import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/comment.dart';
import '../../services/comment_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Comment> _comments = [];
  bool _isLoading = false;
  String? _replyingToCommentId;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadComments();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _currentUserId = user?.id.toString() ?? 'anonymous';
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final comments = await CommentService.getComments();
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading comments: $e')),
        );
      }
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to comment')),
      );
      return;
    }

    try {
      await CommentService.addComment(
        userId: user.id.toString(),
        userName: user.fullName,
        userAvatarUrl: user.profilePicture,
        content: text,
      );
      _commentController.clear();
      await _loadComments();
      _scrollToTop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')),
        );
      }
    }
  }

  Future<void> _addReply(String commentId) async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to reply')),
      );
      return;
    }

    try {
      await CommentService.addReply(
        commentId: commentId,
        userId: user.id.toString(),
        userName: user.fullName,
        userAvatarUrl: user.profilePicture,
        content: text,
      );
      _replyController.clear();
      setState(() {
        _replyingToCommentId = null;
      });
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding reply: $e')),
        );
      }
    }
  }

  Future<void> _toggleReaction(String commentId, ReactionType reactionType) async {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to react')),
      );
      return;
    }

    try {
      await CommentService.addReaction(
        commentId: commentId,
        userId: user.id.toString(),
        reactionType: reactionType,
      );
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding reaction: $e')),
        );
      }
    }
  }

  Future<void> _togglePin(String commentId) async {
    try {
      await CommentService.togglePin(commentId);
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling pin: $e')),
        );
      }
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Chat'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadComments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.comment_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No comments yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to start the conversation!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadComments,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            return _buildCommentCard(_comments[index]);
                          },
                        ),
                      ),
          ),
          if (_replyingToCommentId == null)
            _buildCommentInput()
          else
            _buildReplyInput(),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Comment comment) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final isCurrentUser = user?.id.toString() == comment.userId;
    final reactions = comment.reactions;
    final userIdStr = user?.id.toString() ?? '';
    final hasHelpful = reactions.helpfulUsers.contains(userIdStr);
    final hasNotHelpful = reactions.notHelpfulUsers.contains(userIdStr);
    final hasLike = reactions.likedUsers.contains(userIdStr);
    final hasDislike = reactions.dislikedUsers.contains(userIdStr);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: comment.isPinned ? 4 : 2,
      color: comment.isPinned
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  backgroundImage: comment.userAvatarUrl != null &&
                          comment.userAvatarUrl!.isNotEmpty
                      ? NetworkImage(comment.userAvatarUrl!)
                      : null,
                  child: comment.userAvatarUrl == null ||
                          comment.userAvatarUrl!.isEmpty
                      ? Text(
                          comment.userName.isNotEmpty
                              ? comment.userName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              comment.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (comment.isPinned) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.push_pin,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _formatDate(comment.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrentUser)
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.push_pin, size: 20),
                            SizedBox(width: 8),
                            Text('Pin/Unpin'),
                          ],
                        ),
                        onTap: () => _togglePin(comment.id),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              comment.content,
              style: const TextStyle(fontSize: 15),
            ),
            if (comment.isEdited) ...[
              const SizedBox(height: 4),
              Text(
                '(edited)',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Reactions Row
            Wrap(
              spacing: 16,
              children: [
                _buildReactionButton(
                  icon: Icons.thumb_up,
                  label: 'Helpful',
                  count: reactions.helpful,
                  isActive: hasHelpful,
                  onTap: () => _toggleReaction(comment.id, ReactionType.helpful),
                ),
                _buildReactionButton(
                  icon: Icons.thumb_down,
                  label: 'Not Helpful',
                  count: reactions.notHelpful,
                  isActive: hasNotHelpful,
                  onTap: () =>
                      _toggleReaction(comment.id, ReactionType.notHelpful),
                ),
                _buildReactionButton(
                  icon: Icons.favorite,
                  label: 'Like',
                  count: reactions.likes,
                  isActive: hasLike,
                  onTap: () => _toggleReaction(comment.id, ReactionType.like),
                ),
                _buildReactionButton(
                  icon: Icons.favorite_border,
                  label: 'Dislike',
                  count: reactions.dislikes,
                  isActive: hasDislike,
                  onTap: () =>
                      _toggleReaction(comment.id, ReactionType.dislike),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.reply, size: 18),
                  label: const Text('Reply'),
                  onPressed: () {
                    setState(() {
                      _replyingToCommentId = comment.id;
                    });
                  },
                ),
              ],
            ),
            // Replies Section
            if (comment.replies.isNotEmpty) ...[
              const Divider(height: 24),
              ...comment.replies.map((reply) => _buildReplyCard(reply)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReplyCard(CommentReply reply) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final isCurrentUser = user?.id.toString() == reply.userId;

    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            backgroundImage: reply.userAvatarUrl != null &&
                    reply.userAvatarUrl!.isNotEmpty
                ? NetworkImage(reply.userAvatarUrl!)
                : null,
            child: reply.userAvatarUrl == null || reply.userAvatarUrl!.isEmpty
                ? Text(
                    reply.userName.isNotEmpty
                        ? reply.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(reply.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply.content,
                  style: const TextStyle(fontSize: 14),
                ),
                if (reply.isEdited) ...[
                  const SizedBox(height: 4),
                  Text(
                    '(edited)',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionButton({
    required IconData icon,
    required String label,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade600,
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            color: Theme.of(context).colorScheme.primary,
            onPressed: _addComment,
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Replying to comment',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _replyingToCommentId = null;
                    _replyController.clear();
                  });
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  decoration: InputDecoration(
                    hintText: 'Write a reply...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                color: Theme.of(context).colorScheme.primary,
                onPressed: () {
                  if (_replyingToCommentId != null) {
                    _addReply(_replyingToCommentId!);
                  }
                },
                tooltip: 'Send',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

