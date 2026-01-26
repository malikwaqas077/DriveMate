import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/access_request.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class AccessRequestsScreen extends StatelessWidget {
  AccessRequestsScreen({super.key, required this.instructor});

  final UserProfile instructor;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access requests')),
      body: StreamBuilder<List<AccessRequest>>(
        stream:
            _firestoreService.streamAccessRequestsForInstructor(instructor.id),
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
              final date = request.createdAt ?? DateTime.now();
              final status = request.status;
              return ListTile(
                title: Text('School request'),
                subtitle: Text(
                  'Status: $status · ${DateFormat('dd MMM yyyy').format(date)}',
                ),
                trailing: status == 'pending'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => _respond(request.id, 'rejected'),
                            child: const Text('Reject'),
                          ),
                          FilledButton(
                            onPressed: () => _respond(request.id, 'approved'),
                            child: const Text('Approve'),
                          ),
                        ],
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _respond(String requestId, String status) {
    return _firestoreService.respondToAccessRequest(
      requestId: requestId,
      status: status,
    );
  }
}
