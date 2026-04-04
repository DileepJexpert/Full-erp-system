class FeatureFlags {
  final bool enableDispatch;
  final bool enableReconciliation;
  final bool enableWastageMargin;
  final bool enableBatchExpiry;
  final bool enableAppointments;
  final bool enableCreditLedger;
  final bool enableWeightBilling;
  final bool enableCommissions;
  final bool enableMemberships;
  final bool enableBarcode;
  final bool enableDelivery;
  final bool enableAggregators;
  final bool enableAnomaly;
  final bool enablePerformance;
  final bool enableWeather;
  final bool enableLoyalty;

  const FeatureFlags({
    this.enableDispatch = false,
    this.enableReconciliation = false,
    this.enableWastageMargin = false,
    this.enableBatchExpiry = false,
    this.enableAppointments = false,
    this.enableCreditLedger = false,
    this.enableWeightBilling = false,
    this.enableCommissions = false,
    this.enableMemberships = false,
    this.enableBarcode = false,
    this.enableDelivery = false,
    this.enableAggregators = false,
    this.enableAnomaly = true,
    this.enablePerformance = true,
    this.enableWeather = false,
    this.enableLoyalty = false,
  });

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    return FeatureFlags(
      enableDispatch: json['enableDispatch'] ?? false,
      enableReconciliation: json['enableReconciliation'] ?? false,
      enableWastageMargin: json['enableWastageMargin'] ?? false,
      enableBatchExpiry: json['enableBatchExpiry'] ?? false,
      enableAppointments: json['enableAppointments'] ?? false,
      enableCreditLedger: json['enableCreditLedger'] ?? false,
      enableWeightBilling: json['enableWeightBilling'] ?? false,
      enableCommissions: json['enableCommissions'] ?? false,
      enableMemberships: json['enableMemberships'] ?? false,
      enableBarcode: json['enableBarcode'] ?? false,
      enableDelivery: json['enableDelivery'] ?? false,
      enableAggregators: json['enableAggregators'] ?? false,
      enableAnomaly: json['enableAnomaly'] ?? true,
      enablePerformance: json['enablePerformance'] ?? true,
      enableWeather: json['enableWeather'] ?? false,
      enableLoyalty: json['enableLoyalty'] ?? false,
    );
  }
}
