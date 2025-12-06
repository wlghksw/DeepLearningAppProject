import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'providers/store_provider.dart';
import 'pages/marketplace_page.dart';
import 'pages/product_detail_page.dart';
import 'pages/register_page.dart';
import 'widgets/navbar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const ScaffoldWithNavbar(
            child: MarketplacePage(),
          ),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const ScaffoldWithNavbar(
            child: RegisterPage(),
          ),
        ),
        GoRoute(
          path: '/product/:id',
          builder: (context, state) {
            final productId = state.pathParameters['id']!;
            return ScaffoldWithNavbar(
              child: ProductDetailPage(productId: productId),
            );
          },
        ),
      ],
    );

    return ChangeNotifierProvider(
      create: (_) => StoreProvider(),
      child: MaterialApp.router(
        title: 'SmartGrade AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF97316),
            brightness: Brightness.light,
          ),
        ),
        routerConfig: router,
        builder: (context, child) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFDFCFC), // stone-50
              ),
              child: Stack(
                children: [
                  // Ambient Background Effects
                  Positioned.fill(
                    child: Stack(
                      children: [
                        Positioned(
                          top: -MediaQuery.of(context).size.height * 0.1,
                          left: -MediaQuery.of(context).size.width * 0.1,
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.5,
                            height: MediaQuery.of(context).size.width * 0.5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFED7AA).withOpacity(0.4),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFED7AA)
                                      .withOpacity(0.6),
                                  blurRadius: 120,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: MediaQuery.of(context).size.height * 0.2,
                          right: -MediaQuery.of(context).size.width * 0.1,
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.4,
                            height: MediaQuery.of(context).size.width * 0.4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2).withOpacity(0.4),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFF1F2)
                                      .withOpacity(0.6),
                                  blurRadius: 100,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -MediaQuery.of(context).size.height * 0.1,
                          left: MediaQuery.of(context).size.width * 0.2,
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.6,
                            height: MediaQuery.of(context).size.width * 0.6,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAF9).withOpacity(0.6),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFAFAF9)
                                      .withOpacity(0.5),
                                  blurRadius: 120,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Column(
                    children: [
                      Expanded(
                        child: child ?? const SizedBox(),
                      ),
                      // Footer
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade100),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '© 2024 SmartGrade AI',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Premium Quality Assessment System for Used Devices',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ScaffoldWithNavbar extends StatelessWidget {
  final Widget child;

  const ScaffoldWithNavbar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Navbar(),
        Expanded(child: child),
      ],
    );
  }
}
