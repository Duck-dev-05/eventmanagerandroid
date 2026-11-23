import 'package:eventmanagerandroid/ui/flavor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android 13 and below use the classic UI', () {
    expect(uiFlavorForAndroidVersion('12'), UiFlavor.classic);
    expect(uiFlavorForAndroidVersion('12L'), UiFlavor.classic);
    expect(uiFlavorForAndroidVersion('13'), UiFlavor.classic);
    expect(uiFlavorForAndroidVersion('13 (API 33)'), UiFlavor.classic);
    expect(uiFlavorForAndroidVersion('33'), UiFlavor.classic);
    expect(uiFlavorForAndroidVersion('32'), UiFlavor.classic);
  });

  test('Android 14 and newer use the expressive UI', () {
    expect(uiFlavorForAndroidVersion('14'), UiFlavor.expressive);
    expect(uiFlavorForAndroidVersion('14.0.0'), UiFlavor.expressive);
    expect(uiFlavorForAndroidVersion('14 (API 34)'), UiFlavor.expressive);
    expect(uiFlavorForAndroidVersion('15'), UiFlavor.expressive);
    expect(uiFlavorForAndroidVersion('16 (API 36)'), UiFlavor.expressive);
    expect(uiFlavorForAndroidVersion('34'), UiFlavor.expressive);
    expect(uiFlavorForAndroidVersion('35'), UiFlavor.expressive);
  });
}
