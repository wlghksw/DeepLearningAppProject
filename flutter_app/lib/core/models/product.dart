class ProductSubmission {
  const ProductSubmission({
    required this.deviceName,
    required this.storage,
    required this.batteryHealth,
    required this.imageAngles,
    this.imei,
    this.sellerNote,
  });

  final String deviceName;
  final String storage;
  final double batteryHealth;
  final List<String> imageAngles;
  final String? imei;
  final String? sellerNote;
}



