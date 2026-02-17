import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/conversation.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/chat_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import 'chat_screen.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({
    super.key,
    required this.profile,
  });

  final UserProfile profile;

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  final ChatService _chatService = ChatService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<void> _startConversationWithInstructor() async {
    if (widget.profile.studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student profile not found'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Get student to find instructor
    final student = await _firestoreService.getStudentById(widget.profile.studentId!);
    if (student == null || student.instructorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instructor not found'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    try {
      // Create or get conversation
      final conversationId = await _chatService.getOrCreateConversation(
        instructorId: student.instructorId,
        studentId: widget.profile.studentId!,
      );

      // Get instructor name
      final instructorName = await _chatService.getInstructorName(student.instructorId);

      // Navigate to chat
      if (mounted) {
        final conversation = await _chatService.getConversation(conversationId);
        if (conversation != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                conversation: conversation,
                profile: widget.profile,
                otherUserName: instructorName,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start conversation: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showStudentPicker() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _StudentPickerBottomSheet(
        instructorId: widget.profile.id,
        chatService: _chatService,
        firestoreService: _firestoreService,
        profile: widget.profile,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInstructor = widget.profile.role == 'instructor';
    final isStudent = widget.profile.role == 'student';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Messages'),
      ),
      body: Column(
        children: [
          // Bug 1.6: Search bar for conversations
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Conversation>>(
              stream: isInstructor
                  ? _chatService.streamInstructorConversations(widget.profile.id)
                  : isStudent && widget.profile.studentId != null
                      ? _chatService.streamStudentConversations(widget.profile.studentId!)
                      : Stream.value(<Conversation>[]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: AppTheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading conversations',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final conversations = snapshot.data ?? [];

                if (conversations.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 40,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No conversations yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start a conversation with your ${isInstructor ? 'students' : 'instructor'}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: isInstructor
                                ? _showStudentPicker
                                : _startConversationWithInstructor,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(
                              isInstructor ? 'Select Student' : 'Start Conversation',
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: conversations.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    return _ConversationTile(
                      conversation: conversation,
                      profile: widget.profile,
                      chatService: _chatService,
                      firestoreService: _firestoreService,
                      searchQuery: _searchQuery,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isInstructor
          ? FloatingActionButton.extended(
              onPressed: _showStudentPicker,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Chat'),
            )
          : null,
    );
  }
}

class _StudentPickerBottomSheet extends StatelessWidget {
  const _StudentPickerBottomSheet({
    required this.instructorId,
    required this.chatService,
    required this.firestoreService,
    required this.profile,
  });

  final String instructorId;
  final ChatService chatService;
  final FirestoreService firestoreService;
  final UserProfile profile;

  Future<void> _startConversationWithStudent(
    BuildContext context,
    Student student,
  ) async {
    try {
      // Create or get conversation
      final conversationId = await chatService.getOrCreateConversation(
        instructorId: instructorId,
        studentId: student.id,
      );

      // Get student name
      final studentName = student.name;

      // Navigate to chat
      if (context.mounted) {
        final conversation = await chatService.getConversation(conversationId);
        if (conversation != null) {
          Navigator.of(context).pop(); // Close bottom sheet
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                conversation: conversation,
                profile: profile,
                otherUserName: studentName,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start conversation: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        final colorScheme = Theme.of(context).colorScheme;
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Select Student',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Students list
            Expanded(
              child: StreamBuilder<List<Student>>(
                stream: firestoreService.streamStudents(instructorId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: AppTheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading students',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  final students = snapshot.data ?? [];

                  if (students.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No students yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add students to start conversations',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: students.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: context.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _getInitials(student.name),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            student.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          subtitle: student.email != null && student.email!.isNotEmpty
                              ? Text(
                                  student.email!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : null,
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onTap: () => _startConversationWithStudent(context, student),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}

class _ConversationTile extends StatefulWidget {
  const _ConversationTile({
    required this.conversation,
    required this.profile,
    required this.chatService,
    required this.firestoreService,
    this.searchQuery = '',
  });

  final Conversation conversation;
  final UserProfile profile;
  final ChatService chatService;
  final FirestoreService firestoreService;
  final String searchQuery;

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  String _otherUserName = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOtherUserName();
  }

  Future<void> _loadOtherUserName() async {
    final isInstructor = widget.profile.role == 'instructor';
    String name;

    if (isInstructor) {
      // Get student name
      name = await widget.chatService.getStudentName(
        widget.conversation.studentId,
      );
    } else {
      // Get instructor name
      name = await widget.chatService.getInstructorName(
        widget.conversation.instructorId,
      );
    }

    if (mounted) {
      setState(() {
        _otherUserName = name;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bug 1.6: Filter by search query
    if (widget.searchQuery.isNotEmpty) {
      final nameMatch = _otherUserName.toLowerCase().contains(widget.searchQuery);
      final messageMatch = (widget.conversation.lastMessage ?? '')
          .toLowerCase()
          .contains(widget.searchQuery);
      if (!nameMatch && !messageMatch) {
        return const SizedBox.shrink();
      }
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isInstructor = widget.profile.role == 'instructor';
    final unreadCount = isInstructor
        ? widget.conversation.unreadCountInstructor
        : widget.conversation.unreadCountStudent;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                conversation: widget.conversation,
                profile: widget.profile,
                otherUserName: _otherUserName,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: context.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _getInitials(_otherUserName),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isLoading ? 'Loading...' : _otherUserName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.conversation.lastMessageAt != null)
                          Text(
                            _formatTime(widget.conversation.lastMessageAt!),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.conversation.lastMessage ?? 'No messages yet',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
    );

    if (messageDate == today) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(messageDate).inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
}
