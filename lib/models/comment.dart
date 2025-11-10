class Comment {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<CommentReply> replies;
  final CommentReactions reactions;
  final bool isPinned;
  final bool isEdited;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.replies = const [],
    CommentReactions? reactions,
    this.isPinned = false,
    this.isEdited = false,
  }) : reactions = reactions ?? CommentReactions();

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? json['userId'] as String,
      userName: json['user_name'] as String? ?? json['userName'] as String,
      userAvatarUrl: json['user_avatar_url'] as String? ?? json['userAvatarUrl'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String? ?? json['createdAt'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'] as String)
              : null,
      replies: (json['replies'] as List<dynamic>?)
              ?.map((reply) => CommentReply.fromJson(reply as Map<String, dynamic>))
              .toList() ?? [],
      reactions: json['reactions'] != null
          ? CommentReactions.fromJson(json['reactions'] as Map<String, dynamic>)
          : null,
      isPinned: json['is_pinned'] == true || json['isPinned'] == true,
      isEdited: json['is_edited'] == true || json['isEdited'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_avatar_url': userAvatarUrl,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'replies': replies.map((reply) => reply.toJson()).toList(),
      'reactions': reactions.toJson(),
      'is_pinned': isPinned,
      'is_edited': isEdited,
    };
  }

  Comment copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<CommentReply>? replies,
    CommentReactions? reactions,
    bool? isPinned,
    bool? isEdited,
  }) {
    return Comment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      replies: replies ?? this.replies,
      reactions: reactions ?? this.reactions,
      isPinned: isPinned ?? this.isPinned,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}

class CommentReply {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEdited;

  CommentReply({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.isEdited = false,
  });

  factory CommentReply.fromJson(Map<String, dynamic> json) {
    return CommentReply(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? json['userId'] as String,
      userName: json['user_name'] as String? ?? json['userName'] as String,
      userAvatarUrl: json['user_avatar_url'] as String? ?? json['userAvatarUrl'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String? ?? json['createdAt'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'] as String)
              : null,
      isEdited: json['is_edited'] == true || json['isEdited'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_avatar_url': userAvatarUrl,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_edited': isEdited,
    };
  }
}

class CommentReactions {
  int helpful;
  int notHelpful;
  int likes;
  int dislikes;
  Set<String> helpfulUsers;
  Set<String> notHelpfulUsers;
  Set<String> likedUsers;
  Set<String> dislikedUsers;

  CommentReactions({
    this.helpful = 0,
    this.notHelpful = 0,
    this.likes = 0,
    this.dislikes = 0,
    Set<String>? helpfulUsers,
    Set<String>? notHelpfulUsers,
    Set<String>? likedUsers,
    Set<String>? dislikedUsers,
  })  : helpfulUsers = helpfulUsers ?? {},
        notHelpfulUsers = notHelpfulUsers ?? {},
        likedUsers = likedUsers ?? {},
        dislikedUsers = dislikedUsers ?? {};

  factory CommentReactions.fromJson(Map<String, dynamic> json) {
    return CommentReactions(
      helpful: json['helpful'] as int? ?? 0,
      notHelpful: json['not_helpful'] as int? ?? json['notHelpful'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      dislikes: json['dislikes'] as int? ?? 0,
      helpfulUsers: (json['helpful_users'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ?? 
          (json['helpfulUsers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ?? {},
      notHelpfulUsers: (json['not_helpful_users'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ?? 
          (json['notHelpfulUsers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ?? {},
      likedUsers: (json['liked_users'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ?? 
          (json['likedUsers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ?? {},
      dislikedUsers: (json['disliked_users'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ?? 
          (json['dislikedUsers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'helpful': helpful,
      'not_helpful': notHelpful,
      'likes': likes,
      'dislikes': dislikes,
      'helpful_users': helpfulUsers.toList(),
      'not_helpful_users': notHelpfulUsers.toList(),
      'liked_users': likedUsers.toList(),
      'disliked_users': dislikedUsers.toList(),
    };
  }

  CommentReactions copyWith({
    int? helpful,
    int? notHelpful,
    int? likes,
    int? dislikes,
    Set<String>? helpfulUsers,
    Set<String>? notHelpfulUsers,
    Set<String>? likedUsers,
    Set<String>? dislikedUsers,
  }) {
    return CommentReactions(
      helpful: helpful ?? this.helpful,
      notHelpful: notHelpful ?? this.notHelpful,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      helpfulUsers: helpfulUsers ?? this.helpfulUsers,
      notHelpfulUsers: notHelpfulUsers ?? this.notHelpfulUsers,
      likedUsers: likedUsers ?? this.likedUsers,
      dislikedUsers: dislikedUsers ?? this.dislikedUsers,
    );
  }
}

