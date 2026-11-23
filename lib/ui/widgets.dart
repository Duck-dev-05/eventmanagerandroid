import 'package:flutter/material.dart';

import '../models/event.dart';
import 'theme.dart';

/// Reusable building blocks shared by the app shell and feature pages.

/// One row in the account dropdown menu.
class AccountMenuEntry {
  const AccountMenuEntry(
    this.value,
    this.label,
    this.icon, {
    this.destructive = false,
  });

  final String value;
  final String label;
  final IconData icon;

  /// Destructive actions (sign out) render in the error color.
  final bool destructive;
}

/// A rounded, tinted icon container used by menus, rows and section headers.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
    this.background,
    this.radius,
  });

  final IconData icon;
  final Color color;
  final double size;
  final Color? background;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius ?? size * 0.3),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Small count pill used by navigation and notification affordances.
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    this.color = orange,
    this.foreground = Colors.white,
    this.minSize = 18,
  });

  final int count;
  final Color color;
  final Color foreground;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Avatar chip that opens a styled account dropdown, shared by the mobile
/// app bar, the desktop top bar and the side navigation.
///
/// The popup shows an account header (avatar, name, email) followed by icon
/// rows; pass [icon] to render a plain icon button instead of the avatar.
class AccountMenuButton extends StatelessWidget {
  const AccountMenuButton({
    super.key,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.entries,
    required this.onSelected,
    this.tooltip = 'Account options',
    this.showLabel = false,
    this.icon,
  });

  final String name;
  final String? email;
  final String? photoUrl;
  final List<AccountMenuEntry> entries;
  final ValueChanged<String> onSelected;
  final String tooltip;

  /// Shows the display name and a chevron next to the avatar (desktop bar).
  final bool showLabel;

  /// Renders a plain icon button instead of the avatar chip (side nav).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      onSelected: onSelected,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 18,
      shadowColor: const Color(0x1F16201B),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      constraints: const BoxConstraints(minWidth: 268, maxWidth: 310),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: line),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _AccountHeader(
            name: name,
            email: email,
            avatar: _avatar(radius: 21),
          ),
        ),
        const PopupMenuDivider(height: 1),
        for (var i = 0; i < entries.length; i++) ...[
          if (entries[i].destructive && (i == 0 || !entries[i - 1].destructive))
            const PopupMenuDivider(height: 1),
          PopupMenuItem<String>(
            value: entries[i].value,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTile(
                  icon: entries[i].icon,
                  size: 32,
                  color: entries[i].destructive ? error : mutedStrong,
                  background: entries[i].destructive ? errorTint : softFill,
                  radius: AppRadius.xs,
                ),
                const SizedBox(width: 11),
                Text(
                  entries[i].label,
                  style: TextStyle(
                    color: entries[i].destructive ? error : ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
      child: icon != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Icon(icon, size: 20, color: muted),
            )
          : Container(
              padding: EdgeInsets.fromLTRB(4, 4, showLabel ? 9 : 4, 4),
              decoration: BoxDecoration(
                color: showLabel ? softFill : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: showLabel ? Border.all(color: line) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _avatar(radius: showLabel ? 15 : 17),
                  if (showLabel) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: iconSoft,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _avatar({required double radius}) => CircleAvatar(
    radius: radius,
    backgroundColor: avatarTint,
    backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
    child: photoUrl != null
        ? null
        : Text(
            userInitials(name),
            style: TextStyle(
              color: orange,
              fontWeight: FontWeight.w800,
              fontSize: radius * 0.78,
            ),
          ),
  );
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.name,
    required this.email,
    required this.avatar,
  });

  final String name;
  final String? email;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                if (email != null && email!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 12,
                      color: success,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Signed in',
                      style: TextStyle(
                        color: success,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tonal rounded surface used by feature cards (Material 3 style).
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding,
    this.radius,
    this.color,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final Color? color;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final ui = EventPulseUiTokens.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? ui.cardColor,
        borderRadius: BorderRadius.circular(radius ?? ui.cardRadius),
        border: Border.all(color: ui.cardBorder),
        boxShadow: shadow ? ui.cardShadow : null,
      ),
      child: child,
    );
  }
}

/// Card with an optional icon/title header and consistent inner padding.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.iconColor = orange,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.contentPadding,
    this.radius,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Color iconColor;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? contentPadding;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || trailing != null;
    return Panel(
      radius: radius,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasHeader)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  padding.horizontal / 2 + 4,
                  14,
                  padding.horizontal / 2,
                  12,
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      IconTile(icon: icon!, color: iconColor, size: 36),
                      const SizedBox(width: 11),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null)
                            Text(
                              title!,
                              style: const TextStyle(
                                color: ink,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.1,
                              ),
                            ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
              ),
            if (hasHeader) const Divider(height: 1, color: line),
            Padding(padding: contentPadding ?? padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Compact header used inside cards and list sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor = orange,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          IconTile(icon: icon!, color: iconColor, size: 34),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ink,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Small uppercase section label, e.g. "OVERVIEW".
class Eyebrow extends StatelessWidget {
  const Eyebrow({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: orange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Dashboard metric card.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.tint,
    required this.accent,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color tint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ui = EventPulseUiTokens.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: ui.cardColor,
        borderRadius: BorderRadius.circular(ui.cardRadius),
        border: Border.all(color: ui.cardBorder),
        boxShadow: ui.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.15,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconTile(icon: icon, color: accent, size: 34, radius: 11),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 33,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: ink,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 11.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Responsive page heading with title, subtitle and an optional action.
class PageHeading extends StatelessWidget {
  const PageHeading(
    this.title,
    this.subtitle, {
    super.key,
    this.action,
    this.eyebrow,
  });

  final String title, subtitle;
  final Widget? action;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Eyebrow(label: eyebrow!),
                  const SizedBox(height: 10),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 27,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: ink,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 12),
            Padding(padding: const EdgeInsets.only(top: 2), child: action!),
          ],
        ],
      ),
    );
  }
}

/// Standard page body: consistent horizontal padding, a comfortable max width
/// on tablets/desktop and a single scroll view for the whole page.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.children,
    this.maxWidth = kPageMaxWidth,
    this.padding,
    this.bottomPadding = AppSpace.section,
    this.scrollable = true,
    this.physics,
  });

  final List<Widget> children;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final double bottomPadding;
  final bool scrollable;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final ui = EventPulseUiTokens.of(context);
    final horizontal = width >= kMediumBreakpoint
        ? ui.pageGutterWide
        : ui.pageGutter;
    final body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding:
              padding ??
              EdgeInsets.fromLTRB(horizontal, 18, horizontal, bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
    if (!scrollable) return body;
    return SingleChildScrollView(
      physics: physics,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: body,
    );
  }
}

/// Pill-style segmented control used for page tabs and list filters.
class AppSegmentedTabs extends StatelessWidget {
  const AppSegmentedTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: softFill,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: line),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          for (var i = 0; i < labels.length; i++)
            Material(
              color: i == selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              elevation: i == selected ? 1 : 0,
              shadowColor: const Color(0x1A16201B),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: () => onSelected(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == selected ? ink : muted,
                      fontSize: 12.5,
                      fontWeight: i == selected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tappable row for an event inside a [Panel] list.
class EventRow extends StatelessWidget {
  const EventRow({
    super.key,
    required this.event,
    required this.onTap,
    this.badge = 'Owner',
  });

  final EventItem event;
  final VoidCallback onTap;

  /// Role chip next to the title, e.g. "Owner" or "Shared".
  final String badge;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(event.date).format(context);
    return Semantics(
      button: true,
      label: '${event.title}, ${shortDate(event.date)} at $time',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        splashColor: const Color(0x12D96C2D),
        hoverColor: const Color(0x08D96C2D),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF4EC), Color(0xFFFFE9D8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: orangeBorder),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      monthShort(event.date.month),
                      style: const TextStyle(
                        color: orange,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${event.date.day}',
                      style: const TextStyle(
                        color: ink,
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: badge == 'Shared' ? blueLight : orangeLight,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: badge == 'Shared'
                                  ? const Color(0xFFD5E0FA)
                                  : orangeBorder,
                            ),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: badge == 'Shared' ? blue : orange,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: softFill,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            event.category,
                            style: const TextStyle(
                              color: mutedStrong,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SmallIconText(
                          icon: Icons.access_time_rounded,
                          text: time,
                          maxWidth: 80,
                        ),
                        SmallIconText(
                          icon: Icons.location_on_outlined,
                          text: event.location,
                          maxWidth: 170,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: softFill,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: chevron,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline "icon + text" hint used inside [EventRow].
class SmallIconText extends StatelessWidget {
  const SmallIconText({
    super.key,
    required this.icon,
    required this.text,
    this.maxWidth = 100,
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
          Icon(icon, color: iconSoft, size: 13),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly empty-state card with icon, title, subtitle and optional action.
class EmptyCard extends StatelessWidget {
  const EmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: Panel(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
          child: Column(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF4EC), Color(0xFFFFE6D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: orangeBorder),
                ),
                child: Icon(icon, color: orange, size: 30),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: muted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact empty message used inside list pages.
class EmptyMessage extends StatelessWidget {
  const EmptyMessage(
    this.title,
    this.message, {
    super.key,
    this.icon = Icons.inbox_outlined,
  });

  final String title, message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: softFill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line),
            ),
            child: Icon(icon, color: iconSoft, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: ink,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}

/// Inline success/error banner used by forms and async actions across the app.
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final tint = isError ? errorTint : successTint;
    final accent = isError ? error : success;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? error : const Color(0xFF0B7A52),
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Search input with a leading icon and a one-tap clear button.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    this.onChanged,
    this.hintText = 'Search',
    this.autofocus = false,
    this.onClear,
    this.textInputAction,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final bool autofocus;
  final VoidCallback? onClear;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: autofocus,
        textInputAction: textInputAction ?? TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                    onClear?.call();
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
        ),
      ),
    );
  }
}

/// One option rendered by [AppDropdownField].
class AppSelectOption<T> {
  const AppSelectOption(this.value, this.label, {this.icon, this.description});

  final T value;
  final String label;
  final IconData? icon;
  final String? description;
}

/// Branded replacement for [DropdownButtonFormField] with consistent spacing,
/// a checkmark on the selected option and compact menu rows.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.prefixIcon,
    this.hint,
    this.helperText,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T?>? onChanged;
  final IconData? prefixIcon;
  final String? hint;
  final String? helperText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: ValueKey<T?>(value),
      initialValue: value,
      isExpanded: true,
      itemHeight: 52,
      menuMaxHeight: 320,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: 10,
      dropdownColor: Colors.white,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 20,
        color: iconSoft,
      ),
      style: const TextStyle(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 20, color: iconSoft),
      ),
      hint: hint == null
          ? null
          : Text(hint!, style: const TextStyle(color: chevron, fontSize: 13.5)),
      items: [
        for (final option in options)
          DropdownMenuItem<T>(
            value: option.value,
            child: Row(
              children: [
                if (option.icon != null) ...[
                  Icon(option.icon, size: 18, color: iconSoft),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (option.description != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          option.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (option.value == value)
                  const Icon(Icons.check_rounded, size: 17, color: orange),
              ],
            ),
          ),
      ],
      selectedItemBuilder: (context) => [
        for (final option in options)
          Row(
            children: [
              if (option.icon != null) ...[
                Icon(option.icon, size: 18, color: iconSoft),
                const SizedBox(width: 9),
              ],
              Flexible(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}

/// Consistent icon + label row for [PopupMenuButton] menus.
PopupMenuItem<String> appMenuItem({
  required String value,
  required String label,
  IconData? icon,
  bool destructive = false,
  bool selected = false,
  bool enabled = true,
}) {
  return PopupMenuItem<String>(
    value: value,
    height: 46,
    enabled: enabled,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 18,
            color: destructive
                ? error
                : selected
                ? orange
                : iconSoft,
          ),
          const SizedBox(width: 10),
        ],
        Text(
          label,
          style: TextStyle(
            color: destructive ? error : ink,
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 8),
          const Icon(Icons.check_rounded, size: 16, color: orange),
        ],
      ],
    ),
  );
}
