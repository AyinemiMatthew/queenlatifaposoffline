class PaymentMethodModel {
  String id;
  double amount;
  double totalamount;
  double discount;
  String? discountCode;
  String paymentmethod;
  String accountName;
  String accountNumber;
  String reference;
  bool status;
  double change;
  double balance;
  Map<String, dynamic>? transactionIds;
  String? channel;
  String? merchant;

  PaymentMethodModel({
    this.id = '',
    required this.amount,
    this.totalamount = 0.0,
    this.discount = 0.0,
    this.discountCode,
    required this.paymentmethod,
    required this.accountName,
    required this.accountNumber,
    this.reference = '',
    required this.status,
    this.transactionIds,
    this.change = 0.0,
    this.balance = 0.0,
    this.channel,
    this.merchant,
  });

  Map<String, dynamic> toMap() {
    final map = {
      "amount": amount,
      "method": paymentmethod,
      "accountName": accountName,
      "accountNumber": accountNumber,
      "reference": reference,
      "status": status,
      if (totalamount > 0) "totalamount": totalamount,
      if (discount > 0) "discount": discount,
      if (discountCode != null) "discountCode": discountCode,
      if (channel != null) "channel": channel,
      if (merchant != null) "merchant": merchant,
    };

    if (transactionIds != null && transactionIds!.isNotEmpty) {
      map["transactionIds"] = transactionIds!;
    }

    return map;
  }

  factory PaymentMethodModel.fromMap(Map<String, dynamic> map) {
    return PaymentMethodModel(
      amount: (map['amount'] ?? 0).toDouble(),
      totalamount: (map['totalamount'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      discountCode: map['discountCode'],
      paymentmethod: map['method'] ?? '',
      accountName: map['accountName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      reference: map['reference'] ?? '',
      status: map['status'] ?? false,
      channel: map['channel'],
      merchant: map['merchant'],
      transactionIds: map['transactionIds'] != null
          ? Map<String, dynamic>.from(map['transactionIds'] as Map)
          : null,
    );
  }
}
