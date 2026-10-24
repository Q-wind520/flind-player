import 'package:flutter_test/flutter_test.dart';

/// Pins the test platform to reduced motion.
///
/// The player progress bar scrolls its wave forever while playing; without
/// this, `pumpAndSettle` would wait forever. Only files that pump the player
/// call this, so pure Dart suites keep their normal binding and real HTTP.
void disableTestMotion() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
}
