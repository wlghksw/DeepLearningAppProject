enum QualityGrade {
  s('S'),
  a('A'),
  b('B'),
  c('C'),
  d('D');

  final String value;
  const QualityGrade(this.value);
}

enum DamageSeverity {
  low,
  medium,
  high;
}

class DamageItem {
  final String type;
  final String location;
  final DamageSeverity severity;
  final String description;

  DamageItem({
    required this.type,
    required this.location,
    required this.severity,
    required this.description,
  });

  factory DamageItem.fromJson(Map<String, dynamic> json) {
    return DamageItem(
      type: json['type'] as String,
      location: json['location'] as String,
      severity: DamageSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => DamageSeverity.low,
      ),
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'location': location,
      'severity': severity.name,
      'description': description,
    };
  }
}

class AIAnalysisResult {
  final QualityGrade grade;
  final List<DamageItem> damageReport;
  final Map<String, String>? visualizedImages; // base64 인코딩된 시각화 이미지 (front, back)

  AIAnalysisResult({
    required this.grade,
    required this.damageReport,
    this.visualizedImages,
  });

  factory AIAnalysisResult.fromJson(Map<String, dynamic> json) {
    return AIAnalysisResult(
      grade: QualityGrade.values.firstWhere(
        (e) => e.value == json['grade'],
        orElse: () => QualityGrade.c,
      ),
      damageReport: (json['damageReport'] as List<dynamic>)
          .map((item) => DamageItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      visualizedImages: json['visualizedImages'] != null
          ? Map<String, String>.from(json['visualizedImages'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'grade': grade.value,
      'damageReport': damageReport.map((item) => item.toJson()).toList(),
      'visualizedImages': visualizedImages,
    };
  }
}

enum ProductStatus {
  draft,
  listed,
  sold;
}

class Product {
  final String id;
  final String sellerName;
  final String modelName;
  final int batteryHealth;
  final int price;
  final String description;
  final List<String> images; // [Front, Back]
  final AIAnalysisResult? analysis;
  final int createdAt;
  final ProductStatus status;

  Product({
    required this.id,
    required this.sellerName,
    required this.modelName,
    required this.batteryHealth,
    required this.price,
    required this.description,
    required this.images,
    this.analysis,
    required this.createdAt,
    required this.status,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      sellerName: json['sellerName'] as String,
      modelName: json['modelName'] as String,
      batteryHealth: json['batteryHealth'] as int,
      price: json['price'] as int,
      description: json['description'] as String,
      images: List<String>.from(json['images'] as List),
      analysis: json['analysis'] != null
          ? AIAnalysisResult.fromJson(json['analysis'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] as int,
      status: ProductStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ProductStatus.draft,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sellerName': sellerName,
      'modelName': modelName,
      'batteryHealth': batteryHealth,
      'price': price,
      'description': description,
      'images': images,
      'analysis': analysis?.toJson(),
      'createdAt': createdAt,
      'status': status.name,
    };
  }
}

class FilterState {
  final QualityGrade? minGrade;
  final int minPrice;
  final int maxPrice;

  FilterState({
    this.minGrade,
    this.minPrice = 0,
    this.maxPrice = 10000000,
  });
}

