import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/comment.dart';
import 'package:uuid/uuid.dart';

class CommentService {
  static const String _commentsKey = 'app_comments';
  static const _uuid = Uuid();

  // Get all comments
  static Future<List<Comment>> getComments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final commentsJson = prefs.getString(_commentsKey);
      
      if (commentsJson == null) {
        return [];
      }

      final List<dynamic> commentsList = json.decode(commentsJson);
      return commentsList
          .map((json) => Comment.fromJson(json as Map<String, dynamic>))
          .toList()
        ..sort((a, b) {
          // Pinned comments first, then by date
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
    } catch (e) {
      debugPrint('Error getting comments: $e');
      return [];
    }
  }

  // Add a new comment
  static Future<Comment> addComment({
    required String userId,
    required String userName,
    String? userAvatarUrl,
    required String content,
  }) async {
    try {
      final comment = Comment(
        id: _uuid.v4(),
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        content: content,
        createdAt: DateTime.now(),
      );

      final comments = await getComments();
      comments.insert(0, comment);
      await _saveComments(comments);

      return comment;
    } catch (e) {
      debugPrint('Error adding comment: $e');
      rethrow;
    }
  }

  // Add a reply to a comment
  static Future<CommentReply> addReply({
    required String commentId,
    required String userId,
    required String userName,
    String? userAvatarUrl,
    required String content,
  }) async {
    try {
      final reply = CommentReply(
        id: _uuid.v4(),
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        content: content,
        createdAt: DateTime.now(),
      );

      final comments = await getComments();
      final commentIndex = comments.indexWhere((c) => c.id == commentId);
      
      if (commentIndex == -1) {
        throw Exception('Comment not found');
      }

      final updatedReplies = [...comments[commentIndex].replies, reply];
      comments[commentIndex] = comments[commentIndex].copyWith(replies: updatedReplies);
      await _saveComments(comments);

      return reply;
    } catch (e) {
      debugPrint('Error adding reply: $e');
      rethrow;
    }
  }

  // Update a comment
  static Future<Comment> updateComment({
    required String commentId,
    required String content,
  }) async {
    try {
      final comments = await getComments();
      final commentIndex = comments.indexWhere((c) => c.id == commentId);
      
      if (commentIndex == -1) {
        throw Exception('Comment not found');
      }

      comments[commentIndex] = comments[commentIndex].copyWith(
        content: content,
        updatedAt: DateTime.now(),
        isEdited: true,
      );
      await _saveComments(comments);

      return comments[commentIndex];
    } catch (e) {
      debugPrint('Error updating comment: $e');
      rethrow;
    }
  }

  // Delete a comment
  static Future<void> deleteComment(String commentId) async {
    try {
      final comments = await getComments();
      comments.removeWhere((c) => c.id == commentId);
      await _saveComments(comments);
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      rethrow;
    }
  }

  // Toggle pin status
  static Future<Comment> togglePin(String commentId) async {
    try {
      final comments = await getComments();
      final commentIndex = comments.indexWhere((c) => c.id == commentId);
      
      if (commentIndex == -1) {
        throw Exception('Comment not found');
      }

      comments[commentIndex] = comments[commentIndex].copyWith(
        isPinned: !comments[commentIndex].isPinned,
      );
      await _saveComments(comments);

      return comments[commentIndex];
    } catch (e) {
      debugPrint('Error toggling pin: $e');
      rethrow;
    }
  }

  // Add reaction to a comment
  static Future<Comment> addReaction({
    required String commentId,
    required String userId,
    required ReactionType reactionType,
  }) async {
    try {
      final comments = await getComments();
      final commentIndex = comments.indexWhere((c) => c.id == commentId);
      
      if (commentIndex == -1) {
        throw Exception('Comment not found');
      }

      final comment = comments[commentIndex];
      var reactions = comment.reactions;

      // Remove user from all reaction lists first
      reactions.helpfulUsers.remove(userId);
      reactions.notHelpfulUsers.remove(userId);
      reactions.likedUsers.remove(userId);
      reactions.dislikedUsers.remove(userId);

      // Add to the selected reaction
      switch (reactionType) {
        case ReactionType.helpful:
          if (reactions.helpfulUsers.contains(userId)) {
            reactions.helpfulUsers.remove(userId);
          } else {
            reactions.helpfulUsers.add(userId);
          }
          break;
        case ReactionType.notHelpful:
          if (reactions.notHelpfulUsers.contains(userId)) {
            reactions.notHelpfulUsers.remove(userId);
          } else {
            reactions.notHelpfulUsers.add(userId);
          }
          break;
        case ReactionType.like:
          if (reactions.likedUsers.contains(userId)) {
            reactions.likedUsers.remove(userId);
          } else {
            reactions.likedUsers.add(userId);
          }
          break;
        case ReactionType.dislike:
          if (reactions.dislikedUsers.contains(userId)) {
            reactions.dislikedUsers.remove(userId);
          } else {
            reactions.dislikedUsers.add(userId);
          }
          break;
      }

      // Update counts
      reactions = reactions.copyWith(
        helpful: reactions.helpfulUsers.length,
        notHelpful: reactions.notHelpfulUsers.length,
        likes: reactions.likedUsers.length,
        dislikes: reactions.dislikedUsers.length,
      );

      comments[commentIndex] = comment.copyWith(reactions: reactions);
      await _saveComments(comments);

      return comments[commentIndex];
    } catch (e) {
      debugPrint('Error adding reaction: $e');
      rethrow;
    }
  }

  // Save comments to storage
  static Future<void> _saveComments(List<Comment> comments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final commentsJson = json.encode(
        comments.map((c) => c.toJson()).toList(),
      );
      await prefs.setString(_commentsKey, commentsJson);
    } catch (e) {
      debugPrint('Error saving comments: $e');
      rethrow;
    }
  }
}

enum ReactionType {
  helpful,
  notHelpful,
  like,
  dislike,
}

