import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/cancellation_request.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class CancellationRequestsScreen extends StatefulWidget {
  const CancellationRequestsScreen({super.key, required this.instructor});

  final UserProfile instructor;

  @override
  State<CancellationRequestsScreen> createState() =>
      _CancellationRequestsScreenState();
}

class _CancellationRequestsScreenState
    extends State<CancellationRequestsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Map<String, Student?> _studentsCache = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutral50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Cancellation Requests',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.neutral900,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.neutral700),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<CancellationRequest>>(
        stream: _firestoreService
            .streamCancellationRequestsForInstructor(widget.instructor.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading requests...');
          }

          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return const EmptyView(
              message: 'No cancellation requests',
              subtitle: 'Student requests will appear here',
              type: EmptyViewType.noData,
            );
          }

          // Sort by status (pending first) then by date
          final sortedRequests = List<CancellationRequest>.from(requests)
            ..sort((a, b) {
              if (a.status == 'pending' && b.status != 'pending') return -1;
              if (a.status != 'pending' && b.status == 'pending') return 1;
              return b.createdAt.compareTo(a.createdAt);
            });

          final pendingRequests =
              sortedRequests.where((r) => r.status == 'pending').toList();
          final processedRequests =
              sortedRequests.where((r) => r.status != 'pending').toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pendingRequests.isNotEmpty) ...[
                  _buildSectionHeader('Pending Requests', pendingRequests.length),
                  const SizedBox(height: 12),
                  ...pendingRequests.map((r) => _buildRequestCard(context, r)),
                  const SizedBox(height: 24),
                ],
                if (processedRequests.isNotEmpty) ...[
                  _buildSectionHeader('Processed', processedRequests.length),
                  const SizedBox(height: 12),
                  ...processedRequests.map((r) => _buildRequestCard(context, r)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.neutral900,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(BuildContext context, CancellationRequest request) {
    return FutureBuilder<Student?>(
      future: _getStudent(request.studentId),
      builder: (context, snapshot) {
        final student = snapshot.data;
        final studentName = student?.name ?? 'Student';
        final lessonDate = request.lessonStartAt != null
            ? DateFormat('EEEE, d MMMM').format(request.lessonStartAt!)
            : 'Unknown date';
        final lessonTime = request.lessonStartAt != null
            ? DateFormat('HH:mm').format(request.lessonStartAt!)
            : '';

        final isPending = request.status == 'pending';
        final isApproved = request.status == 'approved';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPending ? AppTheme.warning.withOpacity(0.3) : AppTheme.neutral200,
              width: isPending ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isPending
                            ? AppTheme.warningLight
                            : (isApproved ? AppTheme.successLight : AppTheme.errorLight),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPending
                            ? Icons.event_busy_rounded
                            : (isApproved
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined),
                        color: isPending
                            ? AppTheme.warning
                            : (isApproved ? AppTheme.success : AppTheme.error),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.neutral900,
                            ),
                          ),
                          Text(
                            '$lessonDate at $lessonTime',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.neutral500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(request.status),
                  ],
                ),
              ),
              // Details
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.neutral50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Lesson Duration',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.neutral600,
                            ),
                          ),
                          Text(
                            '${request.hoursToDeduct.toStringAsFixed(1)} hours',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.neutral900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Charge Rate',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.neutral600,
                            ),
                          ),
                          Text(
                            '${request.chargePercent}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: request.chargePercent > 0
                                  ? AppTheme.warning
                                  : AppTheme.success,
                            ),
                          ),
                        ],
                      ),
                      if (request.chargePercent > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Hours to Deduct',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.neutral600,
                              ),
                            ),
                            Text(
                              '${(request.hoursToDeduct * request.chargePercent / 100).toStringAsFixed(1)} hours',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.warning,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Reason
              if (request.reason != null && request.reason!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reason',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.neutral700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.reason!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.neutral600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Request time
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Requested ${_formatTimeAgo(request.createdAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.neutral400,
                  ),
                ),
              ),
              // Actions (for pending requests)
              if (isPending) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleDecline(context, request),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side: const BorderSide(color: AppTheme.error),
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () => _handleApprove(context, request),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.success,
                          ),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = switch (status) {
      'pending' => AppTheme.warning,
      'approved' => AppTheme.success,
      'declined' => AppTheme.error,
      _ => AppTheme.neutral500,
    };
    final bgColor = switch (status) {
      'pending' => AppTheme.warningLight,
      'approved' => AppTheme.successLight,
      'declined' => AppTheme.errorLight,
      _ => AppTheme.neutral100,
    };
    final label = switch (status) {
      'pending' => 'Pending',
      'approved' => 'Approved',
      'declined' => 'Declined',
      _ => status,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<Student?> _getStudent(String studentId) async {
    if (_studentsCache.containsKey(studentId)) {
      return _studentsCache[studentId];
    }
    final student = await _firestoreService.getStudentById(studentId);
    _studentsCache[studentId] = student;
    return student;
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(date);
  }

  Future<void> _handleApprove(
    BuildContext context,
    CancellationRequest request,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppTheme.success,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(child: Text('Approve Cancellation?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will:'),
            const SizedBox(height: 8),
            Text(
              '• Cancel the lesson',
              style: TextStyle(color: AppTheme.neutral700),
            ),
            if (request.chargePercent > 0)
              Text(
                '• Deduct ${(request.hoursToDeduct * request.chargePercent / 100).toStringAsFixed(1)} hours from student balance',
                style: TextStyle(color: AppTheme.neutral700),
              ),
            if (request.chargePercent == 0)
              Text(
                '• Refund all hours to student balance',
                style: TextStyle(color: AppTheme.neutral700),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _firestoreService.approveCancellationRequest(request);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Cancellation approved'),
                ],
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleDecline(
    BuildContext context,
    CancellationRequest request,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                Icons.cancel_outlined,
                color: AppTheme.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(child: Text('Decline Request?')),
          ],
        ),
        content: const Text(
          'The lesson will remain scheduled. The student will be notified of your decision.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _firestoreService.declineCancellationRequest(request.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Request declined'),
                ],
              ),
              backgroundColor: AppTheme.neutral700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }
}
