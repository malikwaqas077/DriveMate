import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../instructor/terms_screen.dart';
import 'owner_access_requests_screen.dart';
import 'owner_instructors_screen.dart';
import 'owner_reports_screen.dart';

class OwnerHome extends StatelessWidget {
  const OwnerHome({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
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
              onSelected: (value) {
                if (value == 'terms') {
                  final schoolId = profile.schoolId ?? '';
                  if (schoolId.isEmpty) {
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
                        schoolId: schoolId,
                        canEdit: true,
                      ),
                    ),
                  );
                }
                if (value == 'logout') {
                  authService.signOut();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'terms',
                  child: Text('Terms & Conditions'),
                ),
                PopupMenuItem(
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
  }
}
