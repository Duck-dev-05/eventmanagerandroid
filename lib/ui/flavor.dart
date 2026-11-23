import 'dart:io';

/// The two visual generations EventPulse ships.
///
/// Android 13 and older keep the original, compact EventPulse look. Android 14
/// and newer get the expressive variant with larger shapes, tonal surfaces and
/// a full-width navigation bar.
enum UiFlavor { classic, expressive }

/// Maps an Android release string such as `13`, `14`, `14.0.0` or
/// `14 (API 34)` to a visual flavor. Non-Android platforms use [classic].
UiFlavor uiFlavorForAndroidVersion(String version) {
  final match = RegExp(r'(\d+)').firstMatch(version);
  final value = int.tryParse(match?.group(1) ?? '') ?? 0;
  // Android release numbers are small (13, 14, 15…). Values of 30 and above
  // are API levels (33 = Android 13, 34 = Android 14), so support both forms.
  final expressive = value >= 30 ? value >= 34 : value >= 14;
  return expressive ? UiFlavor.expressive : UiFlavor.classic;
}

/// Detects the flavor for the device the app is currently running on.
UiFlavor detectUiFlavor() {
  if (!Platform.isAndroid) return UiFlavor.classic;
  return uiFlavorForAndroidVersion(Platform.operatingSystemVersion);
}
