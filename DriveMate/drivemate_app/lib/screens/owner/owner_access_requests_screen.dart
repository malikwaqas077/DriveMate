import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/access_request.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class OwnerAccessRequestsScreen extends StatelessWidget {
  OwnerAccessRequestsScreen({super.key, required this.owner});

  final UserProfile owner;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final schoolId = owner.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      return const Center(child: Text('School not set up.'));
    }
    return StreamBuilder<List<AccessRequest>>(
      stream: _firestoreService.streamAccessRequestsForSchool(schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading requests...');
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const EmptyView(message: 'No access requests yet.');
        }
        return ListView.separated(
          itemCount: requests.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final request = requests[index];
            return FutureBuilder<UserProfile?>(
              future:
                  _firestoreService.getUserProfile(request.instructorId),
              builder: (context, profileSnapshot) {
                final profile = profileSnapshot.data;
                final name = profile?.name ?? 'Instructor';
                final date = request.createdAt ?? DateTime.now();
                return ListTile(
                  title: Text(name),
                  subtitle: Text(
                    'Status: ${request.status} · ${DateFormat('dd MMM yyyy').format(date)}',
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
