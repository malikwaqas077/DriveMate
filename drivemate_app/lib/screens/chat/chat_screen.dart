import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../models/user_profile.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversation,
    required this.profile,
    required this.otherUserName,
  });

  final Conversation conversation;
  final UserProfile profile;
  final String otherUserName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  // Bug 1.4: Manual stream subscription instead of StreamBuilder
  StreamSubscription<List<Message>>? _messagesSubscription;
  List<Message> _messages = [];
  bool _isLoadingMessages = true;
  String? _messagesError;
  bool _hasInitiallyScrolled = false;

  @override
  void initState() {
    super.initState();

    // Bug 1.3: Set active conversation to suppress notifications
    NotificationService.instance.setActiveConversation(widget.conversation.id);

    // Bug 1.2: Cancel any existing notification for this conversation
    NotificationService.instance.cancelNotification(widget.conversation.id.hashCode);

    // Bug 1.4: Subscribe to messages stream manually
    _messagesSubscription = _chatService
        .streamMessages(widget.conversation.id)
        .listen(
      (messages) {
        if (!mounted) return;
        final hadMessages = _messages.isNotEmpty;
        final previousCount = _messages.length;

        setState(() {
          _messages = messages;
          _isLoadingMessages = false;
          _messagesError = null;
        });

        // Auto-scroll: only on first load or if user is near bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;

          if (!_hasInitiallyScrolled) {
            // First load: jump to bottom
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
            _hasInitiallyScrolled = true;
          } else if (messages.length > previousCount) {
            // New message arrived: only scroll if near bottom
            final maxScroll = _scrollController.position.maxScrollExtent;
            final currentScroll = _scrollController.offset;
            if (maxScroll - currentScroll < 100) {
              _scrollController.animateTo(
                maxScroll,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          }
        });

        // Mark as read only when new messages from other sender arrive
        if (messages.isNotEmpty && messages.length > previousCount) {
          final lastMessage = messages.last;
          if (lastMessage.senderId != widget.profile.id) {
            _markAsRead();
          }
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _messagesError = error.toString();
          _isLoadingMessages = false;
        });
      },
    );

    // Mark messages as read when opening chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsRead();
    });
  }

  @override
  void dispose() {
    // Bug 1.3: Clear active conversation
    NotificationService.instance.setActiveConversation(null);
    // Bug 1.4: Cancel stream subscription
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    try {
      await _chatService.markAsRead(
        conversationId: widget.conversation.id,
        userId: widget.profile.id,
        userRole: widget.profile.role,
      );
      // Bug 1.2: Cancel notification after marking as read
      NotificationService.instance.cancelNotification(widget.conversation.id.hashCode);
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversation.id,
        text: text,
        senderId: widget.profile.id,
        senderRole: widget.profile.role,
      );

      _messageController.clear();

      // Scroll to bottom after sending
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: context.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getInitials(widget.otherUserName),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    widget.profile.role == 'instructor' ? 'Student' : 'Instructor',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list - Bug 1.4: No longer using StreamBuilder
          Expanded(
            child: _buildMessagesList(colorScheme),
          ),
          // Message input
          Container(
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
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: context.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _isSending
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.onPrimary,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.send_rounded,
                                color: colorScheme.onPrimary,
                              ),
                        onPressed: _isSending ? null : _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ColorScheme colorScheme) {
    if (_isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messagesError != null) {
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
              'Error loading messages',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
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
              'No messages yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isOwnMessage = message.senderId == widget.profile.id;
        final showDateSeparator = index == 0 ||
            _shouldShowDateSeparator(
              _messages[index - 1].createdAt,
              message.createdAt,
            );

        return Column(
          // Bug 1.4: Add ValueKey to prevent widget reuse issues
          key: ValueKey(message.id),
          children: [
            if (showDateSeparator && message.createdAt != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _formatDate(message.createdAt!),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            _MessageBubble(
              message: message,
              isOwnMessage: isOwnMessage,
            ),
          ],
        );
      },
    );
  }

  bool _shouldShowDateSeparator(DateTime? prevDate, DateTime? currentDate) {
    if (prevDate == null || currentDate == null) return false;

    final prev = DateTime(prevDate.year, prevDate.month, prevDate.day);
    final current = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );

    return prev != current;
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
    );

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, y').format(dateTime);
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isOwnMessage,
  });

  final Message message;
  final bool isOwnMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isOwnMessage
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isOwnMessage
                ? const Radius.circular(20)
                : const Radius.circular(4),
            bottomRight: isOwnMessage
                ? const Radius.circular(4)
                : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 15,
                color: isOwnMessage ? colorScheme.onPrimary : colorScheme.onSurface,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.createdAt != null
                      ? DateFormat('HH:mm').format(message.createdAt!)
                      : '',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOwnMessage
                        ? colorScheme.onPrimary.withOpacity(0.7)
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isOwnMessage && message.readAt != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all_rounded,
                    size: 14,
                    color: colorScheme.onPrimary.withOpacity(0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
