import 'package:eventmanagerandroid/main.dart';
import 'package:eventmanagerandroid/mobile_backend.dart';
import 'package:eventmanagerandroid/ui/flavor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackend extends MobileBackendService {
  _FakeBackend({this.signedOut = false});

  final bool signedOut;
  final account = const MobileAccount(
    id: 'user-1',
    name: 'Minh Tran',
    email: 'minh@example.com',
  );
  final events = <Map<String, dynamic>>[];
  final sharedEvents = <Map<String, dynamic>>[];
  final members = <Map<String, dynamic>>[];
  final eventInvitations = <Map<String, dynamic>>[];
  final invitations = <Map<String, dynamic>>[];
  final notifications = <Map<String, dynamic>>[];
  final templates = <Map<String, dynamic>>[];

  @override
  Future<MobileAccount?> restoreSession() async => signedOut ? null : account;

  @override
  Future<MobileAccount> signInWithGoogle() async => account;

  @override
  Future<MobileSyncBatch> pull() async => MobileSyncBatch(
    snapshot: true,
    events: List<Map<String, dynamic>>.from(events),
    changes: const [],
    sharedEvents: List<Map<String, dynamic>>.from(sharedEvents),
    invitations: List<Map<String, dynamic>>.from(invitations),
    members: List<Map<String, dynamic>>.from(members),
    notifications: List<Map<String, dynamic>>.from(notifications),
    preferences: const {},
    profile: const {},
  );

  @override
  Future<Map<String, dynamic>> eventMembers(String eventId) async => {
    'members': members.where((member) => member['eventId'] == eventId).toList(),
    'users': const <Map<String, dynamic>>[],
    'invitations': eventInvitations
        .where((invitation) => invitation['eventId'] == eventId)
        .toList(),
  };

  @override
  Future<void> respondToInvitation(
    String invitationId,
    String response,
  ) async {}

  @override
  Future<List<Map<String, dynamic>>> listTemplates() async => templates;

  @override
  Future<Map<String, dynamic>> saveTemplate(
    Map<String, dynamic> template,
  ) async {
    templates.add(template);
    return template;
  }

  @override
  Future<void> markNotificationRead({
    String? notificationId,
    bool markAll = false,
  }) async {
    for (final notification in notifications) {
      if (markAll || notification['id'] == notificationId) {
        notification['readAt'] = DateTime.now().toIso8601String();
      }
    }
  }

  @override
  Future<void> updatePreferences(Map<String, dynamic> preferences) async {}

  @override
  Future<MobileAccount?> updateProfileName(String name) async => MobileAccount(
    id: account.id,
    name: name,
    email: account.email,
    workspaceRole: account.workspaceRole,
  );

  @override
  Future<Map<String, dynamic>> createEvent({
    required String title,
    required String description,
    required String category,
    required String venue,
    required DateTime startsAt,
    int? capacity,
    String visibility = 'private',
  }) async {
    final event = <String, dynamic>{
      'id': 'event-${events.length + 1}',
      'title': title,
      'description': description,
      'category': category,
      'venue': venue,
      'startsAt': startsAt.toUtc().toIso8601String(),
      'capacity': capacity,
      'visibility': visibility,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    events.add(event);
    return event;
  }

  @override
  Future<void> signOut({bool revokeDevice = true}) async {}
}

void main() {
  testWidgets('sign-in offers email, password, registration and Google', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeBackend(signedOut: true);
    await tester.pumpWidget(EventPulseApp(backend: backend));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Email'), findsWidgets);
    expect(find.text('Username'), findsNothing);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);

    await tester.ensureVisible(
      find.text('New to EventPulse? Create an account'),
    );
    await tester.tap(find.text('New to EventPulse? Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
  });

  testWidgets('dashboard shows the signed-in account and backend events', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeBackend();
    backend.sharedEvents.add({'id': 'shared-event'});
    backend.members.addAll([
      {'userId': 'user-2'},
      {'userId': 'user-2'},
    ]);
    backend.events.add({
      'id': 'event-existing',
      'title': 'Website workshop',
      'description': '',
      'category': 'Workshop',
      'venue': 'Online',
      'startsAt': DateTime.now()
          .add(const Duration(days: 3))
          .toUtc()
          .toIso8601String(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });

    await tester.pumpWidget(
      EventPulseApp(
        home: EventPulseHome(account: backend.account, backend: backend),
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Minh'), findsOneWidget);
    expect(find.text('Website workshop'), findsWidgets);
    expect(find.text('UPCOMING EVENTS'), findsOneWidget);
    expect(find.text('Events shared with you'), findsOneWidget);
    expect(find.text('Across your event workspace'), findsOneWidget);
  });

  testWidgets('new events are written through the shared backend', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeBackend();
    await tester.pumpWidget(
      EventPulseApp(
        home: EventPulseHome(account: backend.account, backend: backend),
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create event'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Flutter meetup');
    await tester.tap(find.text('Create event').last);
    await tester.pumpAndSettle();

    expect(backend.events, hasLength(1));
    expect(backend.events.single['title'], 'Flutter meetup');
    expect(find.text('Flutter meetup'), findsOneWidget);
  });

  testWidgets('mobile navigation opens the calendar', (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeBackend();
    await tester.pumpWidget(
      EventPulseApp(
        home: EventPulseHome(account: backend.account, backend: backend),
        backend: backend,
      ),
    );
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Nothing on the calendar'), findsOneWidget);
  });

  testWidgets('event workspace exposes its website sections', (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeBackend();
    backend.events.add({
      'id': 'owned-event',
      'title': 'Team meetup',
      'description': 'Planning day',
      'category': 'Workshop',
      'venue': 'Office',
      'startsAt': DateTime.now().toUtc().toIso8601String(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'ownerId': backend.account.id,
    });
    await tester.pumpWidget(
      EventPulseApp(
        home: EventPulseHome(account: backend.account, backend: backend),
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Team meetup').first);
    await tester.tap(find.text('Team meetup').first);
    await tester.pumpAndSettle();

    for (final page in [
      'Overview',
      'Tasks',
      'Members',
      'Schedule',
      'Files',
      'Activity',
      'Settings',
    ]) {
      expect(find.text(page), findsWidgets);
    }
    await tester.tap(find.text('Tasks').last);
    await tester.pumpAndSettle();
    expect(find.text('Add task'), findsOneWidget);
    expect(find.text('Event settings'), findsNothing);
  });

  testWidgets('event team shows the organizer and add-member entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeBackend();
    backend.events.add({
      'id': 'owned-event',
      'title': 'Owner event',
      'description': '',
      'category': 'Meetup',
      'venue': 'Office',
      'startsAt': DateTime.now()
          .add(const Duration(days: 2))
          .toUtc()
          .toIso8601String(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'ownerId': backend.account.id,
    });
    backend.eventInvitations.add({
      'id': 'pending-invite',
      'eventId': 'owned-event',
      'email': 'pending@example.com',
      'role': 'member',
      'status': 'pending',
    });
    await tester.pumpWidget(
      EventPulseApp(
        home: EventPulseHome(account: backend.account, backend: backend),
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Owner event').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Members').last);
    await tester.pumpAndSettle();

    expect(find.text('Minh Tran (you)'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('No other members yet'), findsOneWidget);
    expect(find.text('PENDING INVITATIONS'), findsOneWidget);
    expect(find.text('pending@example.com'), findsOneWidget);
  });

  testWidgets('shared event members can leave from settings', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeBackend();
    backend.sharedEvents.add({
      'id': 'shared-event',
      'title': 'Partner summit',
      'description': 'Cross-team planning',
      'category': 'Conference',
      'venue': 'Hall C',
      'startsAt': DateTime.now()
          .add(const Duration(days: 5))
          .toUtc()
          .toIso8601String(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'ownerId': 'owner-2',
      'ownerName': 'Alex Rivera',
    });
    backend.members.add({
      'eventId': 'shared-event',
      'userId': backend.account.id,
      'name': backend.account.name,
      'email': backend.account.email,
      'role': 'member',
      'status': 'accepted',
    });
    await tester.pumpWidget(
      EventPulseApp(
        home: EventPulseHome(account: backend.account, backend: backend),
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Partner summit').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    expect(find.text('Membership'), findsOneWidget);
    expect(find.text('Leave event'), findsOneWidget);

    await tester.ensureVisible(find.text('Leave event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Partner summit'), findsOneWidget);
  });

  testWidgets(
    'Direct navigation reaches profile, settings, templates and notifications',
    (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final backend = _FakeBackend();
      backend.notifications.add({
        'id': 'notice-1',
        'title': 'Event updated',
        'message': 'Details changed',
        'readAt': null,
      });
      await tester.pumpWidget(
        EventPulseApp(
          home: EventPulseHome(account: backend.account, backend: backend),
          backend: backend,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Your account identity and workspace access.'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Account options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Manage preferences and calendar access.'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Account options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Templates').last);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Built-in presets and event structures saved on this device.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Event updated'), findsOneWidget);

      await tester.tap(find.byTooltip('Account options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Activity'));
      await tester.pumpAndSettle();
      expect(find.text('My activity'), findsOneWidget);
    },
  );

  testWidgets('Direct navigation opens Search and Help pages', (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeBackend();
    await tester.pumpWidget(
      EventPulseApp(
        home: EventPulseHome(account: backend.account, backend: backend),
        backend: backend,
      ),
    );
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Find events and synced event work.'), findsOneWidget);

    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Help & support'));
    await tester.pumpAndSettle();
    expect(
      find.text('Quick answers for using EventPulse on Android.'),
      findsOneWidget,
    );
  });

  testWidgets('invitations show pending, accepted and declined tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeBackend();
    backend.invitations.addAll([
      {
        'id': 'invite-pending',
        'eventId': 'event-alpha',
        'eventTitle': 'Alpha summit',
        'status': 'pending',
        'role': 'member',
        'inviterName': 'Minh Tran',
        'startsAt': DateTime.now()
            .add(const Duration(days: 4))
            .toUtc()
            .toIso8601String(),
        'venue': 'Hall A',
      },
      {
        'id': 'invite-accepted',
        'eventId': 'event-beta',
        'eventTitle': 'Beta workshop',
        'status': 'accepted',
        'role': 'admin',
        'inviterName': 'Minh Tran',
        'startsAt': DateTime.now()
            .add(const Duration(days: 8))
            .toUtc()
            .toIso8601String(),
        'venue': 'Hall B',
      },
    ]);
    await tester.pumpWidget(
      EventPulseApp(
        home: EventPulseHome(account: backend.account, backend: backend),
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Invitations').first);
    await tester.pumpAndSettle();
    expect(find.text('Pending (1)'), findsOneWidget);
    expect(find.text('Accepted (1)'), findsOneWidget);
    expect(find.text('Declined (0)'), findsOneWidget);
    expect(find.text('Alpha summit'), findsOneWidget);
    expect(find.text('Beta workshop'), findsNothing);

    await tester.tap(find.text('Accepted (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Beta workshop'), findsOneWidget);
    expect(find.text('Alpha summit'), findsNothing);
  });

  testWidgets('search finds teammates as well as work', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeBackend();
    backend.events.add({
      'id': 'search-event',
      'title': 'Summer meetup',
      'description': '',
      'category': 'Meetup',
      'venue': 'Riverside',
      'startsAt': DateTime.now().toUtc().toIso8601String(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    backend.members.add({
      'eventId': 'search-event',
      'userId': 'user-2',
      'name': 'Alice Nguyen',
      'email': 'alice@example.com',
      'role': 'member',
      'status': 'accepted',
    });
    await tester.pumpWidget(
      EventPulseApp(
        home: EventPulseHome(account: backend.account, backend: backend),
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'alice');
    await tester.pumpAndSettle();

    expect(find.text('People'), findsOneWidget);
    expect(find.text('Alice Nguyen'), findsOneWidget);
    expect(find.text('alice@example.com · Summer meetup'), findsOneWidget);
  });

  testWidgets('Ctrl K opens the search workspace', (tester) async {
    final backend = _FakeBackend();
    await tester.pumpWidget(
      EventPulseApp(
        home: EventPulseHome(account: backend.account, backend: backend),
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Find events and synced event work.'), findsOneWidget);
  });

  testWidgets('Android 14+ selects the expressive appearance', (tester) async {
    final backend = _FakeBackend();
    await tester.pumpWidget(
      EventPulseApp(
        uiFlavor: UiFlavor.expressive,
        home: EventPulseHome(account: backend.account, backend: backend),
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Expressive · Android 14 and newer'), findsOneWidget);
  });

  testWidgets('Android 13 keeps the classic appearance', (tester) async {
    final backend = _FakeBackend();
    await tester.pumpWidget(
      EventPulseApp(
        home: EventPulseHome(account: backend.account, backend: backend),
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Classic · Android 13 and below'), findsOneWidget);
  });
}
