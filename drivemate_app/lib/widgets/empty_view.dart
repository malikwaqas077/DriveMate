import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum EmptyViewType {
  students,
  lessons,
  payments,
  calendar,
  reports,
  generic,
}

class EmptyView extends StatefulWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.type = EmptyViewType.generic,
    this.actionLabel,
    this.onAction,
    this.subtitle,
  });

  final String message;
  final EmptyViewType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? subtitle;

  @override
  State<EmptyView> createState() => _EmptyViewState();
}

class _EmptyViewState extends State<EmptyView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getIcon() {
    switch (widget.type) {
      case EmptyViewType.students:
        return Icons.people_outline_rounded;
      case EmptyViewType.lessons:
        return Icons.event_note_outlined;
      case EmptyViewType.payments:
        return Icons.account_balance_wallet_outlined;
      case EmptyViewType.calendar:
        return Icons.calendar_today_outlined;
      case EmptyViewType.reports:
        return Icons.analytics_outlined;
      case EmptyViewType.generic:
        return Icons.inbox_outlined;
    }
  }

  Color _getIconBackgroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (widget.type) {
      case EmptyViewType.students:
        return AppTheme.infoLight;
      case EmptyViewType.lessons:
        return AppTheme.warningLight;
      case EmptyViewType.payments:
        return AppTheme.successLight;
      case EmptyViewType.calendar:
        return const Color(0xFF4F46E5).withOpacity(0.15);
      case EmptyViewType.reports:
        return const Color(0xFFEC4899).withOpacity(0.15);
      case EmptyViewType.generic:
        return colorScheme.surfaceContainerHighest;
    }
  }

  Color _getIconColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (widget.type) {
      case EmptyViewType.students:
        return AppTheme.info;
      case EmptyViewType.lessons:
        return AppTheme.warning;
      case EmptyViewType.payments:
        return AppTheme.success;
      case EmptyViewType.calendar:
        return const Color(0xFF4F46E5);
      case EmptyViewType.reports:
        return const Color(0xFFEC4899);
      case EmptyViewType.generic:
        return colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Illustration container
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: _getIconBackgroundColor(context),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background decorative circles
                      Positioned(
                        top: 10,
                        right: 15,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _getIconColor(context).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 10,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _getIconColor(context).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // Main icon
                      Icon(
                        _getIcon(),
                        size: 48,
                        color: _getIconColor(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Title
                Text(
                  widget.message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (widget.actionLabel != null && widget.onAction != null) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: widget.onAction,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(widget.actionLabel!),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A simpler, inline empty state for use in smaller contexts
class InlineEmptyView extends StatelessWidget {
  const InlineEmptyView({
    super.key,
    required this.message,
    this.icon,
  });

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? Icons.inbox_outlined,
            size: 40,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
