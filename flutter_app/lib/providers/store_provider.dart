import 'package:flutter/foundation.dart';
import '../models/types.dart';

class StoreProvider with ChangeNotifier {
  List<Product> _products = [];

  List<Product> get products => _products;

  StoreProvider() {
    _initializeData();
  }

  void _initializeData() {
    _products = [
      Product(
        id: '1',
        sellerName: '김철수',
        modelName: 'iPhone 14 Pro',
        batteryHealth: 92,
        price: 950000,
        description:
            '전반적으로 상태가 매우 우수하나 측면에 미세한 생활 기스가 존재합니다. 케이스 씌우고 사용하여 깨끗합니다.',
        images: [
          'https://picsum.photos/400/600',
          'https://picsum.photos/400/602'
        ],
        status: ProductStatus.listed,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        analysis: AIAnalysisResult(
          grade: QualityGrade.a,
          damageReport: [
            DamageItem(
              type: 'Scratch',
              location: 'Side Bezel',
              severity: DamageSeverity.low,
              description: '충전 포트 근처 미세 스크래치',
            )
          ],
        ),
      ),
      Product(
        id: '2',
        sellerName: '이영희',
        modelName: 'Galaxy S23 Ultra',
        batteryHealth: 88,
        price: 1050000,
        description: '선물 받고 거의 사용하지 않아 신품급 상태입니다. 박스 풀셋입니다.',
        images: [
          'https://picsum.photos/400/603',
          'https://picsum.photos/400/605'
        ],
        status: ProductStatus.listed,
        createdAt: DateTime.now().millisecondsSinceEpoch - 100000,
        analysis: AIAnalysisResult(
          grade: QualityGrade.s,
          damageReport: [],
        ),
      ),
    ];
    notifyListeners();
  }

  void addProduct(Product product) {
    _products = [product, ..._products];
    notifyListeners();
  }

  Product? getProduct(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
}

