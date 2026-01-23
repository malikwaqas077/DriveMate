import 'package:flutter/material.dart';

import '../../models/cancellation_request.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import 'access_requests_screen.dart';
import 'calendar_screen.dart';
import 'cancellation_requests_screen.dart';
import 'instructor_settings_screen.dart';
import 'payments_screen.dart';
import 'reports_screen.dart';
import 'students_screen.dart';
import 'terms_screen.dart';

class InstructorHome extends StatefulWidget {
  const InstructorHome({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<InstructorHome> createState() => _InstructorHomeState();
}

class _InstructorHomeState extends State<InstructorHome> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  int _currentIndex = 0;
  int _pendingCancellations = 0;

  late final List<Widget> _screens;
  late final List<_NavItem> _navItems;

  @override
  void initState() {
    super.initState();
    _screens = [
      CalendarScreen(instructor: widget.profile),
      StudentsScreen(instructor: widget.profile),
      PaymentsScreen(instructor: widget.profile),
      ReportsScreen(instructor: widget.profile),
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
        label: 'Payments',
      ),
      _NavItem(
        icon: Icons.analytics_outlined,
        activeIcon: Icons.analytics_rounded,
        label: 'Reports',
      ),
    ];
    _listenToPendingCancellations();
  }

  void _listenToPendingCancellations() {
    _firestoreService
        .streamPendingCancellationRequests(widget.profile.id)
        .listen((requests) {
      if (mounted) {
        setState(() => _pendingCancellations = requests.length);
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
      backgroundColor: AppTheme.neutral50,
      appBar: _buildAppBar(context),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DriveMate',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.neutral900,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                widget.profile.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.neutral500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Cancellation requests button
        IconButton(
          icon: Stack(
            children: [
              const Icon(
                Icons.event_busy_rounded,
                color: AppTheme.neutral700,
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
              color: AppTheme.neutral100,
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
            _buildPopupHeader(),
            const PopupMenuDivider(),
            _buildPopupItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              value: 'settings',
            ),
            _buildPopupItem(
              icon: Icons.notifications_outlined,
              label: 'Access requests',
              value: 'access',
            ),
            _buildPopupItem(
              icon: Icons.description_outlined,
              label: 'Terms & Conditions',
              value: 'terms',
            ),
            const PopupMenuDivider(),
            _buildPopupItem(
              icon: Icons.logout_rounded,
              label: 'Log out',
              value: 'logout',
              isDestructive: true,
            ),
          ],
          onSelected: (value) {
            if (value == 'settings') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InstructorSettingsScreen(
                    instructor: widget.profile,
                  ),
                ),
              );
            }
            if (value == 'access') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AccessRequestsScreen(
                    instructor: widget.profile,
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
                    canEdit: false,
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

  PopupMenuItem<String> _buildPopupHeader() {
    return PopupMenuItem<String>(
      enabled: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.profile.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.neutral900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.profile.email,
            style: TextStyle(
              color: AppTheme.neutral500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem({
    required IconData icon,
    required String label,
    required String value,
    bool isDestructive = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDestructive ? AppTheme.error : AppTheme.neutral600,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDestructive ? AppTheme.error : AppTheme.neutral700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected ? AppTheme.primary : AppTheme.neutral500,
              size: 22,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
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
            onPressed: () {
              Navigator.pop(context);
              _authService.signOut();
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
