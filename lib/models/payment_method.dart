class PaymentMethod {
  final int id;
  final int userId;
  final String stripePaymentMethodId;
  final String? cardBrand;
  final String? cardLast4;
  final int? cardExpMonth;
  final int? cardExpYear;
  final String? cardHolderName;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PaymentMethod({
    required this.id,
    required this.userId,
    required this.stripePaymentMethodId,
    this.cardBrand,
    this.cardLast4,
    this.cardExpMonth,
    this.cardExpYear,
    this.cardHolderName,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      stripePaymentMethodId: json['stripe_payment_method_id'] as String,
      cardBrand: json['card_brand'] as String?,
      cardLast4: json['card_last4'] as String?,
      cardExpMonth: json['card_exp_month'] as int?,
      cardExpYear: json['card_exp_year'] as int?,
      cardHolderName: json['card_holder_name'] as String?,
      isDefault: json['is_default'] == 1 || json['is_default'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'stripe_payment_method_id': stripePaymentMethodId,
      'card_brand': cardBrand,
      'card_last4': cardLast4,
      'card_exp_month': cardExpMonth,
      'card_exp_year': cardExpYear,
      'is_default': isDefault,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get displayName {
    if (cardBrand != null && cardLast4 != null) {
      return '${cardBrand!.toUpperCase()} •••• $cardLast4';
    }
    return 'Card •••• $cardLast4';
  }

  String get expiryDate {
    if (cardExpMonth != null && cardExpYear != null) {
      return '${cardExpMonth.toString().padLeft(2, '0')}/${cardExpYear.toString().substring(2)}';
    }
    return '';
  }
}

