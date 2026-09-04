import 'package:flutter/widgets.dart';

/// WiseAiTechs design tokens.
///
/// Every value here is quoted directly from the UX/UI Specification sections
/// 2-4 and the Build Specification section 7. The design system source document
/// itself was not supplied with the repository (SPECIFICATION_CONFLICTS C-014),
/// so anything it would have defined but the UX/UI spec does not quote is
/// marked `TODO(design-system)` rather than invented.
///
/// No second design system is defined anywhere else in the codebase; widgets
/// read these tokens through `WiseTheme`.
abstract final class WiseTokens {
  // --- Primary brand colours (UX/UI 2.1) ------------------------------------

  /// Primary actions, navigation, important headings, active system elements.
  static const Color wiseBlue = Color(0xFF243E8F);

  /// Used sparingly: emphasis, alerts, important interactive points.
  static const Color wiseRed = Color(0xFFD61F4B);

  // --- Supporting colours (UX/UI 2.2) ---------------------------------------

  static const Color deepNavy = Color(0xFF101828);
  static const Color slateGray = Color(0xFF475467);
  static const Color lightGray = Color(0xFFEAECF0);
  static const Color softBackground = Color(0xFFF8FAFC);

  /// Reserved for genuine AI features only (UX/UI 59, 67).
  static const Color aiGlowBlue = Color(0xFF3B82F6);

  /// AI / analytics accents (UX/UI 2.2).
  static const Color systemCyan = Color(0xFF06B6D4);

  static const Color successGreen = Color(0xFF16A34A);
  static const Color warningRed = Color(0xFFDC2626);

  static const Color white = Color(0xFFFFFFFF);

  // --- Camera surface (UX/UI 58) --------------------------------------------
  //
  // "The camera should use a predominantly dark interface around the live
  // preview." Derived from Deep Navy so the camera chrome stays on-brand
  // rather than pure black.

  static const Color cameraSurface = Color(0xFF0B1220);
  static const Color cameraChrome = Color(0xCC101828);
  static const Color cameraOnSurface = Color(0xFFF8FAFC);
  static const Color cameraOnSurfaceMuted = Color(0xB3F8FAFC);

  // --- Typography (UX/UI 3) -------------------------------------------------

  /// Poppins is the specified primary font. Font files were not supplied
  /// (SPECIFICATION_CONFLICTS C-015); declaring the family with the specified
  /// fallback chain means the app renders correctly on the platform default
  /// until the files are added to `assets/fonts/`.
  static const String fontFamily = 'Poppins';

  static const List<String> fontFamilyFallback = <String>[
    'Inter',
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  // Mobile scale from UX/UI section 3. The desktop 60-72px headings are
  // deliberately not used.
  static const double screenTitleSize = 24;
  static const double sectionTitleSize = 18;
  static const double bodySize = 16;
  static const double secondarySize = 14;
  static const double captionSize = 12;
  static const double cameraStatusSize = 13;

  static const FontWeight screenTitleWeight = FontWeight.w700;
  static const FontWeight sectionTitleWeight = FontWeight.w700;
  static const FontWeight bodyWeight = FontWeight.w400;
  static const FontWeight secondaryWeight = FontWeight.w500;
  static const FontWeight captionWeight = FontWeight.w600;
  static const FontWeight cameraStatusWeight = FontWeight.w600;

  // --- Spacing (UX/UI 4) ----------------------------------------------------

  static const double space4 = 4;
  static const double space8 = 8;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;
  static const double space64 = 64;
  static const double space96 = 96;

  /// Mobile gutter (UX/UI 4).
  static const double gutter = 16;

  // --- Geometry (UX/UI 57, 65) ----------------------------------------------

  /// "Rounded cards with 24px+ radii" (UX/UI 57).
  static const double cardRadius = 24;

  /// Pill geometry for primary/secondary buttons (UX/UI 65-66).
  static const double pillRadius = 999;

  static const double controlRadius = 12;

  /// Minimum comfortable touch target (UX/UI 54, Accessibility 55).
  static const double minTouchTarget = 48;

  /// The capture control is the dominant action (UX/UI 63, 65).
  static const double captureButtonSize = 76;

  // TODO(design-system): elevation values, gradient stops and the icon set are
  // not quoted in the UX/UI specification. Rounded line icons at a consistent
  // stroke width are used (UX/UI 68) via Material's outlined icon set until the
  // WiseAiTechs icon library is supplied.

  // --- Motion (UX/UI 56) ----------------------------------------------------
  //
  // "Smooth, intelligent, lightweight and fluid ... avoid excessive or
  // distracting animation." Reduced-motion collapses these to zero at the call
  // site.

  static const Duration motionFast = Duration(milliseconds: 120);
  static const Duration motionStandard = Duration(milliseconds: 220);
  static const Duration motionSlow = Duration(milliseconds: 320);

  /// Blink comparison cadence (UX/UI 38).
  static const Duration blinkInterval = Duration(milliseconds: 700);
}
