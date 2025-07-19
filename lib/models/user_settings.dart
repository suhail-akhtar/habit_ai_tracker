class UserSettings {
  final String key;
  final String value;
  final DateTime updatedAt;

  UserSettings({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'key': key,
        'value': value,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory UserSettings.fromMap(Map<String, dynamic> map) => UserSettings(
        key: map['key'],
        value: map['value'],
        updatedAt: DateTime.parse(map['updated_at']),
      );

  @override
  String toString() => 'UserSettings(key: $key, value: $value)';
}
