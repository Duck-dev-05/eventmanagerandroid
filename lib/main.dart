import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mobile_backend.dart';
import 'mobile_pages.dart';
import 'notifications.dart';
import 'models/event.dart';
import 'ui/flavor.dart';
import 'ui/theme.dart';
import 'ui/widgets.dart';

export 'models/event.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Match the Android system bars to the active visual generation so the app
  // reads as a native Android application instead of a bare white web view.
  final flavor = detectUiFlavor();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: flavor == UiFlavor.expressive
          ? const Color(0xFFFBF8F4)
          : Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const EventPulseApp());
}

class EventPulseApp extends StatelessWidget {
  const EventPulseApp({super.key, this.home, this.backend, this.uiFlavor});

  final Widget? home;
  final MobileBackendService? backend;

  /// Overrides Android version detection, mainly for tests and previews.
  final UiFlavor? uiFlavor;

  @override
  Widget build(BuildContext context) {
    final flavor = uiFlavor ?? detectUiFlavor();
    return MaterialApp(
      title: 'EventPulse',
      debugShowCheckedModeBanner: false,
      theme: buildEventPulseTheme(flavor: flavor),
      home:
          home ?? _GoogleSignInGate(backend: backend ?? MobileBackend.instance),
    );
  }
}

/// Branded launch screen shown while the saved sign-in is restored from
/// secure storage. Previously signed-in users go straight through it to the
/// workspace; the login page only appears when no session is stored.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [orangeDeep, orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.event_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'EventPulse',
              style: TextStyle(
                color: ink,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Opening your workspace…',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 26),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleSignInGate extends StatefulWidget {
  const _GoogleSignInGate({required this.backend});

  final MobileBackendService backend;

  @override
  State<_GoogleSignInGate> createState() => _GoogleSignInGateState();
}

class _GoogleSignInGateState extends State<_GoogleSignInGate> {
  MobileAccount? _account;
  bool _initializing = true;
  bool _signingIn = false;
  bool _registering = false;
  bool _showPassword = false;
  String? _error;
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      // The backend restores from encrypted storage instantly, so users who
      // signed in before go straight to the workspace without the login page.
      _account = await widget.backend.restoreSession();
    } on Object {
      _error =
          'Could not restore your EventPulse session. Please sign in again.';
    }
    if (mounted) setState(() => _initializing = false);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitPasswordSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      final account = _registering
          ? await widget.backend.registerAccount(
              _nameController.text.trim(),
              _identifierController.text.trim(),
              _passwordController.text,
            )
          : await widget.backend.signInWithPassword(
              _identifierController.text.trim(),
              _passwordController.text,
            );
      if (mounted) setState(() => _account = account);
    } on Object catch (error) {
      if (mounted) setState(() => _error = appErrorText(error));
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _requestPasswordReset() async {
    final email = _identifierController.text.trim();
    if (email.isEmpty ||
        !RegExp(r'^[^\@\s]+@[^\@\s]+\.[^\@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter your account email first.');
      return;
    }
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      await widget.backend.requestPasswordReset(email);
      if (mounted) {
        setState(
          () => _error =
              'If an account exists for that email, a reset link is on its way.',
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = appErrorText(error));
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      final account = await widget.backend.signInWithGoogle();
      if (mounted) {
        setState(() {
          _account = account;
          _error = null;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = appErrorText(error));
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signOut() async {
    await widget.backend.signOut();
    if (mounted) setState(() => _account = null);
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    if (account != null) {
      return EventPulseHome(
        account: account,
        onSignOut: _signOut,
        backend: widget.backend,
      );
    }
    // While the saved session is being restored, show the splash instead of
    // the login page so returning users never see "Welcome back" again.
    if (_initializing) return const _SplashScreen();
    final form = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [orangeDeep, orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.event_rounded, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 18),
        Text(
          _registering ? 'Create your account' : 'Welcome back',
          style: const TextStyle(
            color: ink,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _registering
              ? 'Create an EventPulse account to get started.'
              : 'Sign in to manage the events you run and follow.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, height: 1.5),
        ),
        const SizedBox(height: 23),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _initializing || _signingIn ? null : _signIn,
              icon: _signingIn || _initializing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.g_mobiledata, size: 24),
              label: Text(
                _initializing
                    ? 'Preparing Google sign-in…'
                    : _signingIn
                    ? 'Signing in…'
                    : 'Continue with Google',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ink,
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: line, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: Divider(color: line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const Expanded(child: Divider(color: line)),
          ],
        ),
        const SizedBox(height: 18),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_registering) ...[
                TextFormField(
                  controller: _nameController,
                  enabled: !_initializing && !_signingIn,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) =>
                      _registering && (value?.trim().length ?? 0) < 2
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _identifierController,
                enabled: !_initializing && !_signingIn,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                ),
                validator: (value) {
                  final identifier = value?.trim() ?? '';
                  if (identifier.isEmpty) {
                    return 'Enter your email';
                  }
                  if (!RegExp(
                    r'^[^\@\s]+@[^\@\s]+\.[^\@\s]+$',
                  ).hasMatch(identifier)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                enabled: !_initializing && !_signingIn,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submitPasswordSignIn(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Your password',
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your password'
                    : (_registering && value.length < 8
                          ? 'Password must be at least 8 characters'
                          : null),
              ),
              const SizedBox(height: 8),
              if (!_registering)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _initializing || _signingIn
                        ? null
                        : _requestPasswordReset,
                    child: const Text('Forgot password?'),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _initializing || _signingIn
                      ? null
                      : _submitPasswordSignIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: Text(_registering ? 'Create account' : 'Sign in'),
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _initializing || _signingIn
              ? null
              : () => setState(() {
                  _registering = !_registering;
                  _error = null;
                }),
          child: Text(
            _registering
                ? 'Already have an account? Sign in'
                : 'New to EventPulse? Create an account',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          StatusBanner(message: _error!, isError: true),
        ],
      ],
    );
    final card = Panel(
      radius: 26,
      child: Padding(padding: const EdgeInsets.all(26), child: form),
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= kWideBreakpoint;
            return Stack(
              children: [
                const _AuthBackdrop(),
                Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(wide ? 40 : 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: wide ? 1040 : 440),
                      child: wide
                          ? Row(
                              children: [
                                const Expanded(child: _AuthBrandPanel()),
                                const SizedBox(width: 34),
                                SizedBox(width: 420, child: card),
                              ],
                            )
                          : card,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [background, Color.lerp(background, Colors.white, 0.45)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -130,
                right: -90,
                child: _Glow(size: 340, color: orange.withValues(alpha: 0.07)),
              ),
              Positioned(
                bottom: -150,
                left: -100,
                child: _Glow(size: 380, color: blue.withValues(alpha: 0.05)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel();

  static const _features = <(IconData, Color, String, String)>[
    (
      Icons.grid_view_rounded,
      orange,
      'Everything in one place',
      'Dashboard, calendar, tasks and files stay together.',
    ),
    (
      Icons.groups_outlined,
      success,
      'Built for teams',
      'Invite members, assign work and manage access.',
    ),
    (
      Icons.sync_rounded,
      blue,
      'Always in sync',
      'Changes reach your web workspace automatically.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const _BrandMark(size: 50),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'EventPulse',
                    style: TextStyle(
                      color: ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'EVENT WORKSPACE',
                    style: TextStyle(
                      color: muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            'Run every event from one calm workspace.',
            style: TextStyle(
              color: ink,
              fontSize: 33,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Plan, invite your team, and keep tasks, files and schedules in sync across Android and the web.',
            style: TextStyle(color: muted, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 28),
          for (final feature in _features)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  IconTile(
                    icon: feature.$1,
                    color: feature.$2,
                    size: 40,
                    radius: 12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.$3,
                          style: const TextStyle(
                            color: ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          feature.$4,
                          style: const TextStyle(
                            color: muted,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: line),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 12, color: iconSoft),
                SizedBox(width: 6),
                Text(
                  'SECURE WORKSPACE · ANDROID + WEB',
                  style: TextStyle(
                    color: muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EventPulseHome extends StatefulWidget {
  const EventPulseHome({super.key, this.account, this.onSignOut, this.backend});

  final MobileAccount? account;
  final MobileBackendService? backend;
  final VoidCallback? onSignOut;

  @override
  State<EventPulseHome> createState() => _EventPulseHomeState();
}

class _EventPulseHomeState extends State<EventPulseHome>
    with WidgetsBindingObserver {
  int _section = 0;

  /// Sections the user visited, so the Android system back button walks back
  /// through pages instead of leaving the app.
  final List<int> _sectionBackstack = [];
  MobileAccount? _account;
  EventItem? _selectedEvent;
  int _eventTab = 0;
  final List<Map<String, dynamic>> _selectedMembers = [];
  final List<Map<String, dynamic>> _selectedAvailableUsers = [];
  final List<Map<String, dynamic>> _selectedActivity = [];
  final List<EventItem> _events = [];
  final List<EventItem> _sharedEvents = [];
  final List<Map<String, dynamic>> _invitations = [];
  final List<Map<String, dynamic>> _members = [];
  final List<Map<String, dynamic>> _notifications = [];
  final Map<String, dynamic> _preferences = {};
  final Map<String, List<Map<String, dynamic>>> _work = {
    'tasks': [],
    'agenda': [],
    'files': [],
    'invitations': [],
  };
  Timer? _syncTimer;
  bool _syncing = false;
  bool _loadingEvents = true;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    WidgetsBinding.instance.addObserver(this);
    unawaited(EventPulseNotifications.requestPermission());
    _refreshEvents();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshEvents(showErrors: false),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      (widget.backend ?? MobileBackend.instance).startBackgroundSync();
      _refreshEvents(showErrors: false);
      // The open event page shows members and activity that are not part of
      // the regular sync batch, so reload them when the app resumes.
      final selected = _selectedEvent;
      if (_section == 12 && selected != null) {
        _loadSelectedEvent(selected);
      }
    }
  }

  Future<void> _refreshEvents({bool showErrors = true}) async {
    if (_syncing) return;
    _syncing = true;
    try {
      final batch = await (widget.backend ?? MobileBackend.instance).pull();
      if (!mounted) return;
      setState(() {
        if (batch.snapshot) _events.clear();
        for (final change in batch.changes) {
          final id = change['entityId']?.toString() ?? '';
          final existing = _events.indexWhere((event) => event.id == id);
          if (change['action'] == 'delete') {
            if (existing >= 0) _events.removeAt(existing);
          } else if (change['event'] is Map) {
            final event = EventItem.fromBackend(
              Map<String, dynamic>.from(change['event'] as Map),
            );
            if (existing >= 0) {
              _events[existing] = event;
            } else {
              _events.add(event);
            }
          }
        }
        if (batch.snapshot) {
          _events.addAll(batch.events.map(EventItem.fromBackend));
        }
        _sharedEvents
          ..clear()
          ..addAll(batch.sharedEvents.map(EventItem.fromBackend));
        _invitations
          ..clear()
          ..addAll(batch.invitations);
        _members
          ..clear()
          ..addAll(batch.members);
        _notifications
          ..clear()
          ..addAll(batch.notifications);
        _preferences
          ..clear()
          ..addAll(batch.preferences);
        final profile = batch.profile;
        if (_account != null && profile['name'] is String) {
          _account = MobileAccount(
            id: _account!.id,
            name: profile['name'] as String,
            email: _account!.email,
            avatarUrl: profile['avatarUrl'] as String? ?? _account!.avatarUrl,
            googleAvatarUrl:
                profile['googleAvatarUrl'] as String? ??
                _account!.googleAvatarUrl,
            workspaceRole:
                profile['workspaceRole'] as String? ?? _account!.workspaceRole,
          );
        }
        _events.sort((a, b) => a.date.compareTo(b.date));
        _sharedEvents.sort((a, b) => a.date.compareTo(b.date));
        _syncError = null;
        _loadingEvents = false;
      });
      unawaited(EventPulseNotifications.notifyNew(batch.notifications));
      await _refreshWork();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingEvents = false;
        if (showErrors) _syncError = appErrorText(error);
      });
    } finally {
      _syncing = false;
    }
  }

  Future<void> _useTemplate(Map<String, dynamic> template) async {
    final date = DateUtils.dateOnly(DateTime.now());
    try {
      final saved = await (widget.backend ?? MobileBackend.instance)
          .createEvent(
            title: template['name']?.toString() ?? 'New event',
            description: template['description']?.toString() ?? '',
            category: template['category']?.toString() ?? 'Conference',
            venue: template['defaultVenue']?.toString() ?? '',
            startsAt: date,
            visibility: template['visibility']?.toString() ?? 'private',
            capacity:
                (template['defaultCapacity'] as num?)?.toInt() ??
                (_preferences['defaultCapacity'] as num?)?.toInt(),
          );
      final event = EventItem.fromBackend(saved);
      final now = DateTime.now().toUtc().toIso8601String();
      for (final raw in template['taskPresets'] as List? ?? const []) {
        if (raw is Map) {
          await (widget.backend ?? MobileBackend.instance)
              .saveWorkItem('task', {
                'id': _newId(),
                'eventId': event.id,
                'title': raw['title'] ?? 'Task',
                'notes': raw['notes'] ?? '',
                'status': 'open',
                'createdAt': now,
                'updatedAt': now,
              });
        }
      }
      var offset = 0;
      for (final raw in template['agendaPresets'] as List? ?? const []) {
        if (raw is Map) {
          await (widget.backend ?? MobileBackend.instance)
              .saveWorkItem('agenda', {
                'id': _newId(),
                'eventId': event.id,
                'title': raw['title'] ?? 'Session',
                'description': raw['description'] ?? '',
                'startsAt': date
                    .add(Duration(minutes: offset))
                    .toUtc()
                    .toIso8601String(),
                'durationMinutes': raw['durationMinutes'] ?? 30,
                'location': event.location,
                'speakerName': '',
                'status': 'scheduled',
                'createdAt': now,
                'updatedAt': now,
              });
          offset += (raw['durationMinutes'] as num?)?.toInt() ?? 30;
        }
      }
      if (!mounted) return;
      final ownedEvent = EventItem(
        id: event.id,
        title: event.title,
        date: event.date,
        location: event.location,
        description: event.description,
        category: event.category,
        visibility: event.visibility,
        capacity: event.capacity,
        ownerId: _account?.id,
        createdAt: event.createdAt,
      );
      setState(() {
        _events.add(ownedEvent);
        _sectionBackstack.add(_section);
        _section = 12;
        _selectedEvent = ownedEvent;
      });
      await _refreshWork();
      _loadSelectedEvent(ownedEvent);
    } on Object catch (error) {
      if (mounted) setState(() => _syncError = appErrorText(error));
    }
  }

  static String _newId() =>
      'android-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(100000)}';

  Future<void> _refreshWork() async {
    try {
      final result = await (widget.backend ?? MobileBackend.instance)
          .pullWork();
      if (!mounted) return;
      setState(() {
        for (final key in ['tasks', 'agenda', 'files']) {
          _work[key] = _asMapList(result[key]);
        }
      });
    } on Object {
      // Work sync is retried with the next regular event pull.
    }
  }

  static List<Map<String, dynamic>> _asMapList(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList()
      : <Map<String, dynamic>>[];

  static const _sectionTitles = [
    'Dashboard',
    'My Events',
    'Invitations',
    'Calendar',
    'Users',
    'My Activity',
    'Search',
    'Notifications',
    'Templates',
    'Help & support',
    'Profile',
    'Settings',
    'Event',
  ];
  Future<void> _createEvent() async {
    final event = await showDialog<EventItem>(
      context: context,
      builder: (_) => const _CreateEventDialog(),
    );
    if (event != null && mounted) {
      try {
        final saved = await (widget.backend ?? MobileBackend.instance)
            .createEvent(
              title: event.title,
              description: event.description,
              category: event.category,
              venue: event.location,
              startsAt: event.date,
              capacity:
                  event.capacity ??
                  (_preferences['defaultCapacity'] as num?)?.toInt(),
            );
        if (!mounted) return;
        setState(() {
          _events.add(
            EventItem.fromBackend({...saved, 'ownerId': _account?.id}),
          );
          _events.sort((a, b) => a.date.compareTo(b.date));
          _syncError = null;
        });
      } on Object catch (error) {
        if (mounted) setState(() => _syncError = appErrorText(error));
      }
    }
  }

  void _openEvent(EventItem event) {
    setState(() {
      _sectionBackstack.add(_section);
      _selectedEvent = event;
      _eventTab = 0;
      _section = 12;
    });
    _loadSelectedEvent(event);
  }

  Future<void> _loadSelectedEvent(EventItem event) async {
    final backend = widget.backend ?? MobileBackend.instance;
    try {
      final role = _eventRole(event);
      final activityFuture = backend.eventActivity(event.id!);
      final membersFuture = role == 'owner' || role == 'admin'
          ? backend.eventMembers(event.id!)
          : Future<Map<String, dynamic>>.value({});
      final activity = await activityFuture;
      final members = await membersFuture;
      if (!mounted || _selectedEvent?.id != event.id) return;
      setState(() {
        _selectedMembers
          ..clear()
          ..addAll(_members.where((member) => member['eventId'] == event.id));
        if (members.isNotEmpty) {
          _selectedMembers
            ..clear()
            ..addAll(_asMapList(members['members']));
          _selectedAvailableUsers
            ..clear()
            ..addAll(_asMapList(members['users']));
          _work['invitations'] = _asMapList(members['invitations']);
        }
        _selectedActivity
          ..clear()
          ..addAll(activity);
      });
    } on Object catch (error) {
      if (mounted) setState(() => _syncError = appErrorText(error));
    }
  }

  String? _eventRole(EventItem event) {
    if (event.ownerId == _account?.id) return 'owner';
    for (final member in _members) {
      if (member['eventId'] == event.id &&
          member['userId'] == _account?.id &&
          member['status'] == 'accepted') {
        return member['role']?.toString();
      }
    }
    return null;
  }

  Future<void> _saveEvent(Map<String, dynamic> values) async {
    try {
      final result = await (widget.backend ?? MobileBackend.instance)
          .updateEvent(values);
      if (!mounted) return;
      setState(() {
        final updated = EventItem.fromBackend(result);
        final index = _events.indexWhere((event) => event.id == updated.id);
        final original = index >= 0 ? _events[index] : _selectedEvent;
        if (index >= 0) {
          _events[index] = EventItem(
            id: updated.id,
            title: updated.title,
            date: updated.date,
            location: updated.location,
            description: updated.description,
            category: updated.category,
            visibility: updated.visibility,
            capacity: updated.capacity,
            ownerId: original?.ownerId,
            ownerName: original?.ownerName,
            ownerAvatarUrl: original?.ownerAvatarUrl,
            createdAt: updated.createdAt,
          );
        }
        _selectedEvent = EventItem(
          id: updated.id,
          title: updated.title,
          date: updated.date,
          location: updated.location,
          description: updated.description,
          category: updated.category,
          visibility: updated.visibility,
          capacity: updated.capacity,
          ownerId: original?.ownerId,
          ownerName: original?.ownerName,
          ownerAvatarUrl: original?.ownerAvatarUrl,
          createdAt: updated.createdAt,
        );
        _syncError = null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _syncError = appErrorText(error));
    }
  }

  Future<void> _deleteSelectedEvent() async {
    final event = _selectedEvent;
    if (event?.id == null) return;
    try {
      await (widget.backend ?? MobileBackend.instance).deleteEvent(event!.id!);
      if (!mounted) return;
      setState(() {
        _events.removeWhere((item) => item.id == event.id);
        _selectedEvent = null;
        _sectionBackstack.clear();
        _section = 1;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _syncError = appErrorText(error));
    }
  }

  void _openProfile() => _navigate(10);
  void _openSettings() => _navigate(11);

  /// Opens a section, remembering the current one for the Android back button.
  void _navigate(int index) {
    if (_section == index) return;
    setState(() {
      _sectionBackstack.add(_section);
      _section = index;
    });
  }

  /// Leaves the open event page, returning to wherever the user came from.
  void _closeEvent() {
    setState(() {
      _selectedEvent = null;
      _eventTab = 0;
      _selectedMembers.clear();
      _selectedAvailableUsers.clear();
      _selectedActivity.clear();
      _section = _sectionBackstack.isEmpty ? 1 : _sectionBackstack.removeLast();
    });
  }

  /// Android back: walk the visited sections, exit only from a root page.
  void _goBack() {
    if (_sectionBackstack.isNotEmpty) {
      setState(() => _section = _sectionBackstack.removeLast());
    } else {
      SystemNavigator.pop();
    }
  }

  /// Material app bar for phones, with a back arrow while inside a page.
  PreferredSizeWidget _buildAppBar() {
    final canGoBack = _sectionBackstack.isNotEmpty;
    final title = _section == 12
        ? (_selectedEvent?.title ?? 'EventPulse')
        : _section < _sectionTitles.length
        ? _sectionTitles[_section]
        : 'EventPulse';
    final unread = _notifications.where((n) => n['readAt'] == null).length;
    return AppBar(
      titleSpacing: canGoBack ? 0 : 16,
      leadingWidth: canGoBack ? 52 : 54,
      leading: canGoBack
          ? IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _goBack,
            )
          : const Padding(
              padding: EdgeInsets.only(left: 14),
              child: _BrandMark(size: 34),
            ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Search',
          onPressed: () => _navigate(6),
          icon: const Icon(Icons.search_rounded),
        ),
        _NotificationAction(unread: unread, onPressed: () => _navigate(7)),
        _accountMenu(),
        const SizedBox(width: 6),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: line),
      ),
    );
  }

  Widget _accountMenu() {
    return AccountMenuButton(
      name: _account?.displayName ?? 'EventPulse',
      email: _account?.email,
      photoUrl: _account?.photoUrl,
      onSelected: _onAccountMenuSelected,
      entries: const [
        AccountMenuEntry('profile', 'My profile', Icons.person_outline_rounded),
        AccountMenuEntry('settings', 'Settings', Icons.settings_outlined),
        AccountMenuEntry(
          'templates',
          'Templates',
          Icons.dashboard_customize_outlined,
        ),
        AccountMenuEntry('help', 'Help & support', Icons.help_outline_rounded),
        AccountMenuEntry('activity', 'My Activity', Icons.history_rounded),
        AccountMenuEntry(
          'signout',
          'Sign out',
          Icons.logout_rounded,
          destructive: true,
        ),
      ],
    );
  }

  void _onAccountMenuSelected(String value) {
    if (value == 'signout') widget.onSignOut?.call();
    if (value == 'profile') _openProfile();
    if (value == 'settings') _openSettings();
    if (value == 'templates') _navigate(8);
    if (value == 'help') _navigate(9);
    if (value == 'activity') _navigate(5);
  }

  /// Maps a bottom destination index to its workspace section.
  void _selectDestination(int destination) => _navigate(switch (destination) {
    0 => 0,
    1 => 1,
    2 => 3,
    _ => 10,
  });

  /// Maps any workspace section to the bottom tab that should read selected.
  int _bottomDestinationIndex(int section) => switch (section) {
    0 => 0,
    1 || 2 || 8 || 12 => 1,
    3 => 2,
    10 || 11 => 3,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kWideBreakpoint;
        final unread = _notifications.where((n) => n['readAt'] == null).length;
        final pendingInvites = _invitations
            .where((invitation) => invitation['status'] == 'pending')
            .length;
        final isAdmin =
            _account?.workspaceRole == 'admin' ||
            _account?.workspaceRole == 'owner';
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
                _navigate(6),
          },
          child: Focus(
            autofocus: true,
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                _goBack();
              },
              child: Scaffold(
                appBar: wide ? null : _buildAppBar(),
                body: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      if (wide)
                        _SideNavigation(
                          selected: _section,
                          onSelect: _navigate,
                          onCreate: _createEvent,
                          account: _account,
                          onSignOut: widget.onSignOut,
                          onProfile: _openProfile,
                          onSettings: _openSettings,
                          onOpenEvent: _openEvent,
                          nextEvent: _events
                              .where(
                                (event) => event.date.isAfter(DateTime.now()),
                              )
                              .firstOrNull,
                          pendingInvites: pendingInvites,
                          unreadNotifications: unread,
                          isAdmin: isAdmin,
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            if (wide)
                              _TopBar(
                                section: _section,
                                title: _section < _sectionTitles.length
                                    ? _sectionTitles[_section]
                                    : 'Event',
                                onCreate: _createEvent,
                                account: _account,
                                onSignOut: widget.onSignOut,
                                onNavigate: _navigate,
                                onProfile: _openProfile,
                                onSettings: _openSettings,
                                unreadNotifications: unread,
                              ),
                            if (_loadingEvents)
                              const LinearProgressIndicator(minHeight: 2),
                            if (_syncError != null)
                              MaterialBanner(
                                leading: const Icon(
                                  Icons.cloud_off_rounded,
                                  color: warning,
                                  size: 20,
                                ),
                                content: Text(_syncError!),
                                actions: [
                                  TextButton(
                                    onPressed: () => _refreshEvents(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.015),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    ),
                                child: KeyedSubtree(
                                  key: ValueKey(
                                    'section-$_section-${_selectedEvent?.id ?? ''}',
                                  ),
                                  child: _buildSection(wide: wide),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                floatingActionButton:
                    !wide && const [0, 1, 3].contains(_section)
                    ? FloatingActionButton(
                        tooltip: 'Create event',
                        onPressed: _createEvent,
                        child: const Icon(Icons.add_rounded, size: 26),
                      )
                    : null,
                bottomNavigationBar: wide ? null : _buildBottomNavigation(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    final ui = EventPulseUiTokens.of(context);
    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view_rounded),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.event_note_outlined),
        selectedIcon: Icon(Icons.event_note_rounded),
        label: 'Events',
      ),
      NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month_rounded),
        label: 'Calendar',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ];
    final bar = NavigationBar(
      selectedIndex: _bottomDestinationIndex(_section),
      onDestinationSelected: _selectDestination,
      destinations: destinations,
    );
    if (!ui.floatingNavigation) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: ui.cardColor,
          border: Border(top: BorderSide(color: ui.cardBorder)),
        ),
        child: SafeArea(top: false, child: bar),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: line),
          boxShadow: kLiftedShadow,
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(22), child: bar),
      ),
    );
  }

  Widget _buildSection({required bool wide}) {
    final allEvents = [..._events, ..._sharedEvents];
    switch (_section) {
      case 0:
        return _Dashboard(
          events: allEvents,
          account: _account,
          loading: _loadingEvents,
          sharedEventsCount: _sharedEvents.length,
          memberCount: _members
              .map((member) => member['userId']?.toString())
              .where((userId) => userId != null && userId != _account?.id)
              .toSet()
              .length,
          wide: wide,
          onOpenEvent: _openEvent,
          onNavigate: _navigate,
        );
      case 1:
        return _EventListPage(
          title: 'My events',
          subtitle: 'Everything you own or collaborate on.',
          events: allEvents,
          onCreate: _createEvent,
          onOpenEvent: _openEvent,
          accountId: _account?.id,
        );
      case 2:
        return _InvitationPage(
          invitations: _invitations,
          events: allEvents,
          backend: widget.backend ?? MobileBackend.instance,
          onOpenEvent: _openEvent,
          onChanged: _refreshEvents,
        );
      case 3:
        return _CalendarPage(
          events: allEvents,
          onOpenEvent: _openEvent,
          accountId: _account?.id,
        );
      case 4:
        return MobilePeoplePage(
          account: _account ?? const MobileAccount(id: '', name: '', email: ''),
          backend: widget.backend ?? MobileBackend.instance,
        );
      case 5:
        return MobileActivityPage(
          events: allEvents,
          backend: widget.backend ?? MobileBackend.instance,
          onOpenEvent: _openEvent,
        );
      case 6:
        return MobileSearchPage(
          events: allEvents,
          members: _members,
          work: _work,
          onOpen: _openEvent,
        );
      case 7:
        return MobileNotificationsPage(
          notifications: _notifications,
          backend: widget.backend ?? MobileBackend.instance,
          events: allEvents,
          onOpenEvent: _openEvent,
          onChanged: _refreshEvents,
        );
      case 8:
        return MobileTemplatesPage(
          backend: widget.backend ?? MobileBackend.instance,
          onUse: _useTemplate,
        );
      case 9:
        return const MobileHelpPage();
      case 10:
        return _account == null
            ? const SizedBox.shrink()
            : MobileProfilePage(
                account: _account!,
                backend: widget.backend ?? MobileBackend.instance,
                onAccountChanged: (account) =>
                    setState(() => _account = account),
              );
      case 11:
        return MobileSettingsPage(
          preferences: _preferences,
          backend: widget.backend ?? MobileBackend.instance,
          isOwner: _account?.workspaceRole == 'owner',
          onRestored: () {
            _refreshEvents();
          },
        );
      case 12:
        final event = _selectedEvent;
        if (event == null || _account == null) return const SizedBox.shrink();
        return MobileEventPage(
          event: event,
          tab: _eventTab,
          role: _eventRole(event) ?? 'viewer',
          account: _account!,
          backend: widget.backend ?? MobileBackend.instance,
          work: _work,
          members: _selectedMembers,
          availableUsers: _selectedAvailableUsers,
          activity: _selectedActivity,
          onLeave: () {
            _refreshEvents();
          },
          onTab: (tab) {
            if (tab < 0) {
              _closeEvent();
            } else {
              setState(() => _eventTab = tab);
            }
          },
          onSave: _saveEvent,
          onDelete: _deleteSelectedEvent,
          onReload: () {
            _refreshWork();
            _loadSelectedEvent(event);
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Brand tile used by the app bar, side navigation and splash surfaces.
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [orangeDeep, orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33D96C2D),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(Icons.event_rounded, color: Colors.white, size: size * 0.5),
    );
  }
}

/// Notification bell with a count badge, shared by the top bars.
class _NotificationAction extends StatelessWidget {
  const _NotificationAction({required this.unread, required this.onPressed});

  final int unread;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: onPressed,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        if (unread > 0)
          Positioned(right: 5, top: 5, child: CountBadge(count: unread)),
      ],
    );
  }
}

/// Section glyph shown in the app top bar.
class _PageGlyph extends StatelessWidget {
  const _PageGlyph({required this.section});

  final int section;

  @override
  Widget build(BuildContext context) {
    final icon = switch (section) {
      0 => Icons.grid_view_rounded,
      1 => Icons.event_note_rounded,
      2 => Icons.mail_outline_rounded,
      3 => Icons.calendar_month_rounded,
      4 => Icons.people_outline_rounded,
      5 => Icons.history_rounded,
      6 => Icons.search_rounded,
      7 => Icons.notifications_none_rounded,
      8 => Icons.dashboard_customize_outlined,
      9 => Icons.help_outline_rounded,
      10 => Icons.person_outline_rounded,
      11 => Icons.settings_outlined,
      _ => Icons.event_rounded,
    };
    return IconTile(icon: icon, color: orange, size: 36, radius: 11);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.section,
    required this.title,
    required this.onCreate,
    required this.account,
    required this.onSignOut,
    required this.onNavigate,
    required this.onProfile,
    required this.onSettings,
    required this.unreadNotifications,
  });

  final int section;
  final String title;
  final VoidCallback onCreate;
  final MobileAccount? account;
  final VoidCallback? onSignOut;
  final ValueChanged<int> onNavigate;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    final ui = EventPulseUiTokens.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 14, 24, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ui.cardColor,
        borderRadius: BorderRadius.circular(ui.cardRadius),
        border: Border.all(color: ui.cardBorder),
        boxShadow: ui.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showSearch = constraints.maxWidth >= 900;
          final showAccountLabel = constraints.maxWidth >= 720;
          final showCreateLabel = constraints.maxWidth >= 580;
          return Row(
            children: [
              _PageGlyph(section: section),
              const SizedBox(width: 11),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 230),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'EVENTPULSE WORKSPACE',
                      style: TextStyle(
                        color: muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.25,
                      ),
                    ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (showSearch) ...[
                _SearchLauncher(onTap: () => onNavigate(6)),
                const SizedBox(width: 10),
              ],
              if (showCreateLabel)
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('New event'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                )
              else
                IconButton.filled(
                  tooltip: 'New event',
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded, size: 20),
                ),
              const SizedBox(width: 2),
              _NotificationAction(
                unread: unreadNotifications,
                onPressed: () => onNavigate(7),
              ),
              AccountMenuButton(
                name: account?.displayName ?? 'My account',
                email: account?.email,
                photoUrl: account?.photoUrl,
                showLabel: showAccountLabel,
                onSelected: (value) {
                  if (value == 'signout') onSignOut?.call();
                  if (value == 'profile') onProfile();
                  if (value == 'settings') onSettings();
                  if (value == 'templates') onNavigate(8);
                  if (value == 'help') onNavigate(9);
                  if (value == 'activity') onNavigate(5);
                },
                entries: const [
                  AccountMenuEntry(
                    'profile',
                    'My profile',
                    Icons.person_outline_rounded,
                  ),
                  AccountMenuEntry(
                    'settings',
                    'Settings',
                    Icons.settings_outlined,
                  ),
                  AccountMenuEntry(
                    'templates',
                    'Templates',
                    Icons.dashboard_customize_outlined,
                  ),
                  AccountMenuEntry(
                    'help',
                    'Help & support',
                    Icons.help_outline_rounded,
                  ),
                  AccountMenuEntry(
                    'activity',
                    'My Activity',
                    Icons.history_rounded,
                  ),
                  AccountMenuEntry(
                    'signout',
                    'Sign out',
                    Icons.logout_rounded,
                    destructive: true,
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          );
        },
      ),
    );
  }
}

/// Looks like a search input but routes to the search workspace page.
class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 268,
      height: 40,
      child: Material(
        color: softFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: iconSoft, size: 17),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Search everything...',
                    style: TextStyle(color: muted, fontSize: 12.5),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: line),
                  ),
                  child: const Text(
                    'Ctrl K',
                    style: TextStyle(
                      color: chevron,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
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

class _NavGroupLabel extends StatelessWidget {
  const _NavGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 5),
      child: Text(
        label,
        style: const TextStyle(
          color: muted,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.35,
        ),
      ),
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.selected,
    required this.onSelect,
    required this.onCreate,
    required this.account,
    required this.onSignOut,
    required this.onProfile,
    required this.onSettings,
    required this.onOpenEvent,
    required this.nextEvent,
    required this.pendingInvites,
    required this.unreadNotifications,
    required this.isAdmin,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  final MobileAccount? account;
  final VoidCallback? onSignOut;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final ValueChanged<EventItem> onOpenEvent;
  final EventItem? nextEvent;
  final int pendingInvites;
  final int unreadNotifications;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final ui = EventPulseUiTokens.of(context);
    return Container(
      width: 264,
      margin: const EdgeInsets.fromLTRB(14, 14, 0, 14),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: ui.cardColor,
        borderRadius: BorderRadius.circular(ui.cardRadius),
        border: Border.all(color: ui.cardBorder),
        boxShadow: ui.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _BrandMark(size: 42),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EventPulse',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'EVENT WORKSPACE',
                      style: TextStyle(
                        color: muted,
                        letterSpacing: 1.35,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Create event'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _NavGroupLabel('WORKSPACE'),
                  _SideNavItem(
                    label: 'Dashboard',
                    icon: Icons.grid_view_rounded,
                    selected: selected == 0,
                    onTap: () => onSelect(0),
                  ),
                  _SideNavItem(
                    label: 'My Events',
                    icon: Icons.event_note_outlined,
                    selected: selected == 1 || selected == 12,
                    onTap: () => onSelect(1),
                  ),
                  _SideNavItem(
                    label: 'Calendar',
                    icon: Icons.calendar_month_outlined,
                    selected: selected == 3,
                    onTap: () => onSelect(3),
                  ),
                  _SideNavItem(
                    label: 'Invitations',
                    icon: Icons.mail_outline_rounded,
                    selected: selected == 2,
                    badge: pendingInvites,
                    onTap: () => onSelect(2),
                  ),
                  const _NavGroupLabel('TEAM'),
                  if (isAdmin)
                    _SideNavItem(
                      label: 'People',
                      icon: Icons.people_outline_rounded,
                      selected: selected == 4,
                      onTap: () => onSelect(4),
                    ),
                  _SideNavItem(
                    label: 'My Activity',
                    icon: Icons.history_rounded,
                    selected: selected == 5,
                    onTap: () => onSelect(5),
                  ),
                  _SideNavItem(
                    label: 'Notifications',
                    icon: Icons.notifications_none_rounded,
                    selected: selected == 7,
                    badge: unreadNotifications,
                    onTap: () => onSelect(7),
                  ),
                  const _NavGroupLabel('MORE'),
                  _SideNavItem(
                    label: 'Templates',
                    icon: Icons.dashboard_customize_outlined,
                    selected: selected == 8,
                    onTap: () => onSelect(8),
                  ),
                  _SideNavItem(
                    label: 'Help & support',
                    icon: Icons.help_outline_rounded,
                    selected: selected == 9,
                    onTap: () => onSelect(9),
                  ),
                  const _NavGroupLabel('ACCOUNT'),
                  _SideNavItem(
                    label: 'Profile',
                    icon: Icons.person_outline_rounded,
                    selected: selected == 10,
                    onTap: onProfile,
                  ),
                  _SideNavItem(
                    label: 'Settings',
                    icon: Icons.settings_outlined,
                    selected: selected == 11,
                    onTap: onSettings,
                  ),
                ],
              ),
            ),
          ),
          if (nextEvent != null && selected == 0) ...[
            const SizedBox(height: 8),
            _NextUpCard(
              event: nextEvent!,
              onTap: () => onOpenEvent(nextEvent!),
            ),
            const SizedBox(height: 10),
          ],
          const Divider(height: 1, color: line),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
              onTap: onProfile,
              leading: CircleAvatar(
                radius: 17,
                backgroundColor: avatarTint,
                backgroundImage: account?.photoUrl == null
                    ? null
                    : NetworkImage(account!.photoUrl!),
                child: account?.photoUrl != null
                    ? null
                    : Text(
                        userInitials(account?.displayName ?? 'EventPulse'),
                        style: const TextStyle(
                          color: orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              title: Text(
                account?.displayName ?? 'My account',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              subtitle: Text(
                account?.email ?? 'Google account',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: muted),
              ),
              trailing: AccountMenuButton(
                name: account?.displayName ?? 'My account',
                email: account?.email,
                photoUrl: account?.photoUrl,
                icon: Icons.more_horiz_rounded,
                onSelected: (value) {
                  if (value == 'profile') onProfile();
                  if (value == 'settings') onSettings();
                  if (value == 'signout') onSignOut?.call();
                },
                entries: const [
                  AccountMenuEntry(
                    'profile',
                    'My profile',
                    Icons.person_outline_rounded,
                  ),
                  AccountMenuEntry(
                    'settings',
                    'Settings',
                    Icons.settings_outlined,
                  ),
                  AccountMenuEntry(
                    'signout',
                    'Sign out',
                    Icons.logout_rounded,
                    destructive: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextUpCard extends StatelessWidget {
  const _NextUpCard({required this.event, required this.onTap});

  final EventItem event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: orangeLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: orangeBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: orange,
                    size: 12,
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'NEXT UP',
                    style: TextStyle(
                      color: muted,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      fontSize: 9.5,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: orange,
                    size: 15,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                event.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                shortDate(event.date),
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? orangeLight : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: selected ? orangeBorder : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 19, color: selected ? orange : muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? ink : mutedStrong,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (badge > 0) CountBadge(count: badge, minSize: 17),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.events,
    required this.account,
    required this.loading,
    required this.sharedEventsCount,
    required this.memberCount,
    required this.wide,
    required this.onOpenEvent,
    required this.onNavigate,
  });

  final List<EventItem> events;
  final MobileAccount? account;
  final bool loading;
  final int sharedEventsCount;
  final int memberCount;
  final bool wide;
  final ValueChanged<EventItem> onOpenEvent;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final upcoming = events
        .where(
          (event) => event.date.isAfter(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
        )
        .toList();
    final width = MediaQuery.sizeOf(context).width;
    final isAdmin =
        account?.workspaceRole == 'admin' || account?.workspaceRole == 'owner';
    return AppPage(
      bottomPadding: 96,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow(label: 'OVERVIEW'),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome back, ${account?.name.split(' ').first ?? 'there'}',
                    style: TextStyle(
                      fontSize: width < 380 ? 27 : 32,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.1,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    loading
                        ? 'Syncing with your EventPulse workspace…'
                        : 'Here\u2019s how your events are doing today.',
                    style: const TextStyle(
                      color: muted,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = 12.0;
            final columns = constraints.maxWidth >= 980
                ? 4
                : constraints.maxWidth >= 360
                ? 2
                : 1;
            final cardWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: StatCard(
                    label: 'UPCOMING EVENTS',
                    value: '${upcoming.length}',
                    caption: upcoming.isEmpty
                        ? 'Nothing scheduled yet'
                        : 'Next on ${shortDate(upcoming.first.date)}',
                    icon: Icons.calendar_today_outlined,
                    tint: orangeLight,
                    accent: orange,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: StatCard(
                    label: 'TOTAL EVENTS',
                    value: '${events.length}',
                    caption:
                        '${events.length - upcoming.length} past · ${upcoming.length} upcoming',
                    icon: Icons.confirmation_number_outlined,
                    tint: mintLight,
                    accent: success,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: StatCard(
                    label: 'SHARED WITH YOU',
                    value: '$sharedEventsCount',
                    caption: sharedEventsCount == 0
                        ? 'No shared events yet'
                        : 'Events shared with you',
                    icon: Icons.share_outlined,
                    tint: roseLight,
                    accent: rose,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: StatCard(
                    label: 'TEAM MEMBERS',
                    value: '$memberCount',
                    caption: memberCount == 0
                        ? 'No team members yet'
                        : 'Across your event workspace',
                    icon: Icons.people_outline_rounded,
                    tint: amberLight,
                    accent: warning,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _UpcomingCard(
                  events: upcoming,
                  onOpenEvent: onOpenEvent,
                  onViewAll: () => onNavigate(1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _QuickAccessCard(
                  onNavigate: onNavigate,
                  isAdmin: isAdmin,
                ),
              ),
            ],
          )
        else ...[
          _UpcomingCard(
            events: upcoming,
            onOpenEvent: onOpenEvent,
            onViewAll: () => onNavigate(1),
          ),
          const SizedBox(height: 14),
          _QuickAccessCard(onNavigate: onNavigate, isAdmin: isAdmin),
        ],
      ],
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.events,
    required this.onOpenEvent,
    required this.onViewAll,
  });

  final List<EventItem> events;
  final ValueChanged<EventItem> onOpenEvent;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Upcoming events',
      subtitle: 'Your next events, all in one place.',
      icon: Icons.event_available_outlined,
      trailing: TextButton(
        onPressed: onViewAll,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('View all'),
            SizedBox(width: 3),
            Icon(Icons.arrow_forward_rounded, size: 15),
          ],
        ),
      ),
      contentPadding: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: events.isEmpty
          ? const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 22),
              child: Text(
                'No upcoming events. Create one to get started.',
                style: TextStyle(color: muted, fontSize: 13, height: 1.45),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < events.take(3).length; i++) ...[
                  EventRow(
                    event: events[i],
                    onTap: () => onOpenEvent(events[i]),
                  ),
                  if (i < events.take(3).length - 1)
                    const Divider(height: 1, indent: 15, endIndent: 15),
                ],
              ],
            ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({required this.onNavigate, required this.isAdmin});
  final ValueChanged<int> onNavigate;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Quick access',
      subtitle: 'Jump back into your workspace.',
      icon: Icons.bolt_rounded,
      iconColor: warning,
      padding: const EdgeInsets.all(16),
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Column(
        children: [
          _QuickLink(
            icon: Icons.event_note_outlined,
            iconColor: orange,
            title: 'View my events',
            subtitle: 'Everything you manage',
            onTap: () => onNavigate(1),
          ),
          if (isAdmin)
            _QuickLink(
              icon: Icons.people_outline_rounded,
              iconColor: success,
              title: 'Manage users',
              subtitle: 'Team & member directory',
              onTap: () => onNavigate(4),
            ),
          _QuickLink(
            icon: Icons.calendar_month_outlined,
            iconColor: blue,
            title: 'Check calendar',
            subtitle: 'Plan the month ahead',
            onTap: () => onNavigate(3),
          ),
          _QuickLink(
            icon: Icons.mail_outline_rounded,
            iconColor: rose,
            title: 'Invitations',
            subtitle: 'Shared events and invites',
            onTap: () => onNavigate(2),
          ),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        hoverColor: softFill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            children: [
              IconTile(icon: icon, color: iconColor, size: 38, radius: 11),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: chevron, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventListPage extends StatefulWidget {
  const _EventListPage({
    required this.title,
    required this.subtitle,
    required this.events,
    required this.onCreate,
    required this.onOpenEvent,
    this.accountId,
  });

  final String title;
  final String subtitle;
  final List<EventItem> events;
  final VoidCallback onCreate;
  final ValueChanged<EventItem> onOpenEvent;

  /// Signed-in user id, used to label rows "Owner" or "Shared" correctly.
  final String? accountId;

  @override
  State<_EventListPage> createState() => _EventListPageState();
}

class _EventListPageState extends State<_EventListPage> {
  final _search = TextEditingController();
  int _filter = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _badgeFor(EventItem event) =>
      widget.accountId != null && event.ownerId != widget.accountId
      ? 'Shared'
      : 'Owner';

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final now = DateTime.now();
    final filtered = widget.events.where((event) {
      final matchesSearch =
          query.isEmpty ||
          '${event.title} ${event.location} ${event.category} ${event.description}'
              .toLowerCase()
              .contains(query);
      final matchesFilter = switch (_filter) {
        1 => event.date.isAfter(now),
        2 => !event.date.isAfter(now),
        _ => true,
      };
      return matchesSearch && matchesFilter;
    }).toList();
    final showCreate = MediaQuery.sizeOf(context).width >= kMediumBreakpoint;

    return AppPage(
      bottomPadding: 92,
      children: [
        PageHeading(
          widget.title,
          widget.subtitle,
          eyebrow: 'YOUR WORKSPACE',
          action: showCreate
              ? FilledButton.icon(
                  onPressed: widget.onCreate,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New event'),
                )
              : null,
        ),
        const SizedBox(height: 16),
        AppSearchField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          hintText: 'Search events by name, place or category',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppSegmentedTabs(
                  labels: const ['All', 'Upcoming', 'Past'],
                  selected: _filter,
                  onSelected: (value) => setState(() => _filter = value),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${filtered.length} event${filtered.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (widget.events.isEmpty)
          EmptyCard(
            icon: Icons.event_busy_outlined,
            title: 'No events yet',
            subtitle: 'Create an event and it will appear here.',
            action: FilledButton.icon(
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create event'),
            ),
          )
        else if (filtered.isEmpty)
          const EmptyMessage(
            'No matching events',
            'Try a different search term or switch the filter.',
            icon: Icons.search_off_rounded,
          )
        else
          Panel(
            child: Column(
              children: [
                for (var i = 0; i < filtered.length; i++) ...[
                  EventRow(
                    event: filtered[i],
                    badge: _badgeFor(filtered[i]),
                    onTap: () => widget.onOpenEvent(filtered[i]),
                  ),
                  if (i < filtered.length - 1)
                    const Divider(height: 1, indent: 15, endIndent: 15),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CalendarPage extends StatefulWidget {
  const _CalendarPage({
    required this.events,
    required this.onOpenEvent,
    this.accountId,
  });
  final List<EventItem> events;
  final ValueChanged<EventItem> onOpenEvent;

  /// Signed-in user id, used to label event rows "Owner" or "Shared".
  final String? accountId;

  @override
  State<_CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<_CalendarPage> {
  DateTime _month = DateTime.now();
  DateTime? _selectedDay;

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selectedDay = null;
    });
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _selectedDay = DateUtils.dateOnly(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final startOffset = (firstDay.weekday + 6) % 7;
    final cellCount = ((startOffset + daysInMonth + 6) ~/ 7) * 7;
    final eventsThisMonth = widget.events
        .where(
          (event) =>
              event.date.year == _month.year &&
              event.date.month == _month.month,
        )
        .toList();
    final selectedEvents = _selectedDay == null
        ? const <EventItem>[]
        : widget.events
              .where((event) => DateUtils.isSameDay(event.date, _selectedDay))
              .toList();
    final today = DateTime.now();

    return AppPage(
      bottomPadding: 92,
      children: [
        PageHeading(
          'Calendar',
          'See what\u2019s coming up.',
          eyebrow: 'PLAN AHEAD',
          action: OutlinedButton.icon(
            onPressed: _goToday,
            icon: const Icon(Icons.today_rounded, size: 17),
            label: const Text('Today'),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '${monthName(_month.month)} ${_month.year}',
          subtitle:
              '${eventsThisMonth.length} event${eventsThisMonth.length == 1 ? '' : 's'} this month',
          icon: Icons.calendar_month_rounded,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous month',
                visualDensity: VisualDensity.compact,
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Next month',
                visualDensity: VisualDensity.compact,
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          contentPadding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
          child: Column(
            children: [
              Row(
                children: [
                  for (final day in const [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ])
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            day,
                            style: const TextStyle(
                              color: muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cellCount,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 46,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemBuilder: (context, index) {
                  final day = index - startOffset + 1;
                  if (day < 1 || day > daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  final date = DateTime(_month.year, _month.month, day);
                  final hasEvent = eventsThisMonth.any(
                    (event) => event.date.day == day,
                  );
                  final isToday = DateUtils.isSameDay(today, date);
                  final isSelected =
                      _selectedDay != null &&
                      DateUtils.isSameDay(_selectedDay, date);
                  return Material(
                    color: isSelected
                        ? ink
                        : hasEvent
                        ? orangeLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () => setState(() => _selectedDay = date),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: isToday && !isSelected
                              ? Border.all(color: orange, width: 1.4)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : hasEvent
                                    ? orange
                                    : ink,
                                fontWeight: hasEvent || isToday || isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            if (hasEvent)
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.only(top: 3),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : orange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedDay != null)
          SectionCard(
            title: shortDate(_selectedDay!),
            subtitle: 'Events on this day',
            icon: Icons.event_available_outlined,
            trailing: TextButton(
              onPressed: () => setState(() => _selectedDay = null),
              child: const Text('Clear'),
            ),
            contentPadding: EdgeInsets.zero,
            padding: const EdgeInsets.all(16),
            child: selectedEvents.isEmpty
                ? const EmptyMessage(
                    'No events on this day',
                    'Pick another day, or create an event for this date.',
                    icon: Icons.event_outlined,
                  )
                : Column(
                    children: [
                      for (var i = 0; i < selectedEvents.length; i++) ...[
                        EventRow(
                          event: selectedEvents[i],
                          badge:
                              widget.accountId != null &&
                                  selectedEvents[i].ownerId != widget.accountId
                              ? 'Shared'
                              : 'Owner',
                          onTap: () => widget.onOpenEvent(selectedEvents[i]),
                        ),
                        if (i < selectedEvents.length - 1)
                          const Divider(height: 1, indent: 15, endIndent: 15),
                      ],
                    ],
                  ),
          )
        else if (eventsThisMonth.isEmpty)
          const EmptyCard(
            icon: Icons.event_available_outlined,
            title: 'Nothing on the calendar',
            subtitle: 'Events scheduled this month will appear here.',
          )
        else ...[
          Row(
            children: [
              const Text(
                'This month',
                style: TextStyle(
                  color: ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                shortDate(_month),
                style: const TextStyle(color: muted, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Panel(
            child: Column(
              children: [
                for (var i = 0; i < eventsThisMonth.length; i++) ...[
                  EventRow(
                    event: eventsThisMonth[i],
                    badge:
                        widget.accountId != null &&
                            eventsThisMonth[i].ownerId != widget.accountId
                        ? 'Shared'
                        : 'Owner',
                    onTap: () => widget.onOpenEvent(eventsThisMonth[i]),
                  ),
                  if (i < eventsThisMonth.length - 1)
                    const Divider(height: 1, indent: 15, endIndent: 15),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InvitationPage extends StatefulWidget {
  const _InvitationPage({
    required this.invitations,
    required this.events,
    required this.backend,
    required this.onOpenEvent,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> invitations;
  final List<EventItem> events;
  final MobileBackendService backend;
  final ValueChanged<EventItem> onOpenEvent;
  final VoidCallback onChanged;

  @override
  State<_InvitationPage> createState() => _InvitationPageState();
}

class _InvitationPageState extends State<_InvitationPage> {
  static const _statuses = ['pending', 'accepted', 'declined'];

  int _filter = 0;
  bool _sending = false;
  String? _notice;
  bool _noticeIsError = false;

  void _setNotice(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _notice = message;
      _noticeIsError = isError;
    });
  }

  Future<void> _respond(
    Map<String, dynamic> invitation,
    String response,
  ) async {
    try {
      await widget.backend.respondToInvitation(
        invitation['id']?.toString() ?? '',
        response,
      );
      widget.onChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response == 'accept'
                  ? 'Invitation accepted.'
                  : 'Invitation declined.',
            ),
          ),
        );
      }
    } catch (error) {
      _setNotice(appErrorText(error), isError: true);
    }
  }

  Future<void> _invitePeople() async {
    final email = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite people'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Invite someone to join EventPulse. They can be added to an event later.',
                style: TextStyle(color: muted, fontSize: 12.5, height: 1.45),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: email,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email address'),
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
            onPressed: () => Navigator.pop(context, email.text.trim()),
            child: const Text('Send invitation'),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    setState(() => _sending = true);
    try {
      final result = await widget.backend.sendWorkspaceInvitation(value);
      final message = result['message']?.toString() ?? 'Invitation sent.';
      final inviteUrl = result['inviteUrl']?.toString();
      _setNotice(message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
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
    } catch (error) {
      _setNotice(appErrorText(error), isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _roleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: blueLight,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: blue.withValues(alpha: 0.22)),
      ),
      child: Text(
        role[0].toUpperCase() + role.substring(1),
        style: const TextStyle(
          color: blue,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _invitationCard(Map<String, dynamic> invitation) {
    final status = invitation['status']?.toString() ?? 'pending';
    final eventId = invitation['eventId']?.toString();
    final event = widget.events.where((item) => item.id == eventId).firstOrNull;
    final role = invitation['role']?.toString() ?? 'member';
    final tone = switch (status) {
      'accepted' => success,
      'declined' => muted,
      _ => orange,
    };
    final tint = switch (status) {
      'accepted' => successTint,
      'declined' => softFill,
      _ => orangeLight,
    };
    final startsAt = DateTime.tryParse(
      invitation['startsAt']?.toString() ?? '',
    )?.toLocal();
    final venue = invitation['venue']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: line),
          boxShadow: kSoftShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconTile(
                    icon: Icons.mail_outline_rounded,
                    color: orange,
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: tint,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                                border: Border.all(
                                  color: tone.withValues(alpha: 0.22),
                                ),
                              ),
                              child: Text(
                                status[0].toUpperCase() + status.substring(1),
                                style: TextStyle(
                                  color: tone,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _roleBadge(role),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          invitation['eventTitle']?.toString() ??
                              'Event invitation',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${invitation['inviterName'] ?? 'EventPulse user'} invited you to collaborate.',
                          style: const TextStyle(
                            color: muted,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                        if (startsAt != null || venue.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            [
                              if (startsAt != null) shortDate(startsAt),
                              if (venue.isNotEmpty) venue,
                            ].join(' · '),
                            style: const TextStyle(
                              color: mutedStrong,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (status == 'pending')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _respond(invitation, 'decline'),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _respond(invitation, 'accept'),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                )
              else if (event != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onOpenEvent(event),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open event'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final status in _statuses)
        status: widget.invitations
            .where(
              (invitation) => (invitation['status'] ?? 'pending') == status,
            )
            .length,
    };
    final status = _statuses[_filter];
    final items = widget.invitations
        .where((invitation) => (invitation['status'] ?? 'pending') == status)
        .toList();

    return AppPage(
      bottomPadding: 96,
      children: [
        PageHeading(
          'Invitations',
          'Review, respond to, and send invitations.',
          eyebrow: 'INBOX',
          action: OutlinedButton.icon(
            onPressed: _sending ? null : _invitePeople,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
            label: Text(_sending ? 'Sending…' : 'Invite people'),
          ),
        ),
        const SizedBox(height: 14),
        if (_notice != null) ...[
          StatusBanner(message: _notice!, isError: _noticeIsError),
          const SizedBox(height: 14),
        ],
        AppSegmentedTabs(
          labels: [
            'Pending (${counts['pending']})',
            'Accepted (${counts['accepted']})',
            'Declined (${counts['declined']})',
          ],
          selected: _filter,
          onSelected: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          EmptyCard(
            icon: Icons.mark_email_read_outlined,
            title: switch (status) {
              'accepted' => 'Nothing accepted yet',
              'declined' => 'No declined invitations',
              _ => 'You’re all caught up',
            },
            subtitle: switch (status) {
              'accepted' =>
                'Invitations you accept appear here and in My Events.',
              'declined' =>
                'Invitations you decline are kept here for reference.',
              _ => 'Event invitations will show up here when you receive them.',
            },
          )
        else
          for (final invitation in items) _invitationCard(invitation),
      ],
    );
  }
}

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog();

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  static const _categories = [
    'Conference',
    'Workshop',
    'Meetup',
    'Webinar',
    'Party',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _capacityController = TextEditingController();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  String _category = 'Conference';
  String _visibility = 'private';

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _time);
    if (time != null) setState(() => _time = time);
  }

  DateTime get _startsAt =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
      contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 6),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 18, 16),
      title: Row(
        children: [
          const IconTile(
            icon: Icons.event_available_rounded,
            color: orange,
            size: 42,
            radius: 13,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create an event',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: ink,
                    fontSize: 19,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add the basics. You can refine everything later.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FormLabel('EVENT DETAILS'),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Event name',
                    hintText: 'e.g. Team celebration',
                    prefixIcon: Icon(Icons.title_rounded, size: 19),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter an event name'
                      : null,
                ),
                const SizedBox(height: 12),
                AppDropdownField<String>(
                  label: 'Category',
                  value: _category,
                  prefixIcon: Icons.category_outlined,
                  options: [
                    for (final category in _categories)
                      AppSelectOption(category, category),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 16),
                const _FormLabel('DATE & PLACE'),
                Row(
                  children: [
                    Expanded(
                      child: _PickerField(
                        label: 'Date',
                        value: shortDate(_date),
                        icon: Icons.calendar_today_outlined,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PickerField(
                        label: 'Start time',
                        value: _time.format(context),
                        icon: Icons.schedule_rounded,
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    hintText: 'Venue or online link',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 19),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'What is this event about?',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                const _FormLabel('ACCESS'),
                AppDropdownField<String>(
                  label: 'Visibility',
                  value: _visibility,
                  prefixIcon: Icons.visibility_outlined,
                  options: const [
                    AppSelectOption(
                      'private',
                      'Private',
                      icon: Icons.lock_outline_rounded,
                      description: 'Only invited members can see the details',
                    ),
                    AppSelectOption(
                      'public',
                      'Public',
                      icon: Icons.public_rounded,
                      description: 'Workspace members can view read-only',
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _visibility = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Capacity (optional)',
                    hintText: 'Unlimited',
                    prefixIcon: Icon(Icons.groups_outlined, size: 19),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final capacity = _capacityController.text.trim();
            Navigator.pop(
              context,
              EventItem(
                title: _titleController.text.trim(),
                date: _startsAt,
                location: _locationController.text.trim().isEmpty
                    ? 'Location to be announced'
                    : _locationController.text.trim(),
                description: _descriptionController.text.trim(),
                category: _category,
                visibility: _visibility,
                capacity: capacity.isEmpty ? null : int.tryParse(capacity),
              ),
            );
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Create event'),
        ),
      ],
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Text(
        label,
        style: const TextStyle(
          color: muted,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fieldFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 17, color: iconSoft),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
