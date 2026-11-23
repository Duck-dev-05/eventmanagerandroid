import 'package:eventmanagerandroid/main.dart';
import 'package:eventmanagerandroid/mobile_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackend extends MobileBackendService {
  final account = const MobileAccount(
    id: 'user-1',
    name: 'Minh Tran',
    email: 'minh@example.com',
  );

  @override
  Future<MobileAccount?> restoreSession() async => account;

  @override
  Future<MobileSyncBatch> pull() async => const MobileSyncBatch(
    snapshot: true,
    events: [],
    changes: [],
    sharedEvents: [],
    invitations: [],
    members: [],
    notifications: [],
    preferences: {},
    profile: {},
  );

  @override
  Future<void> signOut({bool revokeDevice = true}) async {}

  @override
  Future<MobileAccount> signInWithGoogle() async => account;

  @override
  Future<void> respondToInvitation(
    String invitationId,
    String response,
  ) async {}

  @override
  Future<Map<String, dynamic>> createEvent({
    required String title,
    required String description,
    required String category,
    required String venue,
    required DateTime startsAt,
    int? capacity,
    String visibility = 'private',
  }) async => {};
}

void main() {
  testWidgets('debug nav tap', (tester) async {
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
    await tester.pumpAndSettle();

    final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
    // ignore: avoid_print
    print('selectedIndex before: ${nav.selectedIndex}');

    final matches = find.text('Calendar').evaluate().toList();
    // ignore: avoid_print
    print('calendar text matches: ${matches.length}');
    for (final m in find.text('Calendar').evaluate()) {
      final box = m.renderObject as RenderBox?;
      // ignore: avoid_print
      print(
        'Calendar text at ${box?.localToGlobal(Offset.zero)} size ${box?.size} widget ${m.widget}',
      );
    }

    final navBarRect = tester.getRect(find.byType(NavigationBar));
    // ignore: avoid_print
    print('navbar rect: $navBarRect');
    // ignore: avoid_print
    print(
      'icon center: ${tester.getCenter(find.byIcon(Icons.calendar_month_outlined).last)}',
    );

    await tester.tap(find.byIcon(Icons.calendar_month_outlined).last);
    await tester.pumpAndSettle();

    final navAfterIcon = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    // ignore: avoid_print
    print('selectedIndex after icon tap: ${navAfterIcon.selectedIndex}');
    // ignore: avoid_print
    print(
      'empty card count: ${find.text('Nothing on the calendar').evaluate().length}',
    );
    // ignore: avoid_print
    print(
      'events page subtitle count: ${find.text('Everything you own or collaborate on.').evaluate().length}',
    );
    // ignore: avoid_print
    print('dashboard title count: ${find.text('Dashboard').evaluate().length}');
    // ignore: avoid_print
    print('topbar title count: ${find.text('Calendar').evaluate().length}');

    final navAfter = tester.widget<NavigationBar>(find.byType(NavigationBar));
    // ignore: avoid_print
    print('selectedIndex after: ${navAfter.selectedIndex}');
    // ignore: avoid_print
    print(
      'empty card count: ${find.text('Nothing on the calendar').evaluate().length}',
    );
    // ignore: avoid_print
    print(
      'dashboard heading count: ${find.text('Dashboard').evaluate().length}',
    );
  });
}
