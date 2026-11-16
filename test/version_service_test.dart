import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_flutter_app/services/version_service.dart';

void main() {
  group('VersionService.compareVersions', () {
    test('higher minor/patch version requires update', () {
      expect(VersionService.compareVersions('3.0.3', '3.0.2'), 1);
      expect(VersionService.compareVersions('3.1.0', '3.0.9'), 1);
      expect(VersionService.compareVersions('4.0.0', '3.9.9'), 1);
    });

    test('equal version returns 0 (no update needed)', () {
      expect(VersionService.compareVersions('3.0.2', '3.0.2'), 0);
      expect(VersionService.compareVersions('v3.0.2+10', '3.0.2'), 0);
    });

    test('lower version returns -1', () {
      expect(VersionService.compareVersions('3.0.1', '3.0.2'), -1);
      expect(VersionService.compareVersions('2.9.9', '3.0.0'), -1);
    });
  });
}
