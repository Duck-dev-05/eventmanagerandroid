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

  @override
  Future<void> signOut({bool revokeDevice = true}) async {}
}

void main() {
  testWidgets('bottom navigation opens calendar and profile sections', (
    tester,
  ) async {
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

    // Calendar destination must open the calendar section, not invitations.
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    expect(find.text('Nothing on the calendar'), findsOneWidget);

    // Profile destination must open the profile section.
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Your account identity and workspace access.'),
      findsOneWidget,
    );
  });
}
