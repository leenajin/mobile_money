class Category {
  final int? id;
  final String name;
  final bool isDefault;

  const Category({this.id, required this.name, this.isDefault = false});

  Category copyWith({int? id, String? name}) =>
      Category(id: id ?? this.id, name: name ?? this.name, isDefault: isDefault);

  Map<String, Object?> toMap() =>
      {'id': id, 'name': name, 'is_default': isDefault ? 1 : 0};

  factory Category.fromMap(Map<String, Object?> m) => Category(
      id: m['id'] as int?,
      name: m['name'] as String,
      isDefault: m['is_default'] == 1);
}
