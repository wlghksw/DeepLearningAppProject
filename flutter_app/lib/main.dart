import 'package:flutter/material.dart';
import 'package:flutter_app/screens/inspection_screen.dart';
import 'package:flutter_app/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 스마트폰 상태 검사',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const InspectionScreen(),
    );
  }
}
