import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../appearance_screen.dart';
import '../instructor/terms_screen.dart';
import 'owner_access_requests_screen.dart';
import 'owner_instructor_choice_screen.dart';
import 'owner_instructors_screen.dart';
import 'owner_reports_screen.dart';

class OwnerHome extends StatelessWidget {
  const OwnerHome({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();
    final schoolId = profile.schoolId;
    final hasSchool = schoolId != null && schoolId.isNotEmpty;

    return FutureBuilder<bool>(
      future: hasSchool
          ? firestoreService.isOwnerAlsoInstructor(
              ownerId: profile.id,
              schoolId: schoolId,
            )
          : Future.value(false),
      builder: (context, snapshot) {
        final isAlsoInstructor = snapshot.data ?? false;
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('DriveMate'),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.people), text: 'Instructors'),
                  Tab(icon: Icon(Icons.lock_open), text: 'Access'),
                  Tab(icon: Icon(Icons.bar_chart), text: 'Reports'),
                ],
              ),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'terms') {
                      final sid = profile.schoolId ?? '';
                      if (sid.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('School not linked yet.'),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TermsScreen(
                            schoolId: sid,
                            canEdit: true,
                          ),
                        ),
                      );
                    }
                    if (value == 'appearance') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AppearanceScreen(),
                        ),
                      );
                    }
                    if (value == 'logout') {
                      await authService.signOut();
                    }
                  },
                  itemBuilder: (context) => [
                    if (isAlsoInstructor)
                      _buildViewSwitcherMenuItem(
                        context,
                        onSwitchToInstructor: () =>
                            OwnerInstructorChoiceScreen.openAsInstructor(
                                context, profile),
                      ),
                    if (isAlsoInstructor) const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'terms',
                      child: Text('Terms & Conditions'),
                    ),
                    const PopupMenuItem(
                      value: 'appearance',
                      child: Text('Appearance'),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Text('Log out'),
                    ),
                  ],
                ),
              ],
            ),
            body: TabBarView(
              children: [
                OwnerInstructorsScreen(owner: profile),
                OwnerAccessRequestsScreen(owner: profile),
                OwnerReportsScreen(owner: profile),
              ],
            ),
          ),
        );
      },
    );
  }

  static PopupMenuItem<String> _buildViewSwitcherMenuItem(
    BuildContext context, {
    required VoidCallback onSwitchToInstructor,
  }) {
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
            value: 'owner',
            label: Text('Owner'),
            icon: Icon(Icons.business_rounded, size: 18),
          ),
          ButtonSegment<String>(
            value: 'instructor',
            label: Text('Instructor'),
            icon: Icon(Icons.school_rounded, size: 18),
          ),
        ],
        selected: const {'owner'},
        onSelectionChanged: (Set<String> selection) {
          if (selection.contains('instructor')) {
            onSwitchToInstructor();
          }
        },
      ),
    );
  }
}
