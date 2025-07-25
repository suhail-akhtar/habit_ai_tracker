class CustomHabitCategory {
  final int? id;
  final String name;
  final String iconName;
  final String colorCode;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomHabitCategory({
    this.id,
    required this.name,
    required this.iconName,
    required this.colorCode,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon_name': iconName,
    'color_code': colorCode,
    'is_default': isDefault ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory CustomHabitCategory.fromMap(Map<String, dynamic> map) =>
      CustomHabitCategory(
        id: map['id'],
        name: map['name'],
        iconName: map['icon_name'],
        colorCode: map['color_code'],
        isDefault: (map['is_default'] ?? 0) == 1,
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
      );

  CustomHabitCategory copyWith({
    int? id,
    String? name,
    String? iconName,
    String? colorCode,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CustomHabitCategory(
    id: id ?? this.id,
    name: name ?? this.name,
    iconName: iconName ?? this.iconName,
    colorCode: colorCode ?? this.colorCode,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  String toString() => 'CustomHabitCategory(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomHabitCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
