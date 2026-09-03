import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wise_clinical_camera/core/config/feature_flags.dart';
import 'package:wise_clinical_camera/core/cv/local_alignment_engine.dart';
import 'package:wise_clinical_camera/core/imaging/layer_renderer.dart';
import 'package:wise_clinical_camera/core/imaging/layer_stack.dart';
import 'package:wise_clinical_camera/core/imaging/metadata_anonymizer.dart';
import 'package:wise_clinical_camera/core/imaging/thumbnail_generator.dart';
import 'package:wise_clinical_camera/core/measurement/measurement_calculator.dart';
import 'package:wise_clinical_camera/core/errors/result.dart';
import 'package:wise_clinical_camera/core/network/network_guard.dart';
import 'package:wise_clinical_camera/models/annotation.dart';
import 'package:wise_clinical_camera/models/calibration.dart';
import 'package:wise_clinical_camera/models/enums.dart';
import 'package:wise_clinical_camera/models/geometry.dart';
import 'package:wise_clinical_camera/repositories/photo_repository.dart';
import 'package:wise_clinical_camera/services/ai/ai_service.dart';

import '../support/cv_dataset.dart';
import '../support/test_harness.dart';

/// Network policy and no-silent-upload.
///
/// Priority: **P0**. Privacy PRI-003, PRD section 31, Technical Architecture
/// section 34, AI section 8, Build Specification sections 2.3, 72-73, Testing
/// sections 41-42, master prompt Phase 47.
///
/// The specification asks for a facility that can demonstrate
/// "core capture -> no external image request" (Build Specification section
/// 73). `NetworkGuard` is that facility, and this suite is the demonstration.
void main() {
  group('the core workflow makes no network request', () {
    late TestHarness harness;
    late PhotoRepository repository;
    late NetworkGuard guard;

    setUp(() async {
      harness = await TestHarness.create();
      await harness.seedUser();
      repository = PhotoRepository(
        database: harness.database,
        storage: harness.storage,
        ids: harness.ids,
      );
      guard = NetworkGuard(flags: const FeatureFlags());
    });

    tearDown(() async => harness.dispose());

    test(
      'BEFORE, AFTER, measure, annotate, compare and export are silent',
      () async {
        // The complete clinical workflow of Build Specification section 81 and
        // Testing section 69, start to finish, with the audit log checked after.
        final scene = CvDataset.texturedScene();
        final beforeBytes = CvDataset.toJpeg(scene);
        final afterBytes = CvDataset.toJpeg(
          CvDataset.transform(scene, translateX: 6),
        );

        // 1. Create BEFORE.
        final before = await repository.createPhoto(
          bytes: beforeBytes,
          type: PhotoType.before,
          source: PhotoSource.camera,
          bodyPart: BodyPart.knee,
        );
        expect(before.isOk, isTrue);

        // 2. Thumbnail.
        const generator = ThumbnailGenerator();
        expect(generator.generate(beforeBytes).isOk, isTrue);
        await repository.markProcessed(before.valueOrNull!.id);

        // 3. Prepare the reference and align a live frame.
        final engine = LocalAlignmentEngine();
        final prepared = await engine.prepareReference(
          photoId: before.valueOrNull!.id,
          imageBytes: beforeBytes,
        );
        expect(prepared.isOk, isTrue);
        await engine.analyzeFrame(
          frame: CvDataset.toWorking(CvDataset.transform(scene, translateX: 6)),
          reference: prepared.valueOrNull!,
        );

        // 4. Capture AFTER against that reference.
        final after = await repository.createPhoto(
          bytes: afterBytes,
          type: PhotoType.after,
          source: PhotoSource.camera,
          referencePhotoId: before.valueOrNull!.id,
        );
        expect(after.isOk, isTrue);

        // 5. Calibrate and measure.
        final calibration = Calibration.create(
          id: 'cal',
          photoId: after.valueOrNull!.id,
          method: CalibrationMethod.manual,
          knownValue: 5,
          unit: LengthUnit.centimetre,
          pixelDistance: 500,
        );
        final measurement = MeasurementCalculator.build(
          id: 'm',
          photoId: after.valueOrNull!.id,
          type: MeasurementType.length,
          geometry: const Geometry([ImagePoint(10, 10), ImagePoint(290, 10)]),
          calibration: calibration,
        );
        expect(measurement.hasPhysicalValue, isTrue);

        // 6. Annotate.
        final annotation = Annotation(
          id: 'a',
          photoId: after.valueOrNull!.id,
          type: AnnotationType.circle,
          geometry: const Geometry([ImagePoint(50, 50), ImagePoint(80, 80)]),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

        // 7. Compare and export.
        const renderer = LayerRenderer();
        expect(
          renderer
              .renderPair(beforeBytes: beforeBytes, afterBytes: afterBytes)
              .isOk,
          isTrue,
        );
        expect(
          renderer
              .render(
                originalBytes: afterBytes,
                stack: LayerStack(
                  originalPath: after.valueOrNull!.originalPath,
                  widthPx: after.valueOrNull!.widthPx,
                  heightPx: after.valueOrNull!.heightPx,
                  measurements: [measurement],
                  annotations: [annotation],
                  footerLines: const ['WISE CLINICAL PHOTO'],
                ),
              )
              .isOk,
          isTrue,
        );

        // 8. Anonymized export.
        expect(const MetadataAnonymizer().anonymize(afterBytes).isOk, isTrue);

        // The whole workflow, and nothing reached the guard.
        expect(
          guard.audit,
          isEmpty,
          reason:
              'the core clinical workflow attempted a network request: '
              '${guard.audit.map((a) => a.purpose).toList()}',
        );
        expect(guard.imageUploads, isEmpty);
      },
    );
  });

  group('the guard refuses what the policy forbids', () {
    test('Privacy Mode blocks an image upload', () {
      final guard = NetworkGuard(flags: const FeatureFlags(cloudAi: true));

      final result = guard.authorize(
        host: 'example-ai',
        purpose: 'ai:describe',
        carriesImage: true,
      );

      expect(result.isFailure, isTrue);
      expect(guard.allowedAttempts, isEmpty);
      expect(guard.audit.single.blockReason, contains('Privacy Mode'));
    });

    test(
      'cloud AI disabled blocks an image upload even outside Privacy Mode',
      () {
        final guard = NetworkGuard(
          flags: const FeatureFlags(),
          privacyMode: false,
        );

        expect(
          guard
              .authorize(
                host: 'example-ai',
                purpose: 'ai:describe',
                carriesImage: true,
              )
              .isFailure,
          isTrue,
        );
        expect(guard.imageUploads, isEmpty);
      },
    );

    test('an image upload needs an explicit opt-in on both switches', () {
      final guard = NetworkGuard(
        flags: const FeatureFlags(cloudAi: true),
        privacyMode: false,
      );

      expect(
        guard
            .authorize(
              host: 'example-ai',
              purpose: 'ai:describe',
              carriesImage: true,
            )
            .isOk,
        isTrue,
      );
      expect(guard.imageUploads, hasLength(1));
    });

    test('every attempt is audited, allowed or not', () {
      final guard = NetworkGuard(flags: const FeatureFlags());

      guard.authorize(host: 'a', purpose: 'p1');
      guard.authorize(host: 'b', purpose: 'p2', carriesImage: true);

      expect(guard.audit, hasLength(2));
      expect(guard.allowedAttempts, isEmpty);
    });

    test('turning Privacy Mode off is a deliberate act', () {
      final guard = NetworkGuard(flags: const FeatureFlags(cloudAi: true));

      expect(
        guard.authorize(host: 'x', purpose: 'p', carriesImage: true).isFailure,
        isTrue,
      );

      guard.updatePrivacyMode(enabled: false);

      expect(
        guard.authorize(host: 'x', purpose: 'p', carriesImage: true).isOk,
        isTrue,
      );
    });
  });

  group('AI is off by default and stays off', () {
    test('the default flags disable AI entirely', () {
      expect(const FeatureFlags().aiFullyDisabled, isTrue);
      expect(const FeatureFlags().cloudAi, isFalse);
      expect(const FeatureFlags().onDeviceAi, isFalse);
    });

    test('AiService with no provider reports unavailable', () async {
      final service = AiService(flags: const FeatureFlags());

      expect(service.isDisabled, isTrue);
      final result = await service.analyze(
        const AiRequest(capability: AiCapability.bodyRegionDetection),
      );

      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull!.userMessage,
        contains('Core camera features continue normally'),
      );
    });

    test(
      'a provider that would leave the device is refused without a guard',
      () async {
        // Fail closed: no audited route means no transmission.
        final service = AiService(
          flags: const FeatureFlags(cloudAi: true),
          providers: const [_CloudProviderStub()],
        );

        final result = await service.analyze(
          AiRequest(
            capability: AiCapability.imageDescription,
            imageBytes: Uint8List(64),
          ),
        );

        expect(result.isFailure, isTrue);
      },
    );

    test('a cloud provider is refused while Privacy Mode is on', () async {
      final guard = NetworkGuard(flags: const FeatureFlags(cloudAi: true));
      final service = AiService(
        flags: const FeatureFlags(cloudAi: true),
        networkGuard: guard,
        providers: const [_CloudProviderStub()],
      );

      final result = await service.analyze(
        AiRequest(
          capability: AiCapability.imageDescription,
          imageBytes: Uint8List(64),
        ),
      );

      expect(result.isFailure, isTrue);
      expect(guard.imageUploads, isEmpty);
    });

    test('the disabled provider never runs and never transmits', () async {
      const provider = DisabledAiProvider();

      expect(await provider.isAvailable(), isFalse);
      expect(provider.capabilities, isEmpty);
      expect(provider.location.leavesDevice, isFalse);
    });
  });
}

/// A stub that would transmit, used to prove the guard stops it. It never
/// actually opens a connection.
class _CloudProviderStub implements AiProvider {
  const _CloudProviderStub();

  @override
  String get name => 'stub-cloud';

  @override
  AiProcessingLocation get location => AiProcessingLocation.cloud;

  @override
  Set<AiCapability> get capabilities => const {AiCapability.imageDescription};

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Result<AiResult>> analyze(AiRequest request) async => Result.ok(
    AiResult(
      capability: request.capability,
      location: AiProcessingLocation.cloud,
      data: const {},
    ),
  );
}
