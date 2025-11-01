class Address {
  final int? id;
  final int? userId;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String? state;
  final String postalCode;
  final String country;
  final bool isDefault;

  Address({
    this.id,
    this.userId,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    this.state,
    required this.postalCode,
    this.country = 'USA',
    this.isDefault = false,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as int?,
      userId: json['user_id'] ?? json['userId'],
      addressLine1: json['address_line1'] ?? json['addressLine1'],
      addressLine2: json['address_line2'] ?? json['addressLine2'],
      city: json['city'],
      state: json['state'],
      postalCode: json['postal_code'] ?? json['postalCode'],
      country: json['country'] ?? 'USA',
      isDefault: json['is_default'] ?? json['isDefault'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'userId': userId,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
      'isDefault': isDefault,
    };
  }

  String get fullAddress {
    final parts = [
      addressLine1,
      if (addressLine2 != null && addressLine2!.isNotEmpty) addressLine2,
      city,
      if (state != null && state!.isNotEmpty) state,
      postalCode,
      country,
    ];
    return parts.join(', ');
  }
}
