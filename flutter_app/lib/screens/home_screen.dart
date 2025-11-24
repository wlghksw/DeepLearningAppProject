import 'package:flutter/material.dart';
import 'package:flutter_app/screens/dashboard/dashboard_screen.dart';
import 'package:flutter_app/screens/marketplace/marketplace_screen.dart';
import 'package:flutter_app/screens/submission/submission_screen.dart';
import 'package:flutter_app/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    DashboardScreen(),
    SubmissionScreen(),
    MarketplaceScreen(),
  ];

  final List<String> _titles = const [
    'AI 대시보드',
    '검수 요청',
    '보증 마켓',
  ];

  final List<String> _subtitles = const [
    '실시간 검수 현황과 요약을 확인하세요.',
    '기기 정보를 입력하고 필수 이미지를 업로드해요.',
    '검수를 마친 기기를 등급별로 살펴보세요.',
  ];

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titles[_currentIndex]),
            const SizedBox(height: 4),
            Text(
              _subtitles[_currentIndex],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.neutral.withValues(alpha: 0.6), fontSize: 13),
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _tabs[_currentIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '대시보드',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: '검수',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: '마켓',
          ),
        ],
      ),
    );
  }
}
