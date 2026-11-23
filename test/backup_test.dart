import 'package:eventmanagerandroid/backup.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _backup({
  String format = eventPulseBackupFormat,
  Object? version = eventPulseBackupVersion,
  Object? tables,
  Object? files,
}) => {
  'format': format,
  'source': 'web',
  'version': version,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'tables':
      tables ??
      {
        'users': [
          {'id': 'user-1', 'name': 'Owner'},
        ],
      },
  'files': files ?? <Object>[],
};

void main() {
  test('accepts the current EventPulse backup format', () {
    validateEventPulseBackup(_backup());
  });

  test('accepts legacy web and desktop format names at version 1', () {
    validateEventPulseBackup(
      _backup(format: 'eventpulse-web-backup', version: 1),
    );
    validateEventPulseBackup(
      _backup(format: 'eventpulse-desktop-backup', version: 1),
    );
  });

  test('rejects a newer backup format with an update message', () {
    expect(
      () => validateEventPulseBackup(_backup(version: 2)),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Update EventPulse'),
        ),
      ),
    );
  });

  test('rejects unknown formats and versions', () {
    expect(
      () => validateEventPulseBackup(_backup(format: 'another-app')),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => validateEventPulseBackup(_backup(version: 0)),
      throwsA(isA<FormatException>()),
    );
  });

  test('requires workspace users', () {
    expect(
      () => validateEventPulseBackup(_backup(tables: {'users': []})),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('workspace users'),
        ),
      ),
    );
  });

  test('rejects attachments without data', () {
    expect(
      () => validateEventPulseBackup(
        _backup(
          files: [
            {'key': 'uploads/file.pdf', 'data': ''},
          ],
        ),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('without file data'),
        ),
      ),
    );
  });
}
