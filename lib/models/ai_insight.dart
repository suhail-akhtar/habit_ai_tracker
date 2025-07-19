class AIInsight {
  final int? id;
  final String userId;
  final String insightType;
  final String content;
  final String dataHash;
  final DateTime createdAt;
  final DateTime expiresAt;

  AIInsight({
    this.id,
    required this.userId,
    required this.insightType,
    required this.content,
    required this.dataHash,
    required this.createdAt,
    required this.expiresAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'insight_type': insightType,
        'content': content,
        'data_hash': dataHash,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      };

  factory AIInsight.fromMap(Map<String, dynamic> map) => AIInsight(
        id: map['id'],
        userId: map['user_id'],
        insightType: map['insight_type'],
        content: map['content'],
        dataHash: map['data_hash'],
        createdAt: DateTime.parse(map['created_at']),
        expiresAt: DateTime.parse(map['expires_at']),
      );

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  String toString() => 'AIInsight(id: $id, type: $insightType)';
}
