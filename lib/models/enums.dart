// Enumerations shared across the data model.
//
// Every enum carries an explicit `wireName`. The database stores that string,
// never the Dart index, so reordering or inserting a value cannot corrupt
// historical rows (Data Model section 45: never assume a clean database).

/// Capture mode (Data Model section 9, Functional MOD-001..003).
enum PhotoType {
  /// Reference photograph. `referencePhotoId` is normally null.
  before('BEFORE'),

  /// Match of an earlier Before. Should normally carry `referencePhotoId`.
  after('AFTER'),

  /// Standalone photograph. No reference required.
  photo('PHOTO');

  const PhotoType(this.wireName);
  final String wireName;

  static PhotoType fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value);

  /// Only a Before may be offered as a reference by default; the reference
  /// picker prioritises them (Build Specification section 16).
  bool get isReferenceCapable => this == PhotoType.before;
}

/// Data Model section 42.
enum PhotoStatus {
  processing('PROCESSING'),
  active('ACTIVE'),
  failed('FAILED'),
  deleted('DELETED');

  const PhotoStatus(this.wireName);
  final String wireName;

  static PhotoStatus fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value);
}

/// Data Model section 8.
enum PhotoSource {
  camera('CAMERA'),
  import('IMPORT');

  const PhotoSource(this.wireName);
  final String wireName;

  static PhotoSource fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value);
}

/// Optional body region (PRD section 20, Functional MOD-030, Build
/// Specification section 109). Always optional; the user may skip it.
enum BodyPart {
  face('FACE', 'Face'),
  scalp('SCALP', 'Scalp'),
  neck('NECK', 'Neck'),
  chest('CHEST', 'Chest'),
  abdomen('ABDOMEN', 'Abdomen'),
  back('BACK', 'Back'),
  shoulder('SHOULDER', 'Shoulder'),
  arm('ARM', 'Arm'),
  elbow('ELBOW', 'Elbow'),
  forearm('FOREARM', 'Forearm'),
  hand('HAND', 'Hand'),
  hip('HIP', 'Hip'),
  thigh('THIGH', 'Thigh'),
  knee('KNEE', 'Knee'),
  leg('LEG', 'Leg'),
  ankle('ANKLE', 'Ankle'),
  foot('FOOT', 'Foot'),
  other('OTHER', 'Other');

  const BodyPart(this.wireName, this.label);
  final String wireName;
  final String label;

  static BodyPart? fromWire(String? value) => value == null
      ? null
      : values.where((e) => e.wireName == value).firstOrNull;
}

/// Functional specification section 21. Optional.
enum Laterality {
  left('LEFT', 'Left'),
  right('RIGHT', 'Right'),
  both('BOTH', 'Both'),
  notApplicable('NA', 'Not applicable');

  const Laterality(this.wireName, this.label);
  final String wireName;
  final String label;

  static Laterality? fromWire(String? value) => value == null
      ? null
      : values.where((e) => e.wireName == value).firstOrNull;
}

/// Grid options (Functional GRD-002).
enum GridType {
  thirds('3x3', '3 x 3'),
  quarters('4x4', '4 x 4'),
  crosshair('CROSSHAIR', 'Centre crosshair');

  const GridType(this.wireName, this.label);
  final String wireName;
  final String label;

  static GridType fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value, orElse: () => thirds);
}

/// Comparison modes (Functional CMP-001..005, Data Model section 26).
enum ComparisonMode {
  sideBySide('SIDE_BY_SIDE', 'Side by side'),
  slider('SLIDER', 'Slider'),
  overlay('OVERLAY', 'Overlay'),
  blink('BLINK', 'Blink'),
  difference('DIFFERENCE', 'Difference');

  const ComparisonMode(this.wireName, this.label);
  final String wireName;
  final String label;

  static ComparisonMode fromWire(String value) => values.firstWhere(
    (e) => e.wireName == value,
    orElse: () => ComparisonMode.sideBySide,
  );
}

/// Gallery saving preference (Functional SAV-003, Data Model section 16).
enum GallerySaveMode {
  ask('ASK', 'Ask every time'),
  always('ALWAYS', 'Always'),
  never('NEVER', 'Never');

  const GallerySaveMode(this.wireName, this.label);
  final String wireName;
  final String label;

  static GallerySaveMode fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value, orElse: () => ask);
}

/// Calibration methods (Functional CAL-002..004, Data Model section 18).
enum CalibrationMethod {
  ruler('RULER', 'Physical ruler'),
  marker('MARKER', 'Calibration marker'),
  manual('MANUAL', 'Known distance');

  const CalibrationMethod(this.wireName, this.label);
  final String wireName;
  final String label;

  static CalibrationMethod fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value);
}

/// Supported physical units (Functional CAL-005).
///
/// Everything is stored in millimetres internally and converted for display, so
/// a unit change never rewrites stored geometry.
enum LengthUnit {
  millimetre('mm', 'mm', 1),
  centimetre('cm', 'cm', 10),
  metre('m', 'm', 1000);

  const LengthUnit(this.wireName, this.symbol, this.millimetresPerUnit);
  final String wireName;
  final String symbol;
  final double millimetresPerUnit;

  /// Area symbol, e.g. `cm²`.
  String get areaSymbol => '$symbol²';

  static LengthUnit fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value, orElse: () => centimetre);
}

/// Measurement types (Data Model section 20).
///
/// `angle` is present for future posture/orthopaedic workflows and is not
/// offered in the V1 measurement toolbar (Build Specification section 37).
enum MeasurementType {
  length('LENGTH', 'Length'),
  width('WIDTH', 'Width'),
  diameter('DIAMETER', 'Diameter'),
  perimeter('PERIMETER', 'Perimeter'),
  area('AREA', 'Area'),
  angle('ANGLE', 'Angle');

  const MeasurementType(this.wireName, this.label);
  final String wireName;
  final String label;

  static MeasurementType fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value);

  /// True when the result is an area rather than a distance, so the display
  /// unit takes the squared symbol.
  bool get isAreal => this == MeasurementType.area;

  /// True when the value is an angle in degrees, which needs no calibration.
  bool get isAngular => this == MeasurementType.angle;
}

/// Annotation object types (Data Model section 22, Functional ANN-002).
enum AnnotationType {
  pen('PEN', 'Pen'),
  arrow('ARROW', 'Arrow'),
  circle('CIRCLE', 'Circle'),
  rectangle('RECTANGLE', 'Rectangle'),
  point('POINT', 'Point'),
  line('LINE', 'Line'),
  text('TEXT', 'Text'),
  measurement('MEASUREMENT', 'Measurement line');

  const AnnotationType(this.wireName, this.label);
  final String wireName;
  final String label;

  static AnnotationType fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value);
}

/// Alignment methods (Data Model section 27).
enum AlignmentMethod {
  sensor('SENSOR'),
  featureMatch('FEATURE_MATCH'),
  opticalFlow('OPTICAL_FLOW'),
  homography('HOMOGRAPHY'),
  template('TEMPLATE'),
  edge('EDGE'),
  manual('MANUAL'),
  hybrid('HYBRID');

  const AlignmentMethod(this.wireName);
  final String wireName;

  static AlignmentMethod fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value);
}

/// Alignment confidence states (CV section 31, Build Specification section 26).
///
/// A percentage may accompany these, but the percentage is a reproducibility
/// score and never a clinical accuracy claim (CV sections 31, 49, 71).
enum AlignmentStatus {
  good('GOOD', 'Good'),
  fair('FAIR', 'Fair'),
  poor('POOR', 'Poor'),
  unavailable('UNAVAILABLE', 'Unavailable');

  const AlignmentStatus(this.wireName, this.label);
  final String wireName;
  final String label;

  static AlignmentStatus fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value, orElse: () => unavailable);

  /// Whether the estimate is trustworthy enough to drive guidance at all.
  bool get isUsable => this == good || this == fair;
}

/// Quality check types (Data Model section 29).
enum QualityCheckType {
  lighting('LIGHTING'),
  focus('FOCUS'),
  alignment('ALIGNMENT'),
  exposure('EXPOSURE');

  const QualityCheckType(this.wireName);
  final String wireName;

  static QualityCheckType fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value);
}

/// Quality check outcomes (Data Model section 29).
enum QualityStatus {
  good('GOOD'),
  warning('WARNING'),
  fail('FAIL'),
  unavailable('UNAVAILABLE');

  const QualityStatus(this.wireName);
  final String wireName;

  static QualityStatus fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value, orElse: () => unavailable);
}

/// Lighting comparison outcomes (Build Specification section 31, Functional
/// LGT-003).
enum LightingStatus {
  good('GOOD', 'Lighting good'),
  similar('SIMILAR', 'Lighting similar to Before'),
  different('DIFFERENT', 'Lighting differs from Before'),
  tooDark('TOO_DARK', 'Image is dark'),
  tooBright('TOO_BRIGHT', 'Image is bright'),
  unavailable('UNAVAILABLE', 'Lighting check unavailable');

  const LightingStatus(this.wireName, this.label);
  final String wireName;
  final String label;

  bool get isWarning =>
      this == different || this == tooDark || this == tooBright;
}

/// Focus check outcomes (Build Specification section 32, Functional FOC-003).
enum FocusStatus {
  good('GOOD', 'Focus good'),
  mayBeBlurred('MAY_BE_BLURRED', 'Image may be blurred'),
  unavailable('UNAVAILABLE', 'Focus check unavailable');

  const FocusStatus(this.wireName, this.label);
  final String wireName;
  final String label;

  bool get isWarning => this == mayBeBlurred;
}

/// Derived asset types (Data Model section 25).
enum DerivedAssetType {
  thumbnail('THUMBNAIL'),
  annotated('ANNOTATED'),
  measured('MEASURED'),
  comparison('COMPARISON'),
  export('EXPORT'),
  anonymized('ANONYMIZED');

  const DerivedAssetType(this.wireName);
  final String wireName;

  static DerivedAssetType fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value);
}

/// Export presets (Functional EXP-001, Data Model section 30, Build
/// Specification section 47).
enum ExportPreset {
  original('ORIGINAL', 'Original'),
  annotated('ANNOTATED', 'Annotated'),
  measured('MEASURED', 'Measured'),
  beforeAfter('BEFORE_AFTER', 'Before + After'),
  beforeAfterMeasurements(
    'BEFORE_AFTER_MEASUREMENTS',
    'Before + After + Measurements',
  ),
  anonymized('ANONYMIZED', 'Anonymized'),
  reportReady('REPORT_READY', 'Report-ready');

  const ExportPreset(this.wireName, this.label);
  final String wireName;
  final String label;

  static ExportPreset fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value);

  /// Presets that render a Before and an After side by side.
  bool get isPair => this == beforeAfter || this == beforeAfterMeasurements;
}

/// Flash modes exposed by the camera abstraction (Functional CAM-004).
enum WiseFlashMode {
  off('off'),
  auto('auto'),
  always('always'),
  torch('torch');

  const WiseFlashMode(this.wireName);
  final String wireName;

  static WiseFlashMode fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value, orElse: () => off);
}

/// Which physical camera is in use (Functional CAM-002).
enum CameraPosition {
  rear('rear'),
  front('front'),
  external('external');

  const CameraPosition(this.wireName);
  final String wireName;

  static CameraPosition fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value, orElse: () => rear);
}

/// Capture orientation (Functional CAM-005).
enum CaptureOrientation {
  portrait('portrait'),
  landscape('landscape');

  const CaptureOrientation(this.wireName);
  final String wireName;

  static CaptureOrientation fromWire(String value) =>
      values.firstWhere((e) => e.wireName == value, orElse: () => portrait);
}

/// Processing job lifecycle (Build Specification section 104).
enum JobState { queued, running, complete, failed, cancelled }
