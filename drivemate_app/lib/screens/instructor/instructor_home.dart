import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/cancellation_request.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/firestore_service.dart';
import '../../services/role_preference_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../chat/conversations_list_screen.dart';
import '../owner/owner_access_requests_screen.dart';
import '../owner/owner_instructor_choice_screen.dart';
import '../owner/owner_instructors_screen.dart';
import '../owner/owner_reports_screen.dart';
import '../owner/announcements_screen.dart';
import 'calendar_screen.dart';
import 'cancellation_requests_screen.dart';
import 'instructor_expenses_screen.dart';
import 'recurring_lesson_screen.dart';
import 'settings/settings_main_screen.dart';
import 'money_screen.dart';
import 'insights_screen.dart';
import 'students_screen.dart';
import 'terms_screen.dart';

class InstructorHome extends StatefulWidget {
  const InstructorHome({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<InstructorHome> createState() => _InstructorHomeState();
}

class _InstructorHomeState extends State<InstructorHome> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final ChatService _chatService = ChatService();
  int _currentIndex = 0;
  int _pendingCancellations = 0;
  bool _isOwner = false;
  StreamSubscription<List<CancellationRequest>>? _cancellationSubscription;

  late final List<Widget> _screens;
  late final List<_NavItem> _navItems;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      CalendarScreen(instructor: widget.profile),
      StudentsScreen(instructor: widget.profile),
      MoneyScreen(instructor: widget.profile),
      InsightsScreen(instructor: widget.profile),
    ];
    _navItems = const [
      _NavItem(
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month,
        label: 'Calendar',
      ),
      _NavItem(
        icon: Icons.people_outline_rounded,
        activeIcon: Icons.people_rounded,
        label: 'Students',
      ),
      _NavItem(
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
        label: 'Money',
      ),
      _NavItem(
        icon: Icons.insights_rounded,
        activeIcon: Icons.insights_rounded,
        label: 'Insights',
      ),
    ];
    _listenToPendingCancellations();
    _checkIfOwner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancellationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Pause/resume stream subscription based on app lifecycle
    if (state == AppLifecycleState.paused) {
      _cancellationSubscription?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _cancellationSubscription?.resume();
    }
  }

  Future<void> _checkIfOwner() async {
    final schoolId = widget.profile.schoolId;
    if (schoolId != null && schoolId.isNotEmpty) {
      // Check if instructor owns the school OR if owner is also instructor
      final ownsSchool = await _firestoreService.doesInstructorOwnSchool(
        instructorId: widget.profile.id,
        schoolId: schoolId,
      );
      final isOwnerAlsoInstructor = widget.profile.role == 'owner' &&
          await _firestoreService.isOwnerAlsoInstructor(
            ownerId: widget.profile.id,
            schoolId: schoolId,
          );
      if (mounted) {
        setState(() => _isOwner = ownsSchool || isOwnerAlsoInstructor);
      }
    }
  }

  void _listenToPendingCancellations() {
    _cancellationSubscription = _firestoreService
        .streamPendingCancellationRequests(widget.profile.id)
        .listen((requests) {
      if (mounted) {
        final newCount = requests.length;
        // Only call setState if the count actually changed
        if (_pendingCancellations != newCount) {
          setState(() => _pendingCancellations = newCount);
        }
      }
    });
  }

  void _onNavTap(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AppBar(
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          const AppLogo(
            size: 36,
            borderRadius: 10,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DriveMate',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                widget.profile.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Chat button with unread badge
        StreamBuilder<int>(
          stream: _chatService.streamTotalUnreadCount(
            widget.profile.id,
            'instructor',
          ),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            return Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ConversationsListScreen(
                          profile: widget.profile,
                        ),
                      ),
                    );
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        // Cancellation requests button
        IconButton(
          icon: Stack(
            children: [
              Icon(
                Icons.event_busy_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              if (_pendingCancellations > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppTheme.warning,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _pendingCancellations > 9 ? '9+' : '$_pendingCancellations',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CancellationRequestsScreen(
                  instructor: widget.profile,
                ),
              ),
            );
          },
        ),
        // Profile / More menu
        PopupMenuButton<String>(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getInitials(widget.profile.name),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          offset: const Offset(0, 8),
          itemBuilder: (context) => [
            _buildPopupHeader(context),
            const PopupMenuDivider(),
            // Top items: Settings, Log out
            _buildPopupItem(
              context,
              icon: Icons.settings_outlined,
              label: 'Settings',
              value: 'settings',
            ),
            _buildPopupItem(
              context,
              icon: Icons.logout_rounded,
              label: 'Log out',
              value: 'logout',
              isDestructive: true,
            ),
            if (_isOwner) const PopupMenuDivider(),
            if (_isOwner) _buildViewSwitcherMenuItem(context),
            if (_isOwner) const PopupMenuDivider(),
            // Owner-only menu items
            if (_isOwner) ...[
              _buildPopupItem(
                context,
                icon: Icons.people_outlined,
                label: 'Manage Instructors',
                value: 'instructors',
              ),
              _buildPopupItem(
                context,
                icon: Icons.lock_open_outlined,
                label: 'School Access Requests',
                value: 'school_access',
              ),
              _buildPopupItem(
                context,
                icon: Icons.bar_chart_outlined,
                label: 'School Reports',
                value: 'school_reports',
              ),
            ],
            const PopupMenuDivider(),
            _buildPopupItem(
              context,
              icon: Icons.receipt_long_outlined,
              label: 'Expenses',
              value: 'expenses',
            ),
            _buildPopupItem(
              context,
              icon: Icons.repeat_rounded,
              label: 'Recurring Lessons',
              value: 'recurring_lessons',
            ),
            _buildPopupItem(
              context,
              icon: Icons.campaign_outlined,
              label: 'Announcements',
              value: 'announcements',
            ),
            _buildPopupItem(
              context,
              icon: Icons.description_outlined,
              label: 'Terms & Conditions',
              value: 'terms',
            ),
          ],
          onSelected: (value) {
            if (value == 'settings') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsMainScreen(
                    instructor: widget.profile,
                  ),
                ),
              );
            }
            if (value == 'instructors' && _isOwner) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OwnerInstructorsScreen(
                    owner: widget.profile,
                  ),
                ),
              );
            }
            if (value == 'school_access' && _isOwner) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OwnerAccessRequestsScreen(
                    owner: widget.profile,
                  ),
                ),
              );
            }
            if (value == 'school_reports' && _isOwner) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OwnerReportsScreen(
                    owner: widget.profile,
                  ),
                ),
              );
            }
            if (value == 'expenses') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InstructorExpensesScreen(
                    instructor: widget.profile,
                  ),
                ),
              );
            }
            if (value == 'recurring_lessons') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecurringLessonScreen(
                    instructor: widget.profile,
                  ),
                ),
              );
            }
            if (value == 'announcements') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AnnouncementsScreen(
                    profile: widget.profile,
                    isOwner: _isOwner,
                  ),
                ),
              );
            }
            if (value == 'terms') {
              final schoolId = widget.profile.schoolId ?? '';
              if (schoolId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Text('School not linked yet.'),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TermsScreen(
                    schoolId: schoolId,
                    canEdit: _isOwner, // Allow editing if owner
                  ),
                ),
              );
            }
            if (value == 'logout') {
              _showLogoutConfirmation(context);
            }
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  PopupMenuItem<String> _buildViewSwitcherMenuItem(BuildContext context) {
    return PopupMenuItem<String>(
      enabled: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SegmentedButton<String>(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          visualDensity: VisualDensity.compact,
        ),
        segments: const [
          ButtonSegment<String>(
            value: 'instructor',
            label: Text('Instructor'),
            icon: Icon(Icons.school_rounded, size: 18),
          ),
          ButtonSegment<String>(
            value: 'owner',
            label: Text('Owner'),
            icon: Icon(Icons.business_rounded, size: 18),
          ),
        ],
        selected: const {'instructor'},
        onSelectionChanged: (Set<String> selection) {
          if (selection.contains('owner')) {
            OwnerInstructorChoiceScreen.openAsOwner(context, widget.profile);
          }
        },
      ),
    );
  }

  PopupMenuItem<String> _buildPopupHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuItem<String>(
      enabled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.profile.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.profile.email,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDestructive ? AppTheme.error : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDestructive ? AppTheme.error : colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              return _buildNavItem(
                item: _navItems[index],
                isSelected: _currentIndex == index,
                onTap: () => _onNavTap(index),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required _NavItem item,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected ? primary : colorScheme.onSurfaceVariant,
              size: 22,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppTheme.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text('Log out?'),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of DriveMate?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context, rootNavigator: true);
              Navigator.pop(context);
              navigator.popUntil((route) => route.isFirst);
              await _authService.signOut();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}
