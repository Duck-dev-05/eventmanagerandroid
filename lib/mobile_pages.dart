import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'backup.dart';
import 'mobile_backend.dart';
import 'models/event.dart';
import 'ui/flavor.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

const _ink = ink;

String _mobileWorkId() =>
    'android-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(100000)}';

/// Friendly label for a synced work kind, used in search results.
String _kindLabel(String kind) => switch (kind) {
  'tasks' => 'Task',
  'agenda' => 'Session',
  'files' => 'File',
  _ => kind,
};

class MobileSearchPage extends StatefulWidget {
  const MobileSearchPage({
    super.key,
    required this.events,
    required this.members,
    required this.work,
    required this.onOpen,
  });
  final List<EventItem> events;
  final List<Map<String, dynamic>> members;
  final Map<String, List<Map<String, dynamic>>> work;
  final ValueChanged<EventItem> onOpen;

  @override
  State<MobileSearchPage> createState() => _MobileSearchPageState();
}

class _MobileSearchPageState extends State<MobileSearchPage> {
  final _query = TextEditingController();
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final events = widget.events
        .where(
          (e) =>
              q.isNotEmpty &&
              '${e.title} ${e.location} ${e.description} ${e.category}'
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
    final entries = <({String kind, Map<String, dynamic> value})>[];
    for (final kind in ['tasks', 'agenda', 'files']) {
      for (final value in widget.work[kind] ?? const <Map<String, dynamic>>[]) {
        final text =
            '${value['title'] ?? value['name'] ?? ''} ${value['notes'] ?? ''} ${value['description'] ?? ''}';
        if (q.isNotEmpty && text.toLowerCase().contains(q)) {
          entries.add((kind: kind, value: value));
        }
      }
    }
    final people = widget.members.where((member) {
      if (q.isEmpty) return false;
      return '${member['name'] ?? ''} ${member['email'] ?? ''}'
          .toLowerCase()
          .contains(q);
    }).toList();
    String eventTitle(String? eventId) =>
        widget.events
            .where((item) => item.id == eventId)
            .map((item) => item.title)
            .firstOrNull ??
        'Event';
    final hasResults =
        events.isNotEmpty || entries.isNotEmpty || people.isNotEmpty;

    return AppPage(
      bottomPadding: 96,
      children: [
        const PageHeading(
          'Search',
          'Find events and synced event work.',
          eyebrow: 'WORKSPACE',
        ),
        const SizedBox(height: 16),
        AppSearchField(
          controller: _query,
          onChanged: (_) => setState(() {}),
          hintText: 'Events, tasks, sessions, files, people',
        ),
        const SizedBox(height: 16),
        if (q.isEmpty)
          Panel(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                children: [
                  const IconTile(
                    icon: Icons.manage_search_rounded,
                    color: blue,
                    size: 60,
                    radius: 20,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Start typing to search your synced workspace.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Search event names, tasks, agenda sessions and files from every event you can access.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 12.5, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final suggestion in const [
                        'Workshop',
                        'Task',
                        'Agenda',
                        'File',
                      ])
                        ActionChip(
                          label: Text(suggestion),
                          onPressed: () {
                            _query.text = suggestion;
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else if (!hasResults)
          EmptyMessage(
            'No matches found',
            'Nothing matched “${_query.text.trim()}”. Try another term.',
            icon: Icons.search_off_rounded,
          )
        else ...[
          if (events.isNotEmpty) ...[
            SectionCard(
              title: 'Events',
              subtitle:
                  '${events.length} matching event${events.length == 1 ? '' : 's'}',
              icon: Icons.event_note_rounded,
              contentPadding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < events.length; i++) ...[
                    EventRow(
                      event: events[i],
                      badge: 'Event',
                      onTap: () => widget.onOpen(events[i]),
                    ),
                    if (i < events.length - 1)
                      const Divider(height: 1, indent: 15, endIndent: 15),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (entries.isNotEmpty)
            SectionCard(
              title: 'Work items',
              subtitle: '${entries.length} matching task, session or file',
              icon: Icons.task_alt_rounded,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final entry in entries)
                    ListTile(
                      leading: IconTile(
                        icon: entry.kind == 'tasks'
                            ? Icons.check_circle_outline_rounded
                            : entry.kind == 'agenda'
                            ? Icons.schedule_rounded
                            : Icons.attach_file_rounded,
                        color: entry.kind == 'tasks'
                            ? success
                            : entry.kind == 'agenda'
                            ? blue
                            : orange,
                        size: 38,
                        radius: 11,
                      ),
                      title: Text(
                        '${entry.value['title'] ?? entry.value['name'] ?? 'Untitled'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_kindLabel(entry.kind)} · ${eventTitle(entry.value['eventId']?.toString())}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: chevron,
                        size: 19,
                      ),
                      onTap: () {
                        final eventId = entry.value['eventId']?.toString();
                        final event = widget.events
                            .where((item) => item.id == eventId)
                            .firstOrNull;
                        if (event != null) widget.onOpen(event);
                      },
                    ),
                ],
              ),
            ),
          if (people.isNotEmpty) ...[
            const SizedBox(height: 14),
            SectionCard(
              title: 'People',
              subtitle:
                  '${people.length} matching teammate${people.length == 1 ? '' : 's'}',
              icon: Icons.groups_outlined,
              contentPadding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < people.length; i++) ...[
                    InkWell(
                      onTap: () {
                        final eventId = people[i]['eventId']?.toString();
                        final event = widget.events
                            .where((item) => item.id == eventId)
                            .firstOrNull;
                        if (event != null) widget.onOpen(event);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: orangeLight,
                              child: Text(
                                userInitials(
                                  people[i]['name']?.toString() ?? '?',
                                ),
                                style: const TextStyle(
                                  color: orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    people[i]['name']?.toString() ?? 'Teammate',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${people[i]['email'] ?? ''} · ${eventTitle(people[i]['eventId']?.toString())}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: chevron,
                              size: 19,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (i < people.length - 1)
                      const Divider(height: 1, indent: 64),
                  ],
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class MobileNotificationsPage extends StatefulWidget {
  const MobileNotificationsPage({
    super.key,
    required this.notifications,
    required this.backend,
    required this.events,
    required this.onOpenEvent,
    required this.onChanged,
  });
  final List<Map<String, dynamic>> notifications;
  final MobileBackendService backend;
  final List<EventItem> events;
  final ValueChanged<EventItem> onOpenEvent;
  final VoidCallback onChanged;

  @override
  State<MobileNotificationsPage> createState() =>
      _MobileNotificationsPageState();
}

class _MobileNotificationsPageState extends State<MobileNotificationsPage> {
  int _filter = 0;

  Future<void> _markAllRead() async {
    try {
      await widget.backend.markNotificationRead(markAll: true);
      widget.onChanged();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
      }
    }
  }

  Future<void> _open(Map<String, dynamic> n) async {
    final isUnread = n['readAt'] == null;
    if (isUnread) {
      try {
        await widget.backend.markNotificationRead(
          notificationId: n['id']?.toString(),
        );
        widget.onChanged();
        if (mounted) setState(() {});
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_messageFor(error))));
        }
      }
    }
    final eventId = n['eventId']?.toString();
    final event = widget.events.where((item) => item.id == eventId).firstOrNull;
    if (event != null) widget.onOpenEvent(event);
  }

  @override
  Widget build(BuildContext context) {
    final unread = widget.notifications
        .where((n) => n['readAt'] == null)
        .length;
    final items = _filter == 1
        ? widget.notifications.where((n) => n['readAt'] == null).toList()
        : widget.notifications;

    return AppPage(
      bottomPadding: 92,
      children: [
        PageHeading(
          'Notifications',
          'Invites, reminders and changes across your events.',
          eyebrow: 'INBOX',
          action: unread == 0
              ? null
              : TextButton.icon(
                  onPressed: _markAllRead,
                  icon: const Icon(Icons.done_all_rounded, size: 17),
                  label: const Text('Mark all read'),
                ),
        ),
        const SizedBox(height: 14),
        AppSegmentedTabs(
          labels: ['All (${widget.notifications.length})', 'Unread ($unread)'],
          selected: _filter,
          onSelected: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: 14),
        if (widget.notifications.isEmpty)
          const EmptyCard(
            icon: Icons.notifications_none_rounded,
            title: 'No notifications',
            subtitle: 'You are all caught up. New activity will appear here.',
          )
        else if (items.isEmpty)
          const EmptyMessage(
            'Nothing unread',
            'You have read every notification in this workspace.',
            icon: Icons.mark_email_read_outlined,
          )
        else
          for (final n in items) _buildNotificationCard(n),
      ],
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> n) {
    final isUnread = n['readAt'] == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: isUnread ? orangeBorder : line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(n),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(
                  icon: isUnread
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: isUnread ? orange : iconSoft,
                  background: isUnread ? orangeLight : softFill,
                  size: 40,
                  radius: 12,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n['title']?.toString() ?? 'Notification',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: ink,
                                fontSize: 13.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        n['message']?.toString() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: iconSoft,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(n['createdAt']),
                            style: const TextStyle(
                              color: iconSoft,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: chevron,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MobileProfilePage extends StatefulWidget {
  const MobileProfilePage({
    super.key,
    required this.account,
    required this.backend,
    required this.onAccountChanged,
  });
  final MobileAccount account;
  final MobileBackendService backend;
  final ValueChanged<MobileAccount> onAccountChanged;
  @override
  State<MobileProfilePage> createState() => _MobileProfilePageState();
}

class _MobileProfilePageState extends State<MobileProfilePage> {
  late final _name = TextEditingController(text: widget.account.name);
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _setStatus(String message, {required bool isError}) {
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  Future<void> _runAction(Future<MobileAccount?> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final updated = await action();
      if (!mounted) return;
      if (updated != null) widget.onAccountChanged(updated);
    } catch (error) {
      if (mounted) _setStatus(_messageFor(error), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadAvatar() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
      _setStatus('Choose a PNG, JPEG or WebP image under 2 MB.', isError: true);
      return;
    }
    final mime = lookupMimeType(file.name) ?? 'application/octet-stream';
    if (!['image/png', 'image/jpeg', 'image/webp'].contains(mime)) {
      _setStatus('Use a PNG, JPEG or WebP image.', isError: true);
      return;
    }
    await _runAction(() async {
      final updated = await widget.backend.updateProfileAvatar(
        'upload-avatar',
        mimeType: mime,
        dataBase64: base64Encode(bytes),
      );
      _setStatus('Profile photo updated.', isError: false);
      return updated;
    });
  }

  Future<void> _changeAvatar(String action) => _runAction(() async {
    final updated = await widget.backend.updateProfileAvatar(action);
    _setStatus(
      action == 'remove-avatar'
          ? 'Profile photo removed.'
          : 'Google profile photo restored.',
      isError: false,
    );
    return updated;
  });

  Future<void> _saveProfile() => _runAction(() async {
    final updated = await widget.backend.updateProfileName(_name.text.trim());
    _setStatus('Profile updated.', isError: false);
    return updated;
  });

  /// Material bottom sheet with the photo actions, like the Contacts app.
  void _showPhotoOptions() {
    final account = widget.account;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    IconTile(
                      icon: Icons.photo_camera_outlined,
                      color: orange,
                      size: 38,
                      radius: 12,
                    ),
                    SizedBox(width: 11),
                    Text(
                      'Profile photo',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              _SheetAction(
                icon: Icons.upload_rounded,
                color: orange,
                title: 'Upload photo',
                subtitle: 'Choose an image from this device',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _uploadAvatar();
                },
              ),
              if (account.googleAvatarUrl != null)
                _SheetAction(
                  icon: Icons.restore_rounded,
                  color: blue,
                  title: 'Use Google photo',
                  subtitle: 'Restore the photo from your Google account',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _changeAvatar('google-avatar');
                  },
                ),
              if (account.avatarUrl != null)
                _SheetAction(
                  icon: Icons.no_photography_outlined,
                  color: error,
                  title: 'Remove photo',
                  subtitle: 'Use your initials instead',
                  destructive: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _changeAvatar('remove-avatar');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(Widget? overlay) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: orange, width: 2),
          color: Colors.white,
        ),
        child: CircleAvatar(
          radius: 44,
          backgroundImage: widget.account.avatarUrl == null
              ? null
              : NetworkImage(widget.account.avatarUrl!),
          backgroundColor: avatarTint,
          child: widget.account.avatarUrl == null
              ? Text(
                  userInitials(widget.account.name),
                  style: const TextStyle(
                    color: orange,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                )
              : null,
        ),
      ),
      if (overlay != null) Positioned.fill(child: Center(child: overlay)),
      Positioned(
        right: -2,
        bottom: -2,
        child: Material(
          color: ink,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _busy ? null : _showPhotoOptions,
            child: const Padding(
              padding: EdgeInsets.all(7),
              child: Icon(
                Icons.photo_camera_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _roleChip(bool staff, String title) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(
      color: staff ? orangeLight : softFill,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: staff ? orangeBorder : line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          staff
              ? Icons.admin_panel_settings_outlined
              : Icons.person_outline_rounded,
          size: 14,
          color: staff ? orange : muted,
        ),
        const SizedBox(width: 5),
        Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: staff ? orange : mutedStrong,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final roleLabel = account.workspaceRole.isEmpty
        ? 'member'
        : account.workspaceRole;
    final roleIsStaff = roleLabel == 'admin' || roleLabel == 'owner';
    final roleTitle = roleLabel[0].toUpperCase() + roleLabel.substring(1);
    final busyOverlay = _busy
        ? const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: orange),
          )
        : null;

    return AppPage(
      bottomPadding: 96,
      children: [
        const PageHeading(
          'Profile',
          'Your account identity and workspace access.',
          eyebrow: 'ACCOUNT',
        ),
        const SizedBox(height: 16),
        Panel(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 440;
                final details = Column(
                  crossAxisAlignment: narrow
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: narrow ? TextAlign.center : TextAlign.start,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _roleChip(roleIsStaff, roleTitle),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _showPhotoOptions,
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            size: 16,
                          ),
                          label: const Text('Change photo'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
                if (narrow) {
                  return Column(
                    children: [
                      _avatar(busyOverlay),
                      const SizedBox(height: 14),
                      details,
                    ],
                  );
                }
                return Row(
                  children: [
                    _avatar(busyOverlay),
                    const SizedBox(width: 18),
                    Expanded(child: details),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Profile details',
          subtitle: 'How you appear across the workspace.',
          icon: Icons.badge_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 19),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                readOnly: true,
                initialValue: account.email,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText: 'Sign-in email cannot be changed here',
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 19),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy ? null : _saveProfile,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(_busy ? 'Saving…' : 'Save profile'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                StatusBanner(message: _message!, isError: _messageIsError),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Workspace access',
          subtitle: 'Roles are managed by workspace owners.',
          icon: Icons.shield_outlined,
          child: Row(
            children: [
              IconTile(
                icon: roleIsStaff
                    ? Icons.admin_panel_settings_outlined
                    : Icons.person_outline_rounded,
                color: roleIsStaff ? orange : muted,
                size: 38,
                radius: 11,
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workspace role',
                      style: TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Determines which areas of EventPulse you can manage.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              _roleChip(roleIsStaff, roleTitle),
            ],
          ),
        ),
      ],
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Row(
              children: [
                IconTile(icon: icon, color: color, size: 38, radius: 11),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: destructive ? error : ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: const TextStyle(color: muted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: chevron,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MobileSettingsPage extends StatefulWidget {
  const MobileSettingsPage({
    super.key,
    required this.preferences,
    required this.backend,
    required this.isOwner,
    this.onRestored,
  });
  final Map<String, dynamic> preferences;
  final MobileBackendService backend;
  final bool isOwner;
  final VoidCallback? onRestored;
  @override
  State<MobileSettingsPage> createState() => _MobileSettingsPageState();
}

class _MobileSettingsPageState extends State<MobileSettingsPage> {
  late bool reminders = widget.preferences['eventReminders'] != false;
  late bool emailUpdates = widget.preferences['emailUpdates'] != false;
  late bool digest = widget.preferences['weeklyDigest'] == true;
  late final _capacity = TextEditingController(
    text: widget.preferences['defaultCapacity']?.toString() ?? '',
  );
  String? _message;
  bool _messageIsError = false;
  bool _busy = false;
  String? _feed;
  bool _backupBusy = false;

  void _setStatus(String message, {required bool isError}) => setState(() {
    _message = message;
    _messageIsError = isError;
  });
  @override
  void dispose() {
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _downloadBackup() async {
    setState(() => _backupBusy = true);
    try {
      final backup = await widget.backend.createBackup();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/eventpulse-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json',
      );
      await file.writeAsString(jsonEncode(backup));
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'EventPulse backup'),
      );
      if (mounted) {
        _setStatus(
          'Backup ready (format v$eventPulseBackupVersion). Store it somewhere safe.',
          isError: false,
        );
      }
    } catch (error) {
      if (mounted) _setStatus(_messageFor(error), isError: true);
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (!mounted) return;
    final bytes = picked?.files.single.bytes;
    if (bytes == null) return;

    Map<String, dynamic> backup;
    try {
      final parsed = jsonDecode(utf8.decode(bytes));
      if (parsed is! Map) {
        throw const FormatException('Choose a valid EventPulse backup.');
      }
      backup = Map<String, dynamic>.from(parsed);
      validateEventPulseBackup(backup);
    } catch (error) {
      if (mounted) _setStatus(_messageFor(error), isError: true);
      return;
    }

    if (!await _confirm(
      context,
      'Restore this full backup? It will replace all workspace data. This cannot be undone.',
    )) {
      return;
    }
    setState(() => _backupBusy = true);
    try {
      await widget.backend.restoreBackup(backup);
      widget.onRestored?.call();
      if (mounted) {
        _setStatus(
          'Backup restored. Sign in again if the restored workspace account changed.',
          isError: false,
        );
      }
    } catch (error) {
      if (mounted) _setStatus(_messageFor(error), isError: true);
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _save() async {
    final raw = _capacity.text.trim();
    final cap = raw.isEmpty ? null : int.tryParse(raw);
    if (raw.isNotEmpty && (cap == null || cap < 1 || cap > 100000)) {
      _setStatus(
        'Capacity must be between 1 and 100,000, or leave it blank.',
        isError: true,
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.backend.updatePreferences({
        'eventReminders': reminders,
        'emailUpdates': emailUpdates,
        'weeklyDigest': digest,
        'defaultCapacity': cap,
      });
      _setStatus('Preferences saved and synced.', isError: false);
    } catch (e) {
      _setStatus(_messageFor(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadFeed({bool rotate = false}) async {
    try {
      final url = await widget.backend.getCalendarFeed(rotate: rotate);
      _setStatus(
        rotate
            ? 'Calendar link reset. The old link no longer works.'
            : 'Calendar feed created below.',
        isError: false,
      );
      setState(() => _feed = url);
    } catch (e) {
      _setStatus(_messageFor(e), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      bottomPadding: 96,
      children: [
        const PageHeading(
          'Settings',
          'Manage preferences and calendar access.',
          eyebrow: 'PREFERENCES',
        ),
        const SizedBox(height: 16),
        if (_message != null) ...[
          StatusBanner(message: _message!, isError: _messageIsError),
          const SizedBox(height: 14),
        ],
        SectionCard(
          title: 'App appearance',
          subtitle: EventPulseUiTokens.of(context).flavor == UiFlavor.expressive
              ? 'Expressive · Android 14 and newer'
              : 'Classic · Android 13 and below',
          icon: Icons.phone_android_rounded,
          iconColor:
              EventPulseUiTokens.of(context).flavor == UiFlavor.expressive
              ? blue
              : orange,
          child: Text(
            EventPulseUiTokens.of(context).flavor == UiFlavor.expressive
                ? 'Larger shapes, flatter tonal cards and a full-width navigation bar.'
                : 'Compact cards, soft shadows and a floating navigation bar.',
            style: const TextStyle(color: muted, fontSize: 12.5, height: 1.5),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Notifications',
          subtitle: 'Choose how EventPulse keeps you informed.',
          icon: Icons.notifications_none_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsSwitch(
                icon: Icons.alarm_rounded,
                color: orange,
                title: 'Event reminders',
                subtitle: 'Email reminders for upcoming events',
                value: reminders,
                onChanged: (value) => setState(() => reminders = value),
              ),
              const Divider(height: 18, color: line),
              _SettingsSwitch(
                icon: Icons.mail_outline_rounded,
                color: blue,
                title: 'Email updates',
                subtitle: 'Receive event update emails',
                value: emailUpdates,
                onChanged: (value) => setState(() => emailUpdates = value),
              ),
              const Divider(height: 18, color: line),
              _SettingsSwitch(
                icon: Icons.mark_email_unread_outlined,
                color: success,
                title: 'Weekly digest',
                subtitle: 'A weekly summary of workspace activity',
                value: digest,
                onChanged: (value) => setState(() => digest = value),
              ),
              const SizedBox(height: 16),
              const Text(
                'DEFAULT CAPACITY',
                style: TextStyle(
                  color: muted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 7),
              TextField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Default event capacity',
                  hintText: 'Unlimited',
                  prefixIcon: Icon(Icons.groups_outlined, size: 19),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(_busy ? 'Saving…' : 'Save preferences'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Calendar feed',
          subtitle: 'Subscribe in Google Calendar, Apple Calendar or Outlook.',
          icon: Icons.calendar_month_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create a private feed link, then add it to the calendar app you use. Rotating the link revokes the old one.',
                style: TextStyle(color: muted, fontSize: 12.5, height: 1.5),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _loadFeed(),
                    icon: const Icon(Icons.link_rounded, size: 17),
                    label: const Text('Get feed URL'),
                  ),
                  if (_feed != null)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _feed!));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Calendar URL copied.'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy URL'),
                    ),
                  if (_feed != null)
                    TextButton.icon(
                      onPressed: () => _loadFeed(rotate: true),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset link'),
                    ),
                ],
              ),
              if (_feed != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: softFill,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: line),
                  ),
                  child: SelectableText(
                    _feed!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: mutedStrong,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Keep this link private — anyone with it can read your event calendar.',
                  style: TextStyle(color: iconSoft, fontSize: 10.5),
                ),
              ],
            ],
          ),
        ),
        if (widget.isOwner) ...[
          const SizedBox(height: 14),
          SectionCard(
            title: 'Full backup & restore',
            subtitle:
                'Move your workspace data between devices. Format v$eventPulseBackupVersion.',
            icon: Icons.shield_outlined,
            iconColor: blue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Backup contains sensitive workspace data, files and device-local templates. Restore replaces the current workspace.',
                  style: TextStyle(color: muted, fontSize: 12.5, height: 1.5),
                ),
                const SizedBox(height: 6),
                Text(
                  'Compatible with EventPulse Web and Desktop backups.',
                  style: TextStyle(
                    color: iconSoft,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: warningTint,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(color: warningBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: warning,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Backup contains sensitive data.',
                          style: TextStyle(
                            fontSize: 12,
                            color: warningInk,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _backupBusy ? null : _downloadBackup,
                      icon: const Icon(Icons.download_rounded, size: 17),
                      label: Text(
                        _backupBusy ? 'Working…' : 'Export full backup',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _backupBusy ? null : _restoreBackup,
                      icon: const Icon(Icons.restore_rounded, size: 17),
                      label: const Text('Restore backup'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            IconTile(icon: icon, color: color, size: 38, radius: 11),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class MobilePeoplePage extends StatefulWidget {
  const MobilePeoplePage({
    super.key,
    required this.account,
    required this.backend,
  });
  final MobileAccount account;
  final MobileBackendService backend;
  @override
  State<MobilePeoplePage> createState() => _MobilePeoplePageState();
}

class _MobilePeoplePageState extends State<MobilePeoplePage>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();
  int _roleFilter = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reload silently when the app comes back to the foreground so the user
    // list never shows stale data after background sync runs.
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await widget.backend.manageWorkspaceUsers('list');
      if (mounted) {
        setState(() {
          _users = (r['users'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mutate(String action, Map<String, dynamic> values) async {
    try {
      await widget.backend.manageWorkspaceUsers(
        action,
        userId: values['userId']?.toString(),
        name: values['name']?.toString(),
        email: values['email']?.toString(),
        password: values['password']?.toString(),
        role: values['role']?.toString(),
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
    }
  }

  Future<void> _edit(Map<String, dynamic> user) async {
    final name = TextEditingController(text: user['name']?.toString() ?? '');
    final email = TextEditingController(text: user['email']?.toString() ?? '');
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit user'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, {
              'name': name.text.trim(),
              'email': email.text.trim(),
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (values != null && mounted) {
      await _mutate('update', {'userId': user['id'], ...values});
    }
  }

  Future<void> _create() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        final name = TextEditingController(),
            email = TextEditingController(),
            password = TextEditingController();
        return AlertDialog(
          title: const Text('Create workspace account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Initial password (6+ characters)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'name': name.text,
                'email': email.text,
                'password': password.text,
              }),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (result != null) await _mutate('create', result);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.account.workspaceRole != 'owner' &&
        widget.account.workspaceRole != 'admin') {
      return AppPage(
        children: [
          const PageHeading(
            'Users & team',
            'Manage workspace accounts and access.',
            eyebrow: 'TEAM',
          ),
          const SizedBox(height: 16),
          const EmptyCard(
            icon: Icons.lock_outline_rounded,
            title: 'Workspace people',
            subtitle: 'Only workspace administrators can manage accounts.',
          ),
        ],
      );
    }
    final query = _search.text.trim().toLowerCase();
    final filtered = _users.where((user) {
      final matchesQuery = '${user['name']} ${user['email']}'
          .toLowerCase()
          .contains(query);
      final role = (user['workspaceRole'] ?? 'member').toString();
      final matchesRole = switch (_roleFilter) {
        1 => role == 'owner' || role == 'admin',
        2 => role == 'member' || role == 'viewer',
        _ => true,
      };
      return matchesQuery && matchesRole;
    }).toList();
    final showAdd = MediaQuery.sizeOf(context).width >= kMediumBreakpoint;

    return AppPage(
      bottomPadding: 96,
      children: [
        PageHeading(
          'Users & team',
          'Manage workspace accounts and access.',
          eyebrow: 'TEAM',
          action: showAdd
              ? FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add user'),
                )
              : IconButton(
                  tooltip: 'Add user',
                  onPressed: _create,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          StatusBanner(message: _error!, isError: true),
          const SizedBox(height: 14),
        ],
        AppSearchField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          hintText: 'Search by name or email',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppSegmentedTabs(
                  labels: const ['All', 'Admins', 'Members'],
                  selected: _roleFilter,
                  onSelected: (value) => setState(() => _roleFilter = value),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${filtered.length} of ${_users.length}',
              style: const TextStyle(
                color: muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_loading)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: const LinearProgressIndicator(minHeight: 3),
          ),
        if (!_loading && filtered.isEmpty)
          const EmptyMessage(
            'No users found',
            'Users in this workspace will appear here.',
            icon: Icons.people_outline_rounded,
          )
        else if (filtered.isNotEmpty)
          Panel(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < filtered.length; i++) ...[
                    _userRow(filtered[i]),
                    if (i < filtered.length - 1)
                      const Divider(height: 1, indent: 52),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _rolePill(String role) {
    final (color, tint) = switch (role) {
      'owner' => (orange, orangeLight),
      'admin' => (blue, blueLight),
      'viewer' => (muted, softFill),
      _ => (mutedStrong, softFill),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        role[0].toUpperCase() + role.substring(1),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _userRow(Map<String, dynamic> user) {
    final role = (user['workspaceRole'] ?? 'member').toString();
    final isYou = user['id'] == widget.account.id;
    final isOwner = widget.account.workspaceRole == 'owner';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: role == 'owner' ? orangeLight : softFill,
            child: Text(
              userInitials(user['name']?.toString() ?? '?'),
              style: TextStyle(
                color: role == 'owner' ? orange : mutedStrong,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user['name']?.toString() ?? 'User',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isYou) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: chipFill,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: line),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  user['email']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 11.5),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _rolePill(role),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.event_available_outlined,
                          size: 11,
                          color: iconSoft,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Joined ${_formatDate(user['createdAt'])}',
                          style: const TextStyle(color: iconSoft, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isOwner || widget.account.workspaceRole == 'admin')
            PopupMenuButton<String>(
              tooltip: 'User actions',
              position: PopupMenuPosition.under,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: const BorderSide(color: line),
              ),
              onSelected: (value) async {
                if (!mounted) return;
                if (value == 'edit') {
                  await _edit(user);
                } else if (value == 'role') {
                  final role = await showDialog<String>(
                    context: context,
                    builder: (c) => SimpleDialog(
                      title: const Text('Workspace role'),
                      children: [
                        for (final r in ['member', 'admin', 'owner'])
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(c, r),
                            child: Row(
                              children: [
                                _rolePill(r),
                                const SizedBox(width: 10),
                                Text(r[0].toUpperCase() + r.substring(1)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                  if (!mounted) return;
                  if (role != null) {
                    await _mutate('set-role', {
                      'userId': user['id'],
                      'role': role,
                    });
                  }
                } else if (value == 'delete') {
                  if (await _confirm(context, 'Delete this account?') &&
                      mounted) {
                    await _mutate('delete', {'userId': user['id']});
                  }
                } else if (value == 'reset') {
                  if (!mounted) return;
                  final password = await _passwordDialog(context);
                  if (!mounted) return;
                  if (password != null) {
                    await _mutate('reset-password', {
                      'userId': user['id'],
                      'password': password,
                    });
                  }
                }
              },
              itemBuilder: (_) => [
                appMenuItem(
                  value: 'edit',
                  label: 'Edit user',
                  icon: Icons.edit_outlined,
                ),
                if (isOwner && !isYou) ...[
                  appMenuItem(
                    value: 'role',
                    label: 'Change role',
                    icon: Icons.manage_accounts_outlined,
                  ),
                  appMenuItem(
                    value: 'reset',
                    label: 'Reset password',
                    icon: Icons.key_rounded,
                  ),
                  appMenuItem(
                    value: 'delete',
                    label: 'Delete account',
                    icon: Icons.delete_outline_rounded,
                    destructive: true,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class MobileActivityPage extends StatefulWidget {
  const MobileActivityPage({
    super.key,
    required this.events,
    required this.backend,
    required this.onOpenEvent,
  });
  final List<EventItem> events;
  final MobileBackendService backend;
  final ValueChanged<EventItem> onOpenEvent;
  @override
  State<MobileActivityPage> createState() => _MobileActivityPageState();
}

class _MobileActivityPageState extends State<MobileActivityPage>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void didUpdateWidget(covariant MobileActivityPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events.map((e) => e.id).join(',') !=
        widget.events.map((e) => e.id).join(',')) {
      _load();
    }
  }

  Future<void> _load() async {
    final all = await Future.wait(
      widget.events
          .where((e) => e.id != null)
          .map(
            (e) async =>
                (await widget.backend
                        .eventActivity(e.id!)
                        .catchError((_) => <Map<String, dynamic>>[]))
                    .map(
                      (entry) => {
                        ...entry,
                        'eventId': e.id,
                        'eventTitle': e.title,
                      },
                    )
                    .toList(),
          ),
    );
    if (mounted) {
      setState(
        () => _items = all.expand((x) => x).toList()
          ..sort(
            (a, b) => (b['createdAt'] ?? '').toString().compareTo(
              (a['createdAt'] ?? '').toString(),
            ),
          ),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      bottomPadding: 92,
      children: [
        const PageHeading(
          'My activity',
          'Recent updates from your events.',
          eyebrow: 'HISTORY',
        ),
        const SizedBox(height: 16),
        if (_loading) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: const LinearProgressIndicator(minHeight: 3),
          ),
          const SizedBox(height: 14),
        ],
        if (!_loading && _items.isEmpty)
          const EmptyCard(
            icon: Icons.history_rounded,
            title: 'No activity yet',
            subtitle: 'Create an event or join one to see activity here.',
          )
        else if (_items.isNotEmpty)
          SectionCard(
            title: 'Recent updates',
            subtitle:
                '${_items.length} update${_items.length == 1 ? '' : 's'} across your events',
            icon: Icons.history_rounded,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < _items.length; i++) ...[
                  InkWell(
                    onTap: () {
                      final eventId = _items[i]['eventId']?.toString();
                      final event = widget.events
                          .where((item) => item.id == eventId)
                          .firstOrNull;
                      if (event != null) widget.onOpenEvent(event);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconTile(
                            icon: Icons.bolt_rounded,
                            color: i == 0 ? orange : iconSoft,
                            background: i == 0 ? orangeLight : softFill,
                            size: 36,
                            radius: 11,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_items[i]['summary'] ?? 'Event update'} · ${_items[i]['eventTitle'] ?? 'Event'}',
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_items[i]['actorName'] ?? 'A teammate'} · ${_formatDate(_items[i]['createdAt'])}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: chevron,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i < _items.length - 1)
                    const Divider(height: 1, indent: 58),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class MobileTemplatesPage extends StatefulWidget {
  const MobileTemplatesPage({
    super.key,
    required this.backend,
    required this.onUse,
  });
  final MobileBackendService backend;
  final ValueChanged<Map<String, dynamic>> onUse;
  @override
  State<MobileTemplatesPage> createState() => _MobileTemplatesPageState();
}

class _MobileTemplatesPageState extends State<MobileTemplatesPage>
    with WidgetsBindingObserver {
  static const _builtInTemplates = <Map<String, dynamic>>[
    {
      'id': 'tech-conference',
      'name': 'Tech Innovation Conference',
      'category': 'Conference',
      'description':
          'A full-day flagship event with keynotes, breakout sessions and an evening networking mixer.',
      'defaultVenue': 'Grand Convention Center, Hall A',
      'defaultCapacity': 500,
      'defaultDurationMinutes': 480,
      'agendaPresets': [
        {
          'title': 'Registration & Morning Coffee',
          'durationMinutes': 45,
          'description': 'Badge pickup and breakfast.',
        },
        {
          'title': 'Opening Keynote',
          'durationMinutes': 60,
          'description': 'Welcome and keynote address.',
        },
        {
          'title': 'Networking Reception',
          'durationMinutes': 60,
          'description': 'Meet fellow attendees.',
        },
      ],
      'taskPresets': [
        {
          'title': 'Confirm speakers',
          'notes': 'Finalize speaker details and presentations.',
        },
        {
          'title': 'Arrange catering',
          'notes': 'Confirm dietary requirements and headcount.',
        },
        {
          'title': 'Test AV equipment',
          'notes': 'Check microphones, screens and connectivity.',
        },
      ],
    },
    {
      'id': 'product-launch',
      'name': 'Product Launch Showcase',
      'category': 'Webinar',
      'description':
          'An energetic reveal for press, VIP customers and ambassadors with live demos and Q&A.',
      'defaultVenue': 'Metropolitan Theater & Studio',
      'defaultCapacity': 250,
      'defaultDurationMinutes': 180,
      'agendaPresets': [
        {
          'title': 'Doors Open & Press Check-in',
          'durationMinutes': 30,
          'description': 'Media check-in and welcome.',
        },
        {
          'title': 'The Big Reveal',
          'durationMinutes': 45,
          'description': 'Product announcement and presentation.',
        },
        {
          'title': 'Live Product Demo',
          'durationMinutes': 30,
          'description': 'Demonstrate the new product.',
        },
        {
          'title': 'Press Q&A',
          'durationMinutes': 30,
          'description': 'Questions and answers.',
        },
      ],
      'taskPresets': [
        {
          'title': 'Prepare press kit',
          'notes': 'Gather product specs, images and pricing.',
        },
        {
          'title': 'Set up demo units',
          'notes': 'Install the release build and test.',
        },
        {
          'title': 'Arrange refreshments',
          'notes': 'Confirm catering for guests.',
        },
      ],
    },
  ];

  List<Map<String, dynamic>> _templates = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    final list = await widget.backend.listTemplates();
    if (mounted) setState(() => _templates = list);
  }

  Future<void> _create() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        final name = TextEditingController();
        final description = TextEditingController();
        final venue = TextEditingController();
        final tasks = TextEditingController();
        final agenda = TextEditingController();
        return AlertDialog(
          title: const Text('Create template'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Template name'),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: venue,
                  decoration: const InputDecoration(labelText: 'Default venue'),
                ),
                TextField(
                  controller: agenda,
                  decoration: const InputDecoration(
                    labelText: 'Agenda presets (one per line)',
                  ),
                ),
                TextField(
                  controller: tasks,
                  decoration: const InputDecoration(
                    labelText: 'Task presets (one per line)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {
                'name': name.text.trim(),
                'description': description.text.trim(),
                'defaultVenue': venue.text.trim(),
                'category': 'Conference',
                'defaultCapacity': null,
                'defaultDurationMinutes': 180,
                'agendaPresets': agenda.text
                    .split('\n')
                    .where((s) => s.trim().isNotEmpty)
                    .map(
                      (title) => {
                        'title': title.trim(),
                        'durationMinutes': 30,
                        'description': '',
                      },
                    )
                    .toList(),
                'taskPresets': tasks.text
                    .split('\n')
                    .where((s) => s.trim().isNotEmpty)
                    .map((title) => {'title': title.trim(), 'notes': ''})
                    .toList(),
              }),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (result == null || result['name'] == '') return;
    await widget.backend.saveTemplate(result);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final showNew = MediaQuery.sizeOf(context).width >= kMediumBreakpoint;
    final templates = [..._builtInTemplates, ..._templates];
    return AppPage(
      bottomPadding: 92,
      children: [
        PageHeading(
          'Templates',
          'Built-in presets and event structures saved on this device.',
          eyebrow: 'LIBRARY',
          action: showNew
              ? FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New template'),
                )
              : IconButton(
                  tooltip: 'Create template',
                  onPressed: _create,
                  icon: const Icon(Icons.add_rounded),
                ),
        ),
        const SizedBox(height: 16),
        if (templates.isEmpty)
          EmptyCard(
            icon: Icons.dashboard_customize_outlined,
            title: 'No templates yet',
            subtitle: 'Create a template to reuse its agenda and task list.',
            action: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create template'),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 2 : 1;
              final gap = 12.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final template in templates)
                    SizedBox(
                      width: width,
                      child: _TemplateCard(
                        template: template,
                        onUse: () => widget.onUse(template),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onUse});

  final Map<String, dynamic> template;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final agenda = (template['agendaPresets'] as List? ?? const []).length;
    final tasks = (template['taskPresets'] as List? ?? const []).length;
    final description = template['description']?.toString() ?? '';
    final category = template['category']?.toString();
    return Panel(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconTile(
                  icon: Icons.dashboard_customize_outlined,
                  color: orange,
                  size: 42,
                  radius: 13,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template['name']?.toString() ?? 'Template',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (category != null && category.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          category,
                          style: const TextStyle(
                            color: muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: muted,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 11),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                _CountChip(
                  icon: Icons.schedule_rounded,
                  label: '$agenda agenda',
                ),
                _CountChip(
                  icon: Icons.task_alt_rounded,
                  label: '$tasks task${tasks == 1 ? '' : 's'}',
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: onUse,
                  icon: const Icon(Icons.play_arrow_rounded, size: 17),
                  label: const Text('Use template'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: orange,
                    side: const BorderSide(color: orangeBorder),
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: softFill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconSoft),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: mutedStrong,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class MobileHelpPage extends StatelessWidget {
  const MobileHelpPage({super.key});

  static const _faqs = <(IconData, String, String)>[
    (
      Icons.add_task_rounded,
      'How do I create an event?',
      'Choose Create event, enter the event details, and save. It syncs to your website and desktop account.',
    ),
    (
      Icons.sync_rounded,
      'How does sync work?',
      'Android syncs with your paired EventPulse website account. Changes are shared with the website and desktop when online.',
    ),
    (
      Icons.groups_outlined,
      'Where do I manage team members?',
      'Open an event and choose Members. Event owners and admins can invite or manage collaborators.',
    ),
    (
      Icons.tune_rounded,
      'Where are settings?',
      'Open your account menu and select Settings to manage notifications and your calendar feed.',
    ),
    (
      Icons.phone_android_rounded,
      'What is stored only on this device?',
      'Event templates are saved on this Android device. Workspace owners can create and restore a full backup from Settings.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppPage(
      bottomPadding: 92,
      children: [
        const PageHeading(
          'Help & support',
          'Quick answers for using EventPulse on Android.',
          eyebrow: 'SUPPORT',
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            children: [
              for (var i = 0; i < _faqs.length; i++) ...[
                ExpansionTile(
                  leading: IconTile(
                    icon: _faqs[i].$1,
                    color: i.isEven ? orange : blue,
                    size: 36,
                    radius: 11,
                  ),
                  title: Text(
                    _faqs[i].$2,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _faqs[i].$3,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12.5,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
                if (i < _faqs.length - 1)
                  const Divider(height: 1, indent: 60, endIndent: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Still need a hand?',
          subtitle: 'Workspace owners can help with access and billing.',
          icon: Icons.support_agent_rounded,
          iconColor: success,
          child: const Text(
            'Reach out to the owner of your EventPulse workspace for account, role or workspace-level questions. Event owners can manage most event settings from the event Settings tab.',
            style: TextStyle(color: muted, fontSize: 12.5, height: 1.55),
          ),
        ),
      ],
    );
  }
}

class MobileEventPage extends StatefulWidget {
  const MobileEventPage({
    super.key,
    required this.event,
    required this.tab,
    required this.role,
    required this.account,
    required this.backend,
    required this.work,
    required this.members,
    required this.availableUsers,
    required this.activity,
    this.onLeave,
    required this.onTab,
    required this.onSave,
    required this.onDelete,
    required this.onReload,
  });
  final EventItem event;
  final int tab;
  final String role;
  final MobileAccount account;
  final MobileBackendService backend;
  final Map<String, List<Map<String, dynamic>>> work;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> availableUsers;
  final List<Map<String, dynamic>> activity;
  final VoidCallback? onLeave;
  final ValueChanged<int> onTab;
  final ValueChanged<Map<String, dynamic>> onSave;
  final VoidCallback onDelete;
  final VoidCallback onReload;
  @override
  State<MobileEventPage> createState() => _MobileEventPageState();
}

class _MobileEventPageState extends State<MobileEventPage> {
  bool _busy = false;
  String? _error;
  String _id(Map<String, dynamic> m) => m['id']?.toString() ?? '';
  List<Map<String, dynamic>> _forEvent(String key) => (widget.work[key] ?? [])
      .where((m) => m['eventId'] == widget.event.id)
      .toList();

  String get _eventUrl => '$eventPulseWebsiteOrigin/events/${widget.event.id}';
  bool get _isOwnerRecord => widget.event.ownerId == widget.account.id;
  String get _ownerName => _isOwnerRecord
      ? widget.account.name
      : (widget.event.ownerName ?? 'Event organizer');
  String? get _ownerAvatarUrl =>
      _isOwnerRecord ? widget.account.avatarUrl : widget.event.ownerAvatarUrl;

  Future<void> _copyEventLink() async {
    await Clipboard.setData(ClipboardData(text: _eventUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Event link copied.')));
  }

  Future<void> _openEventOnWebsite() async {
    try {
      await launchUrl(
        Uri.parse(_eventUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    const names = [
      'Overview',
      'Tasks',
      'Members',
      'Schedule',
      'Files',
      'Activity',
      'Settings',
    ];
    const icons = [
      Icons.info_outline_rounded,
      Icons.task_alt_rounded,
      Icons.groups_outlined,
      Icons.schedule_rounded,
      Icons.folder_open_rounded,
      Icons.history_rounded,
      Icons.settings_outlined,
    ];
    final event = widget.event;
    final time = TimeOfDay.fromDateTime(event.date).format(context);
    final roleLabel = widget.role.isEmpty
        ? 'Viewer'
        : widget.role[0].toUpperCase() + widget.role.substring(1);
    final roleColor = switch (widget.role) {
      'owner' => orange,
      'admin' => blue,
      _ => mutedStrong,
    };
    final roleTint = switch (widget.role) {
      'owner' => orangeLight,
      'admin' => blueLight,
      _ => softFill,
    };

    return AppPage(
      bottomPadding: 96,
      children: [
        Panel(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl - 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 5,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [orangeDeep, orange]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _EventPill(
                                      icon: Icons.sell_outlined,
                                      label: event.category,
                                      color: orange,
                                      tint: orangeLight,
                                      border: orangeBorder,
                                    ),
                                    _EventPill(
                                      icon: Icons.shield_outlined,
                                      label: roleLabel,
                                      color: roleColor,
                                      tint: roleTint,
                                      border: roleColor.withValues(alpha: 0.22),
                                    ),
                                    if (event.visibility == 'public')
                                      const _EventPill(
                                        icon: Icons.public_rounded,
                                        label: 'Public',
                                        color: blue,
                                        tint: blueLight,
                                        border: Color(0xFFD5E0FA),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  event.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 23,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 13,
                                  runSpacing: 5,
                                  children: [
                                    _HeaderMeta(
                                      icon: Icons.calendar_today_outlined,
                                      text: longDate(event.date),
                                      maxWidth: 230,
                                    ),
                                    _HeaderMeta(
                                      icon: Icons.schedule_rounded,
                                      text: time,
                                      maxWidth: 90,
                                    ),
                                    _HeaderMeta(
                                      icon: Icons.location_on_outlined,
                                      text: event.location,
                                      maxWidth: 230,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Event actions',
                            position: PopupMenuPosition.under,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              side: const BorderSide(color: line),
                            ),
                            onSelected: (value) {
                              if (value == 'calendar') {
                                _shareCalendarEvent();
                              } else if (value == 'copy-link') {
                                _copyEventLink();
                              } else if (value == 'open-web') {
                                _openEventOnWebsite();
                              } else if (value == 'run-sheet') {
                                _runSheetMenu();
                              } else if (value == 'duplicate' &&
                                  widget.role == 'owner') {
                                _duplicateEvent();
                              } else {
                                widget.onTab(int.parse(value));
                              }
                            },
                            itemBuilder: (_) => [
                              for (var i = 0; i < names.length; i++)
                                appMenuItem(
                                  value: '$i',
                                  label: names[i],
                                  icon: icons[i],
                                  selected: widget.tab == i,
                                ),
                              const PopupMenuDivider(),
                              appMenuItem(
                                value: 'calendar',
                                label: 'Add to calendar',
                                icon: Icons.calendar_month_outlined,
                              ),
                              appMenuItem(
                                value: 'copy-link',
                                label: 'Copy event link',
                                icon: Icons.link_rounded,
                              ),
                              appMenuItem(
                                value: 'open-web',
                                label: 'Open on website',
                                icon: Icons.open_in_new_rounded,
                              ),
                              appMenuItem(
                                value: 'run-sheet',
                                label: 'Print run sheet',
                                icon: Icons.print_outlined,
                              ),
                              if (widget.role == 'owner')
                                appMenuItem(
                                  value: 'duplicate',
                                  label: 'Duplicate event',
                                  icon: Icons.content_copy_rounded,
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _shareCalendarEvent,
                            icon: const Icon(
                              Icons.calendar_month_outlined,
                              size: 16,
                            ),
                            label: const Text('Add to calendar'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _copyEventLink,
                            icon: const Icon(Icons.link_rounded, size: 16),
                            label: const Text('Copy link'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _openEventOnWebsite,
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                            ),
                            label: const Text('Website'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _runSheetMenu,
                            icon: const Icon(Icons.print_outlined, size: 16),
                            label: const Text('Run sheet'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                          if (widget.role == 'owner')
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _duplicateEvent,
                              icon: const Icon(
                                Icons.content_copy_rounded,
                                size: 16,
                              ),
                              label: const Text('Duplicate'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 38),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        AppSegmentedTabs(
          labels: names,
          selected: widget.tab,
          onSelected: widget.onTab,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          StatusBanner(message: _error!, isError: true),
        ],
        const SizedBox(height: 14),
        ..._content(),
      ],
    );
  }

  bool get _canEdit => widget.role != 'viewer';
  bool get _canDelete => widget.role == 'owner' || widget.role == 'admin';
  bool get _canManageSettings => widget.role == 'owner';
  bool get _canChangeRoles => widget.role == 'owner';
  bool get _canDeleteEvent => widget.role == 'owner';
  bool get _canManageTeam => _canDelete;

  List<Widget> _content() {
    final e = widget.event;
    switch (widget.tab) {
      case 0:
        final time = TimeOfDay.fromDateTime(e.date).format(context);
        return [
          SectionCard(
            title: 'Event overview',
            subtitle: 'The essentials at a glance.',
            icon: Icons.info_outline_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (e.description.isNotEmpty) ...[
                  Text(
                    e.description,
                    style: const TextStyle(
                      color: mutedStrong,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: orangeLight,
                      backgroundImage: _ownerAvatarUrl == null
                          ? null
                          : NetworkImage(_ownerAvatarUrl!),
                      child: _ownerAvatarUrl == null
                          ? Text(
                              userInitials(_ownerName),
                              style: const TextStyle(
                                color: orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ORGANIZER',
                            style: TextStyle(
                              color: muted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _ownerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ink,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DetailChip(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: shortDate(e.date),
                    ),
                    _DetailChip(
                      icon: Icons.schedule_rounded,
                      label: 'Starts',
                      value: time,
                    ),
                    _DetailChip(
                      icon: Icons.location_on_outlined,
                      label: 'Venue',
                      value: e.location,
                    ),
                    _DetailChip(
                      icon: Icons.sell_outlined,
                      label: 'Category',
                      value: e.category,
                    ),
                    _DetailChip(
                      icon: Icons.groups_outlined,
                      label: 'Capacity',
                      value: e.capacity == null
                          ? 'Unlimited'
                          : '${e.capacity} guests',
                    ),
                    _DetailChip(
                      icon: Icons.visibility_outlined,
                      label: 'Visibility',
                      value: e.visibility == 'public' ? 'Public' : 'Private',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onTab(1),
                    icon: const Icon(Icons.task_alt_rounded, size: 17),
                    label: const Text('Open event tasks'),
                  ),
                ),
              ],
            ),
          ),
        ];
      case 1:
        final tasks = _forEvent('tasks');
        final done = tasks.where((task) => task['status'] == 'done').length;
        return [
          SectionCard(
            title: 'Tasks',
            subtitle: tasks.isEmpty
                ? 'Keep the team aligned.'
                : '$done of ${tasks.length} complete',
            icon: Icons.task_alt_rounded,
            trailing: _canEdit
                ? _compactAddButton(
                    'Add task',
                    Icons.add_rounded,
                    () => _editWork('tasks'),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            child: tasks.isEmpty
                ? const EmptyMessage(
                    'No tasks yet',
                    'Add a task to keep the team aligned.',
                    icon: Icons.task_alt_rounded,
                  )
                : Column(
                    children: [
                      for (var i = 0; i < tasks.length; i++) ...[
                        _taskRow(tasks[i]),
                        if (i < tasks.length - 1)
                          const Divider(height: 1, indent: 52, endIndent: 10),
                      ],
                    ],
                  ),
          ),
        ];
      case 2:
        final members = widget.members
            .where((member) => member['eventId'] == e.id)
            .toList();
        final pending = _forEvent('invitations');
        return [
          SectionCard(
            title: 'Team',
            subtitle:
                '${members.length + 1} member${members.isEmpty ? '' : 's'} on this event.',
            icon: Icons.groups_outlined,
            trailing: _canManageTeam
                ? _compactAddButton(
                    'Add',
                    Icons.person_add_alt_1_rounded,
                    _addMemberMenu,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _ownerRow(),
                const Divider(height: 1, indent: 52, endIndent: 10),
                if (members.isEmpty)
                  const EmptyMessage(
                    'No other members yet',
                    'Invite teammates to collaborate on this event.',
                    icon: Icons.groups_outlined,
                  )
                else
                  for (var i = 0; i < members.length; i++) ...[
                    _memberRow(members[i]),
                    if (i < members.length - 1)
                      const Divider(height: 1, indent: 52, endIndent: 10),
                  ],
                if (pending.isNotEmpty) ...[
                  const Divider(height: 14),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 6, 14, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'PENDING INVITATIONS',
                        style: TextStyle(
                          color: muted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.15,
                        ),
                      ),
                    ),
                  ),
                  for (final invitation in pending)
                    ListTile(
                      leading: const IconTile(
                        icon: Icons.mail_outline_rounded,
                        color: warning,
                        size: 36,
                        radius: 11,
                      ),
                      title: Text(
                        invitation['email']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        invitation['status']?.toString() ?? 'pending',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                      trailing:
                          _canManageTeam && invitation['status'] == 'pending'
                          ? PopupMenuButton<String>(
                              tooltip: 'Invitation actions',
                              position: PopupMenuPosition.under,
                              onSelected: (action) async {
                                if (action == 'resend') {
                                  await _manageMember(
                                    'resend',
                                    '',
                                    inviteId: invitation['id']?.toString(),
                                  );
                                } else if (action == 'cancel' &&
                                    await _confirm(
                                      context,
                                      'Cancel this invitation?',
                                    )) {
                                  await _manageMember(
                                    'cancel-invitation',
                                    '',
                                    inviteId: invitation['id']?.toString(),
                                  );
                                }
                              },
                              itemBuilder: (_) => [
                                appMenuItem(
                                  value: 'resend',
                                  label: 'Resend invitation',
                                  icon: Icons.refresh_rounded,
                                ),
                                appMenuItem(
                                  value: 'cancel',
                                  label: 'Cancel invitation',
                                  icon: Icons.close_rounded,
                                  destructive: true,
                                ),
                              ],
                            )
                          : null,
                    ),
                ],
              ],
            ),
          ),
        ];
      case 3:
        final agenda = _forEvent('agenda');
        return [
          SectionCard(
            title: 'Agenda',
            subtitle:
                '${agenda.length} session${agenda.length == 1 ? '' : 's'} scheduled.',
            icon: Icons.schedule_rounded,
            trailing: _canEdit
                ? _compactAddButton(
                    'Add item',
                    Icons.add_rounded,
                    () => _editWork('agenda'),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            child: agenda.isEmpty
                ? const EmptyMessage(
                    'No sessions yet',
                    'Build the run of show for this event.',
                    icon: Icons.schedule_rounded,
                  )
                : Column(
                    children: [
                      for (var i = 0; i < agenda.length; i++) ...[
                        _agendaRow(agenda[i]),
                        if (i < agenda.length - 1)
                          const Divider(height: 1, indent: 52, endIndent: 10),
                      ],
                    ],
                  ),
          ),
        ];
      case 4:
        final files = _forEvent('files');
        return [
          SectionCard(
            title: 'Files',
            subtitle:
                '${files.length} file${files.length == 1 ? '' : 's'} · 20 MB max each',
            icon: Icons.folder_open_rounded,
            iconColor: blue,
            trailing: _canManageTeam
                ? _compactAddButton(
                    'Upload',
                    Icons.upload_file_rounded,
                    _uploadFile,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            child: files.isEmpty
                ? const EmptyMessage(
                    'No files yet',
                    'Upload an agenda, deck or handout for the team.',
                    icon: Icons.folder_open_rounded,
                  )
                : Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(14, 4, 14, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Files sync with your website workspace.',
                            style: TextStyle(color: iconSoft, fontSize: 11),
                          ),
                        ),
                      ),
                      for (var i = 0; i < files.length; i++) ...[
                        _fileRow(files[i]),
                        if (i < files.length - 1)
                          const Divider(height: 1, indent: 52, endIndent: 10),
                      ],
                    ],
                  ),
          ),
        ];
      case 5:
        return [
          SectionCard(
            title: 'Activity',
            subtitle: 'Recent changes to this event.',
            icon: Icons.history_rounded,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            child: widget.activity.isEmpty
                ? const EmptyMessage(
                    'No activity yet',
                    'Updates will appear here as the team works.',
                    icon: Icons.history_rounded,
                  )
                : Column(
                    children: [
                      for (var i = 0; i < widget.activity.length; i++) ...[
                        _activityRow(widget.activity[i], first: i == 0),
                        if (i < widget.activity.length - 1)
                          const Divider(height: 1, indent: 52, endIndent: 10),
                      ],
                    ],
                  ),
          ),
        ];
      case 6:
        return [
          if (_canManageSettings)
            _editEvent()
          else
            const EmptyCard(
              icon: Icons.lock_outline_rounded,
              title: 'Event settings',
              subtitle: 'Only the event owner can edit event settings.',
            ),
          if (!_isOwnerRecord) _membershipCard(),
        ];
      default:
        return [const Text('Event page unavailable.')];
    }
  }

  Widget _taskRow(Map<String, dynamic> task) {
    final done = task['status'] == 'done';
    final meta = [
      if ((task['notes']?.toString() ?? '').isNotEmpty)
        task['notes'].toString(),
      if (task['assigneeName'] != null) 'Assigned to ${task['assigneeName']}',
      if (task['dueAt'] != null) 'Due ${_formatDate(task['dueAt'])}',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 6, 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Checkbox(
              value: done,
              visualDensity: VisualDensity.compact,
              onChanged: _canEdit
                  ? (value) => _saveWork('task', {
                      ...task,
                      'status': value == true ? 'done' : 'open',
                    })
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title']?.toString() ?? '',
                    style: TextStyle(
                      color: done ? muted : ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      decoration: done ? TextDecoration.lineThrough : null,
                      height: 1.35,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      meta.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Task actions',
            position: PopupMenuPosition.under,
            onSelected: (action) => action == 'edit'
                ? _editWork('tasks', existing: task)
                : _deleteWork('task', task),
            itemBuilder: (_) => [
              if (_canEdit)
                appMenuItem(
                  value: 'edit',
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                ),
              if (_canDelete)
                appMenuItem(
                  value: 'delete',
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  destructive: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _membershipCard() {
    return SectionCard(
      title: 'Membership',
      subtitle: 'You are a ${widget.role} on this event.',
      icon: Icons.logout_rounded,
      iconColor: error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Leaving removes your access to the event, its tasks, agenda and files. You can rejoin only if someone invites you again.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.45),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _leaveEvent,
            icon: const Icon(Icons.logout_rounded, size: 17),
            label: const Text('Leave event'),
            style: OutlinedButton.styleFrom(
              foregroundColor: error,
              side: BorderSide(color: error.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveEvent() async {
    final ok = await _confirm(
      context,
      'Leave this event? You will lose access until you are invited again.',
    );
    if (!ok) return;
    try {
      await widget.backend.leaveEvent(widget.event.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You left the event.')));
      widget.onLeave?.call();
      widget.onTab(-1);
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    }
  }

  Widget _ownerRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: orangeLight,
            backgroundImage: _ownerAvatarUrl == null
                ? null
                : NetworkImage(_ownerAvatarUrl!),
            child: _ownerAvatarUrl == null
                ? Text(
                    userInitials(_ownerName),
                    style: const TextStyle(
                      color: orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOwnerRecord ? '$_ownerName (you)' : _ownerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isOwnerRecord ? widget.account.email : 'Event owner',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const _RoleChip(role: 'owner'),
        ],
      ),
    );
  }

  Widget _memberRow(Map<String, dynamic> member) {
    final memberRole = (member['role'] ?? 'member').toString();
    final canManage =
        _canManageTeam &&
        member['userId'] != widget.account.id &&
        (widget.role == 'owner' ||
            (memberRole != 'owner' && memberRole != 'admin'));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: orangeLight,
            child: Text(
              userInitials(member['name']?.toString() ?? '?'),
              style: const TextStyle(
                color: orange,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['name']?.toString() ?? 'Member',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 7,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _RoleChip(role: memberRole),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 190),
                      child: Text(
                        member['email']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              tooltip: 'Member actions',
              position: PopupMenuPosition.under,
              onSelected: (action) async {
                final userId = member['userId']?.toString();
                if (userId == null) return;
                if (action == 'role' && _canChangeRoles) {
                  final role = await showDialog<String>(
                    context: context,
                    builder: (dialogContext) => SimpleDialog(
                      title: const Text('Event role'),
                      children: [
                        for (final value in ['admin', 'member', 'viewer'])
                          SimpleDialogOption(
                            onPressed: () =>
                                Navigator.pop(dialogContext, value),
                            child: Row(
                              children: [
                                _RoleChip(role: value),
                                const SizedBox(width: 10),
                                Text(
                                  value[0].toUpperCase() + value.substring(1),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                  if (role != null) {
                    await _manageMember('change-role', userId, role: role);
                  }
                } else if (action == 'remove' &&
                    await _confirm(
                      context,
                      'Remove this member from the event?',
                    )) {
                  await _manageMember('remove', userId);
                }
              },
              itemBuilder: (_) => [
                if (_canChangeRoles)
                  appMenuItem(
                    value: 'role',
                    label: 'Change role',
                    icon: Icons.manage_accounts_outlined,
                  ),
                appMenuItem(
                  value: 'remove',
                  label: 'Remove member',
                  icon: Icons.person_remove_outlined,
                  destructive: true,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _agendaStatusChip(String status) {
    final (color, tint) = switch (status) {
      'live' => (blue, blueLight),
      'completed' => (success, successTint),
      'cancelled' => (error, errorTint),
      _ => (muted, softFill),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _agendaRow(Map<String, dynamic> item) {
    final description = item['description']?.toString() ?? '';
    final extras = [item['location'], item['speakerName']]
        .where((value) => value != null && value.toString().isNotEmpty)
        .join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconTile(
            icon: Icons.schedule_rounded,
            color: blue,
            size: 38,
            radius: 11,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item['title']?.toString() ?? '',
                        style: const TextStyle(
                          color: ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _agendaStatusChip(
                      item['status']?.toString() ?? 'scheduled',
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatDate(item['startsAt'])} · ${item['durationMinutes'] ?? 30} minutes',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                ],
                if (extras.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 12,
                        color: iconSoft,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          extras,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: iconSoft,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Session actions',
            position: PopupMenuPosition.under,
            onSelected: (action) => action == 'edit'
                ? _editWork('agenda', existing: item)
                : _deleteWork('agenda', item),
            itemBuilder: (_) => [
              if (_canEdit)
                appMenuItem(
                  value: 'edit',
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                ),
              if (_canDelete)
                appMenuItem(
                  value: 'delete',
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  destructive: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fileRow(Map<String, dynamic> file) {
    return InkWell(
      onTap: () => _downloadFile(file),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            const IconTile(
              icon: Icons.attach_file_rounded,
              color: blue,
              size: 38,
              radius: 11,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file['name']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${file['mimeType'] ?? 'File'} · ${_size(file['sizeBytes'])} · ${file['uploaderName'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'File actions',
              position: PopupMenuPosition.under,
              onSelected: (action) => action == 'rename'
                  ? _renameFile(file)
                  : action == 'delete'
                  ? _deleteWork('file', file)
                  : _downloadFile(file),
              itemBuilder: (_) => [
                appMenuItem(
                  value: 'download',
                  label: 'Download / share',
                  icon: Icons.download_rounded,
                ),
                if (_canDelete)
                  appMenuItem(
                    value: 'rename',
                    label: 'Rename',
                    icon: Icons.drive_file_rename_outline_rounded,
                  ),
                if (_canDelete)
                  appMenuItem(
                    value: 'delete',
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    destructive: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityRow(Map<String, dynamic> activity, {bool first = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: Icons.bolt_rounded,
            color: first ? orange : iconSoft,
            background: first ? orangeLight : softFill,
            size: 36,
            radius: 11,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['summary']?.toString() ?? 'Event update',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${activity['actorName'] ?? 'A teammate'} · ${_formatDate(activity['createdAt'])}',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactAddButton(String title, IconData icon, VoidCallback action) =>
      FilledButton.icon(
        onPressed: _busy ? null : action,
        icon: Icon(icon, size: 17),
        label: Text(title),
        style: FilledButton.styleFrom(
          backgroundColor: orangeLight,
          foregroundColor: orange,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: const BorderSide(color: orangeBorder),
          ),
        ),
      );

  Future<void> _editWork(String kind, {Map<String, dynamic>? existing}) async {
    final title = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final notes = TextEditingController(
      text: (existing?['notes'] ?? existing?['description'])?.toString() ?? '',
    );
    final due = TextEditingController(
      text: existing?['dueAt'] == null
          ? ''
          : _localInputDate(existing?['dueAt']),
    );
    final starts = TextEditingController(
      text: _localInputDate(
        existing?['startsAt'] ?? widget.event.date.toIso8601String(),
      ),
    );
    final duration = TextEditingController(
      text: '${existing?['durationMinutes'] ?? 30}',
    );
    final location = TextEditingController(
      text: existing?['location']?.toString() ?? widget.event.location,
    );
    final speaker = TextEditingController(
      text: existing?['speakerName']?.toString() ?? '',
    );
    final assignee = TextEditingController(
      text: existing?['assigneeId']?.toString() ?? '',
    );
    final assigneeOptions = <AppSelectOption<String>>[
      const AppSelectOption('', 'Unassigned'),
      if (widget.account.id.isNotEmpty)
        AppSelectOption(widget.account.id, '${widget.account.name} (you)'),
      ...widget.members
          .where(
            (member) =>
                member['eventId'] == widget.event.id &&
                member['userId'] != widget.account.id,
          )
          .map(
            (member) => AppSelectOption(
              member['userId']?.toString() ?? '',
              member['name']?.toString() ??
                  member['email']?.toString() ??
                  'Teammate',
            ),
          ),
    ];
    final assigneeValue =
        assigneeOptions.any((option) => option.value == assignee.text)
        ? assignee.text
        : '';
    var agendaStatus = existing?['status']?.toString() ?? 'scheduled';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          '${existing == null ? 'New' : 'Edit'} ${kind == 'tasks' ? 'task' : 'agenda session'}',
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: notes,
                  decoration: InputDecoration(
                    labelText: kind == 'tasks' ? 'Notes' : 'Description',
                  ),
                ),
                if (kind == 'tasks') ...[
                  TextField(
                    controller: due,
                    decoration: const InputDecoration(
                      labelText: 'Due date (YYYY-MM-DD HH:MM)',
                    ),
                  ),
                  AppDropdownField<String>(
                    label: 'Assignee',
                    value: assigneeValue,
                    prefixIcon: Icons.person_outline_rounded,
                    options: assigneeOptions,
                    onChanged: (value) => assignee.text = value ?? '',
                  ),
                ] else ...[
                  TextField(
                    controller: starts,
                    decoration: const InputDecoration(
                      labelText: 'Starts (YYYY-MM-DD HH:MM)',
                    ),
                  ),
                  TextField(
                    controller: duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duration (minutes)',
                    ),
                  ),
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                  TextField(
                    controller: speaker,
                    decoration: const InputDecoration(
                      labelText: 'Speaker / host',
                    ),
                  ),
                  AppDropdownField<String>(
                    label: 'Status',
                    value: agendaStatus,
                    prefixIcon: Icons.flag_outlined,
                    options: const [
                      AppSelectOption('scheduled', 'Scheduled'),
                      AppSelectOption('live', 'Live'),
                      AppSelectOption('completed', 'Completed'),
                      AppSelectOption('cancelled', 'Cancelled'),
                    ],
                    onChanged: (value) => agendaStatus = value ?? agendaStatus,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final data = <String, dynamic>{
                'title': title.text.trim(),
                'notes': notes.text.trim(),
                'description': notes.text.trim(),
              };
              if (kind == 'tasks') {
                data['dueAt'] = due.text.trim().isEmpty
                    ? null
                    : _parseLocalDate(due.text.trim());
                data['assigneeId'] = assignee.text.trim().isEmpty
                    ? null
                    : assignee.text.trim();
              } else {
                data.addAll({
                  'startsAt': _parseLocalDate(starts.text.trim()),
                  'durationMinutes': int.tryParse(duration.text) ?? 30,
                  'location': location.text.trim(),
                  'speakerName': speaker.text.trim(),
                  'status': agendaStatus,
                });
              }
              Navigator.pop(c, data);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result['title'] == '') return;
    final now = DateTime.now().toUtc().toIso8601String();
    final entity = <String, dynamic>{
      ...?existing,
      ...result,
      'id': existing?['id'] ?? _mobileWorkId(),
      'eventId': widget.event.id,
      'createdAt': existing?['createdAt'] ?? now,
      'updatedAt': now,
      if (kind == 'tasks') 'status': existing?['status'] ?? 'open',
    };
    await _saveWork(kind == 'tasks' ? 'task' : 'agenda', entity);
  }

  String _localInputDate(Object? value) {
    final dt = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (dt == null) return '';
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _parseLocalDate(String input) {
    final dt = DateTime.tryParse(input.trim().replaceFirst(' ', 'T'));
    if (dt == null) {
      throw const FormatException('Use date/time format YYYY-MM-DD HH:MM.');
    }
    return dt.toUtc().toIso8601String();
  }

  Future<void> _uploadFile() async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.any,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Could not read the selected file.');
      return;
    }
    try {
      await widget.backend.uploadEventFile(
        widget.event.id!,
        file.name,
        lookupMimeType(file.name) ?? 'application/octet-stream',
        bytes,
      );
      widget.onReload();
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    }
  }

  Future<void> _downloadFile(Map<String, dynamic> file) async {
    try {
      final bytes = await widget.backend.downloadEventFile(
        file['id'].toString(),
        file['updatedAt'].toString(),
        (file['sizeBytes'] as num).toInt(),
      );
      final dir = await getTemporaryDirectory();
      final name = file['name']?.toString() ?? 'event-file';
      final safeName = name.replaceAll(RegExp(r'[/\\\\]'), '_');
      final path = '${dir.path}/$safeName';
      await XFile.fromData(
        Uint8List.fromList(bytes),
        name: name,
        mimeType: file['mimeType']?.toString(),
      ).saveTo(path);
      final opened = await OpenFilex.open(path);
      if (opened.type != ResultType.done && mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path, mimeType: file['mimeType']?.toString())],
            text: name,
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    }
  }

  Future<void> _renameFile(Map<String, dynamic> file) async {
    final controller = TextEditingController(
      text: file['name']?.toString() ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'File name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == file['name']) return;
    if (name.contains('/') || name.contains('\\')) {
      if (mounted) {
        setState(() => _error = 'File name cannot contain a path separator.');
      }
      return;
    }
    await _saveWork('file', {...file, 'name': name});
  }

  Future<void> _shareCalendarEvent() async {
    final event = widget.event;
    String escape(String value) => value
        .replaceAll('\\', '\\\\')
        .replaceAll('\n', r'\n')
        .replaceAll(',', r'\,')
        .replaceAll(';', r'\;');
    String stamp(DateTime value) => value
        .toUtc()
        .toIso8601String()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .replaceAll(RegExp(r'\.\d+'), '');
    final lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//EventPulse//Android//EN',
      'CALSCALE:GREGORIAN',
      'BEGIN:VEVENT',
      'UID:${event.id}@eventpulse',
      'DTSTAMP:${stamp(DateTime.now())}',
      'DTSTART:${stamp(event.date)}',
      'DTEND:${stamp(event.date.add(const Duration(hours: 2)))}',
      'SUMMARY:${escape(event.title)}',
      'DESCRIPTION:${escape(event.description)}',
      'LOCATION:${escape(event.location)}',
      'END:VEVENT',
      'END:VCALENDAR',
    ];
    final dir = await getTemporaryDirectory();
    final safeName = event.title
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final file = File(
      '${dir.path}/${safeName.isEmpty ? 'event' : safeName}.ics',
    );
    await file.writeAsString('${lines.join('\r\n')}\r\n');
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/calendar')],
        subject: 'Add ${event.title} to calendar',
      ),
    );
  }

  Future<void> _runSheetMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('Print run sheet'),
              subtitle: const Text('Open the Android print dialog.'),
              onTap: () => Navigator.pop(c, 'print'),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Share run sheet PDF'),
              subtitle: const Text('Send the run sheet to another app.'),
              onTap: () => Navigator.pop(c, 'share'),
            ),
          ],
        ),
      ),
    );
    if (action == 'print') {
      await _printRunSheet();
    } else if (action == 'share') {
      await _shareRunSheet();
    }
  }

  Future<void> _printRunSheet() async {
    try {
      final bytes = await _buildRunSheetPdf();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${widget.event.title} run sheet',
      );
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    }
  }

  Future<void> _shareRunSheet() async {
    try {
      final bytes = await _buildRunSheetPdf();
      await Printing.sharePdf(bytes: bytes, filename: 'run-sheet.pdf');
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    }
  }

  Future<Uint8List> _buildRunSheetPdf() async {
    final event = widget.event;
    final tasks = _forEvent('tasks');
    final agenda = _forEvent('agenda');
    final members = widget.members
        .where((member) => member['eventId'] == event.id)
        .toList();
    final done = tasks.where((task) => task['status'] == 'done').length;
    final dark = PdfColor.fromHex('#16201B');
    final grey = PdfColor.fromHex('#6C7B73');
    final orange = PdfColor.fromHex('#D96C2D');
    final lineColor = PdfColor.fromHex('#D9D5CB');

    String when(Object? value) {
      final dt = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
      if (dt == null) return '';
      return '${shortDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    final document = pw.Document(
      title: '${event.title} run sheet',
      author: 'EventPulse',
    );
    final headerStyle = pw.TextStyle(
      fontSize: 7.5,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final cellStyle = pw.TextStyle(fontSize: 8, color: dark);
    final headerDecoration = pw.BoxDecoration(
      color: PdfColor.fromHex('#193B30'),
    );

    pw.Widget sectionTitle(String title) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: dark,
        ),
      ),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Generated ${when(DateTime.now().toIso8601String())} · EventPulse',
            style: pw.TextStyle(fontSize: 7, color: grey),
          ),
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F5F8F4'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'EVENTPULSE · RUN SHEET',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    letterSpacing: 1.2,
                    color: orange,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  event.title,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: dark,
                  ),
                ),
                if (event.description.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    event.description,
                    style: pw.TextStyle(fontSize: 9, color: grey),
                  ),
                ],
                pw.SizedBox(height: 8),
                pw.Text(
                  longDate(event.date),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: dark,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  event.location,
                  style: pw.TextStyle(fontSize: 9, color: grey),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  [
                    event.capacity == null
                        ? 'Unlimited capacity'
                        : '${event.capacity} guests',
                    '$done of ${tasks.length} tasks complete',
                  ].join(' · '),
                  style: pw.TextStyle(fontSize: 9, color: grey),
                ),
              ],
            ),
          ),
          sectionTitle('Schedule · ${agenda.length} sessions'),
          if (agenda.isEmpty)
            pw.Text(
              'No sessions scheduled.',
              style: pw.TextStyle(fontSize: 9, color: grey),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Time', 'Session', 'Min', 'Status'],
              data: [
                for (final item in agenda)
                  [
                    when(item['startsAt']),
                    item['title']?.toString() ?? '',
                    '${item['durationMinutes'] ?? 30}',
                    item['status']?.toString() ?? 'scheduled',
                  ],
              ],
              headerStyle: headerStyle,
              headerDecoration: headerDecoration,
              cellStyle: cellStyle,
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 4,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.4),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(0.6),
                3: const pw.FlexColumnWidth(1),
              },
            ),
          sectionTitle('Team · ${members.length + 1} members'),
          pw.TableHelper.fromTextArray(
            headers: const ['Name', 'Email', 'Role'],
            data: [
              [
                _ownerName,
                _isOwnerRecord ? widget.account.email : 'Event owner',
                'owner',
              ],
              for (final member in members)
                [
                  member['name']?.toString() ?? '',
                  member['email']?.toString() ?? '',
                  member['role']?.toString() ?? 'member',
                ],
            ],
            headerStyle: headerStyle,
            headerDecoration: headerDecoration,
            cellStyle: cellStyle,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 4,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.4),
              1: const pw.FlexColumnWidth(2.4),
              2: const pw.FlexColumnWidth(0.8),
            },
          ),
          sectionTitle('Operations checklist · $done/${tasks.length}'),
          if (tasks.isEmpty)
            pw.Text(
              'No tasks on the checklist.',
              style: pw.TextStyle(fontSize: 9, color: grey),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Done', 'Task', 'Assignee', 'Due'],
              data: [
                for (final task in tasks)
                  [
                    task['status'] == 'done' ? '✓' : '',
                    task['title']?.toString() ?? '',
                    task['assigneeName']?.toString() ?? 'Unassigned',
                    task['dueAt'] == null ? '' : when(task['dueAt']),
                  ],
              ],
              headerStyle: headerStyle,
              headerDecoration: headerDecoration,
              cellStyle: cellStyle,
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 4,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
            ),
          sectionTitle('Day-of notes'),
          for (var i = 0; i < 3; i++)
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 12),
              height: 1,
              color: lineColor,
            ),
        ],
      ),
    );
    return document.save();
  }

  Future<void> _duplicateEvent() async {
    final title = TextEditingController(text: '${widget.event.title} (copy)');
    final date = DateTime.now().add(const Duration(days: 7));
    final dateText = TextEditingController(
      text:
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    );
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Duplicate event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Event title'),
            ),
            TextField(
              controller: dateText,
              decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(c, (title.text.trim(), dateText.text.trim())),
            child: const Text('Create copy'),
          ),
        ],
      ),
    );
    if (values == null) return;
    final newDate = DateTime.tryParse(values.$2);
    if (newDate == null || values.$1.length < 3) {
      setState(() => _error = 'Enter a valid title and date.');
      return;
    }
    try {
      final copy = await widget.backend.createEvent(
        title: values.$1,
        description: widget.event.description,
        category: widget.event.category,
        venue: widget.event.location,
        startsAt: newDate,
        capacity: widget.event.capacity,
        visibility: widget.event.visibility,
      );
      final copyId = copy['id'].toString();
      final now = DateTime.now().toUtc().toIso8601String();
      final shift = newDate.difference(widget.event.date);
      for (final task in _forEvent('tasks')) {
        await widget.backend.saveWorkItem('task', {
          ...task,
          'id': _mobileWorkId(),
          'eventId': copyId,
          'status': 'open',
          if (task['dueAt'] != null)
            'dueAt': DateTime.parse(
              task['dueAt'].toString(),
            ).add(shift).toUtc().toIso8601String(),
          'createdAt': now,
          'updatedAt': now,
        });
      }
      for (final agenda in _forEvent('agenda')) {
        await widget.backend.saveWorkItem('agenda', {
          ...agenda,
          'id': _mobileWorkId(),
          'eventId': copyId,
          if (agenda['startsAt'] != null)
            'startsAt': DateTime.parse(
              agenda['startsAt'].toString(),
            ).add(shift).toUtc().toIso8601String(),
          'createdAt': now,
          'updatedAt': now,
        });
      }
      widget.onReload();
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    }
  }

  Future<void> _saveWork(String kind, Map<String, dynamic> value) async {
    setState(() => _busy = true);
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await widget.backend.saveWorkItem(kind, {
        ...value,
        'eventId': widget.event.id,
        'updatedAt': now,
      });
      widget.onReload();
    } catch (e) {
      setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteWork(String kind, Map<String, dynamic> value) async {
    if (!await _confirm(
      context,
      'Delete "${value['title'] ?? value['name']}"?',
    )) {
      return;
    }
    try {
      await widget.backend.deleteWorkItem(
        kind,
        widget.event.id ?? '',
        _id(value),
      );
      widget.onReload();
    } catch (e) {
      setState(() => _error = _messageFor(e));
    }
  }

  Future<Map<String, dynamic>?> _manageMember(
    String action,
    String memberId, {
    String? userId,
    String? role,
    String? inviteId,
  }) async {
    try {
      final result = await widget.backend.manageEventMembers(
        widget.event.id!,
        action,
        userId: userId,
        memberId: memberId.isEmpty ? null : memberId,
        inviteId: inviteId,
        role: role,
      );
      widget.onReload();
      final message = result['message']?.toString();
      if (message != null && message.isNotEmpty && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return result;
    } catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
      return null;
    }
  }

  Future<void> _addMemberMenu() async {
    final action = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Add a teammate'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, 'invite'),
            child: const ListTile(
              leading: Icon(Icons.mail_outline_rounded),
              title: Text('Invite by email'),
              subtitle: Text('Send an invitation link to someone new.'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, 'existing'),
            child: const ListTile(
              leading: Icon(Icons.person_add_alt_1_rounded),
              title: Text('Add existing workspace user'),
              subtitle: Text('Give an existing account access right away.'),
            ),
          ),
        ],
      ),
    );
    if (action == 'invite') {
      await _invite();
    } else if (action == 'existing') {
      await _addExistingMember();
    }
  }

  Future<void> _invite() async {
    final email = TextEditingController();
    var role = 'member';
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: const Text('Invite by email'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email address'),
                ),
                const SizedBox(height: 12),
                AppDropdownField<String>(
                  label: 'Role',
                  value: role,
                  options: const [
                    AppSelectOption('member', 'Member'),
                    AppSelectOption('admin', 'Admin'),
                    AppSelectOption('viewer', 'Viewer'),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => role = value ?? 'member'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, (email.text.trim(), role)),
              child: const Text('Send invitation'),
            ),
          ],
        ),
      ),
    );
    if (result == null || result.$1.isEmpty) return;
    try {
      final r = await widget.backend.manageEventMembers(
        widget.event.id!,
        'invite',
        email: result.$1,
        role: result.$2,
      );
      final msg = r['message']?.toString() ?? 'Invitation created.';
      final inviteUrl = r['inviteUrl']?.toString();
      widget.onReload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            action: inviteUrl == null || inviteUrl.isEmpty
                ? null
                : SnackBarAction(
                    label: 'Copy link',
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: inviteUrl)),
                  ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
    }
  }

  Future<void> _addExistingMember() async {
    final candidates = widget.availableUsers
        .where((user) => (user['id']?.toString() ?? '').isNotEmpty)
        .toList();
    if (candidates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Every workspace account already has access to this event.',
            ),
          ),
        );
      }
      return;
    }
    var selected = candidates.first['id'].toString();
    var role = 'member';
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: const Text('Add workspace user'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppDropdownField<String>(
                  label: 'Workspace user',
                  value: selected,
                  options: [
                    for (final user in candidates)
                      AppSelectOption(
                        user['id'].toString(),
                        '${user['name'] ?? user['email'] ?? 'User'} · ${user['email'] ?? ''}',
                      ),
                  ],
                  onChanged: (value) => setDialogState(
                    () => selected = value ?? candidates.first['id'].toString(),
                  ),
                ),
                const SizedBox(height: 12),
                AppDropdownField<String>(
                  label: 'Role',
                  value: role,
                  options: const [
                    AppSelectOption('member', 'Member'),
                    AppSelectOption('admin', 'Admin'),
                    AppSelectOption('viewer', 'Viewer'),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => role = value ?? 'member'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, (selected, role)),
              child: const Text('Add to event'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await _manageMember('add', '', userId: result.$1, role: result.$2);
  }

  Widget _editEvent() => _EventSettingsEditor(
    event: widget.event,
    canDelete: _canDeleteEvent,
    onSave: widget.onSave,
    onDelete: widget.onDelete,
  );
}

class _EventPill extends StatelessWidget {
  const _EventPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.tint,
    required this.border,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color tint;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMeta extends StatelessWidget {
  const _HeaderMeta({
    required this.icon,
    required this.text,
    this.maxWidth = 220,
  });

  final IconData icon;
  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconSoft),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: softFill,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: orange),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final (color, tint) = switch (role) {
      'owner' => (orange, orangeLight),
      'admin' => (blue, blueLight),
      'viewer' => (muted, softFill),
      _ => (mutedStrong, softFill),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        role[0].toUpperCase() + role.substring(1),
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EventSettingsEditor extends StatefulWidget {
  const _EventSettingsEditor({
    required this.event,
    required this.canDelete,
    required this.onSave,
    required this.onDelete,
  });
  final EventItem event;
  final bool canDelete;
  final ValueChanged<Map<String, dynamic>> onSave;
  final VoidCallback onDelete;

  @override
  State<_EventSettingsEditor> createState() => _EventSettingsEditorState();
}

class _EventSettingsEditorState extends State<_EventSettingsEditor> {
  late final title = TextEditingController(text: widget.event.title);
  late final description = TextEditingController(
    text: widget.event.description,
  );
  late final venue = TextEditingController(
    text: widget.event.location == 'Location to be announced'
        ? ''
        : widget.event.location,
  );
  late final capacity = TextEditingController(
    text: widget.event.capacity?.toString() ?? '',
  );
  late DateTime startsAt = widget.event.date;
  late String category = widget.event.category;
  late String visibility = widget.event.visibility;

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    venue.dispose();
    capacity.dispose();
    super.dispose();
  }

  String _formatEditorDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: startsAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(startsAt),
    );
    if (time != null) {
      setState(
        () => startsAt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: muted,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
    return SectionCard(
      title: 'Event settings',
      subtitle: 'Update the details guests see.',
      icon: Icons.settings_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          sectionLabel('EVENT DETAILS'),
          TextField(
            controller: title,
            decoration: const InputDecoration(
              labelText: 'Event title',
              prefixIcon: Icon(Icons.title_rounded, size: 19),
            ),
          ),
          TextField(
            controller: description,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
            ),
          ),
          AppDropdownField<String>(
            label: 'Category',
            value:
                [
                  'Conference',
                  'Workshop',
                  'Meetup',
                  'Webinar',
                  'Party',
                  'Other',
                ].contains(category)
                ? category
                : 'Other',
            prefixIcon: Icons.category_outlined,
            options: const [
              AppSelectOption('Conference', 'Conference'),
              AppSelectOption('Workshop', 'Workshop'),
              AppSelectOption('Meetup', 'Meetup'),
              AppSelectOption('Webinar', 'Webinar'),
              AppSelectOption('Party', 'Party'),
              AppSelectOption('Other', 'Other'),
            ],
            onChanged: (value) {
              if (value != null) setState(() => category = value);
            },
          ),
          sectionLabel('DATE & VENUE'),
          Material(
            color: fieldFill,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: const BorderSide(color: line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _pickDateTime,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const IconTile(
                      icon: Icons.calendar_today_outlined,
                      color: orange,
                      size: 38,
                      radius: 11,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date and start time',
                            style: TextStyle(
                              color: muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatEditorDate(startsAt),
                            style: const TextStyle(
                              color: ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.edit_calendar_outlined,
                      color: orange,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
          TextField(
            controller: venue,
            decoration: const InputDecoration(
              labelText: 'Venue',
              prefixIcon: Icon(Icons.location_on_outlined, size: 19),
            ),
          ),
          TextField(
            controller: capacity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Capacity (optional)',
              hintText: 'Unlimited',
              prefixIcon: Icon(Icons.groups_outlined, size: 19),
            ),
          ),
          sectionLabel('ACCESS'),
          AppDropdownField<String>(
            label: 'Visibility',
            value: visibility == 'public' ? 'public' : 'private',
            prefixIcon: Icons.visibility_outlined,
            options: const [
              AppSelectOption(
                'private',
                'Private',
                icon: Icons.lock_outline_rounded,
                description: 'Members only',
              ),
              AppSelectOption(
                'public',
                'Public',
                icon: Icons.public_rounded,
                description: 'Workspace read-only',
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => visibility = value);
            },
          ),
          const SizedBox(height: 4),
          FilledButton.icon(
            onPressed: () {
              final cap = capacity.text.trim().isEmpty
                  ? null
                  : int.tryParse(capacity.text.trim());
              if (title.text.trim().length < 3 ||
                  (capacity.text.trim().isNotEmpty &&
                      (cap == null || cap < 1))) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter a title of at least 3 characters and a valid capacity.',
                    ),
                  ),
                );
                return;
              }
              widget.onSave({
                'id': widget.event.id,
                'title': title.text.trim(),
                'description': description.text.trim(),
                'venue': venue.text.trim(),
                'category': category,
                'startsAt': startsAt.toUtc().toIso8601String(),
                'capacity': cap,
                'visibility': visibility,
                'createdAt':
                    widget.event.createdAt ??
                    DateTime.now().toUtc().toIso8601String(),
              });
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Save changes'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (widget.canDelete) ...[
            const Divider(color: line),
            TextButton.icon(
              onPressed: () =>
                  _confirm(context, 'Delete this event permanently?').then((
                    ok,
                  ) {
                    if (ok) widget.onDelete();
                  }),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete event'),
              style: TextButton.styleFrom(foregroundColor: error),
            ),
          ],
        ],
      ),
    );
  }
}

String _messageFor(Object e) => switch (e) {
  BackendException() => e.message,
  FormatException() => e.message,
  _ => e.toString(),
};

String _formatDate(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return '';
  return shortDate(date.toLocal());
}

String _size(Object? raw) {
  final bytes = (raw as num?)?.toInt() ?? 0;
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

Future<bool> _confirm(BuildContext context, String text) async =>
    (await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm action'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: _ink),
            child: const Text('Confirm'),
          ),
        ],
      ),
    )) ??
    false;
Future<String?> _passwordDialog(BuildContext context) async {
  final p = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Reset password'),
      content: TextField(
        controller: p,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'New password (6+ characters)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, p.text),
          child: const Text('Reset'),
        ),
      ],
    ),
  );
}
