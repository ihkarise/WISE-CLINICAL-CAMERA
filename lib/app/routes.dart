import 'package:flutter/material.dart';

import '../features/annotation/markup_screen.dart';
import '../features/calibration/calibration_screen.dart';
import '../features/capture/capture_screen.dart';
import '../features/cases/cases_screen.dart';
import '../features/comparison/comparison_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/library_screen.dart';
import '../features/library/photo_detail_screen.dart';
import '../features/protocols/protocols_screen.dart';
import '../features/reference/reference_picker_screen.dart';
import '../features/settings/settings_screen.dart';
import '../models/enums.dart';
import '../models/photo.dart';

/// Route names.
///
/// The navigation the specification describes: Camera, Library and Settings as
/// primary, with Cases and Protocols reachable without changing the camera
/// architecture (UX/UI section 5, Build Specification section 8).
abstract final class WiseRoutes {
  static const String home = '/';
  static const String capture = '/capture';
  static const String referencePicker = '/reference';
  static const String library = '/library';
  static const String photoDetail = '/photo';
  static const String comparison = '/comparison';
  static const String calibration = '/calibration';
  static const String markup = '/markup';
  static const String cases = '/cases';
  static const String protocols = '/protocols';
  static const String settings = '/settings';
}

/// What the capture screen needs to start.
class CaptureArguments {
  const CaptureArguments({required this.type, this.referencePhoto});

  final PhotoType type;

  /// Required for AFTER, which cannot start without a reference
  /// (Functional MOD-020).
  final Photo? referencePhoto;
}

/// Comparison arguments.
class ComparisonArguments {
  const ComparisonArguments({required this.before, required this.after});

  final Photo before;
  final Photo after;
}

Route<dynamic>? generateWiseRoute(RouteSettings settings) {
  Widget page;

  switch (settings.name) {
    case WiseRoutes.home:
      page = const HomeScreen();
    case WiseRoutes.capture:
      final arguments = settings.arguments;
      if (arguments is! CaptureArguments) return null;
      page = CaptureScreen(arguments: arguments);
    case WiseRoutes.referencePicker:
      page = const ReferencePickerScreen();
    case WiseRoutes.library:
      page = const LibraryScreen();
    case WiseRoutes.photoDetail:
      final photo = settings.arguments;
      if (photo is! Photo) return null;
      page = PhotoDetailScreen(photo: photo);
    case WiseRoutes.comparison:
      final arguments = settings.arguments;
      if (arguments is! ComparisonArguments) return null;
      page = ComparisonScreen(arguments: arguments);
    case WiseRoutes.calibration:
      final photo = settings.arguments;
      if (photo is! Photo) return null;
      page = CalibrationScreen(photo: photo);
    case WiseRoutes.markup:
      final photo = settings.arguments;
      if (photo is! Photo) return null;
      page = MarkupScreen(photo: photo);
    case WiseRoutes.cases:
      page = const CasesScreen();
    case WiseRoutes.protocols:
      page = const ProtocolsScreen();
    case WiseRoutes.settings:
      page = const SettingsScreen();
    default:
      return null;
  }

  return MaterialPageRoute<dynamic>(builder: (_) => page, settings: settings);
}
