import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

/// Entry point.
///
/// Deliberately minimal. There is no network call, no analytics initialisation
/// and no remote configuration fetch here: the application must start and take
/// a photograph with no connectivity at all (PRD section 30, Privacy PRI-002,
/// Build Specification section 63).
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait is the clinical default; landscape support is a device-testing
  // item rather than a claim made here (Testing section 57).
  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  );

  runApp(const ProviderScope(child: WiseApp()));
}
