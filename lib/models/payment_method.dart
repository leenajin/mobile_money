class PaymentMethod {
  final int? id;
  final String name;
  final bool isDefault;

  const PaymentMethod({this.id, required this.name, this.isDefault = false});

  PaymentMethod copyWith({int? id, String? name}) =>
      PaymentMethod(id: id ?? this.id, name: name ?? this.name, isDefault: isDefault);

  Map<String, Object?> toMap() =>
      {'id': id, 'name': name, 'is_default': isDefault ? 1 : 0};

  factory PaymentMethod.fromMap(Map<String, Object?> m) => PaymentMethod(
      id: m['id'] as int?,
      name: m['name'] as String,
      isDefault: m['is_default'] == 1);
}
