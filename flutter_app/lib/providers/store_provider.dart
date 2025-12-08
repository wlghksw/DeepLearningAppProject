import 'package:flutter/foundation.dart';
import '../models/types.dart';

class StoreProvider with ChangeNotifier {
  List<Product> _products = [];

  List<Product> get products => _products;

  StoreProvider() {
    _initializeData();
  }

  void _initializeData() {
    // 초기 데이터 없음 - 빈 리스트로 시작
    _products = [];
    notifyListeners();
  }

  void addProduct(Product product) {
    // 상품을 리스트 맨 앞에 추가 (최신 상품이 먼저 보이도록)
    _products = [product, ..._products];
    // 상태 변경을 알림 (UI 업데이트)
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


