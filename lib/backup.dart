/// Current portable workspace backup contract shared by Web, Desktop and
/// Android. Web and Desktop both use version 1 today.
const eventPulseBackupFormat = 'eventpulse-backup';
const eventPulseBackupVersion = 1;

const _compatibleFormats = {
  eventPulseBackupFormat,
  'eventpulse-web-backup',
  'eventpulse-desktop-backup',
};

/// Validates enough of a backup to fail before uploading attachments to the
/// restore endpoint. The server still performs the full schema validation.
void validateEventPulseBackup(Map<String, dynamic> backup) {
  final format = backup['format']?.toString() ?? '';
  if (!_compatibleFormats.contains(format)) {
    throw const FormatException(
      'This is not a supported EventPulse backup file.',
    );
  }

  final rawVersion = backup['version'];
  final version = rawVersion is num
      ? rawVersion.toInt()
      : int.tryParse(rawVersion?.toString() ?? '');
  if (version == null) {
    throw const FormatException('This backup has no format version.');
  }
  if (version > eventPulseBackupVersion) {
    throw FormatException(
      'This backup uses format version $version, but this Android build '
      'supports version $eventPulseBackupVersion. Update EventPulse before '
      'restoring it.',
    );
  }
  if (version != eventPulseBackupVersion) {
    throw FormatException(
      'This backup uses an unsupported format version ($version).',
    );
  }

  final tables = backup['tables'];
  if (tables is! Map) {
    throw const FormatException('This backup has no database tables.');
  }
  final users = tables['users'];
  if (users is! List || users.isEmpty) {
    throw const FormatException(
      'This backup does not contain any workspace users.',
    );
  }

  final files = backup['files'];
  if (files is! List) {
    throw const FormatException('This backup has no attachment list.');
  }
  for (final entry in files) {
    if (entry is! Map) {
      throw const FormatException(
        'This backup contains an invalid attachment.',
      );
    }
    final key = entry['key'];
    final data = entry['data'];
    if (key is! String || key.isEmpty) {
      throw const FormatException(
        'This backup contains an attachment without a file path.',
      );
    }
    if (data is! String || data.isEmpty) {
      throw const FormatException(
        'This backup contains an attachment without file data.',
      );
    }
    if (data.length > 40000000) {
      throw FormatException(
        'The backup contains a file larger than the 40 MB restore limit '
        '($key).',
      );
    }
  }
}
