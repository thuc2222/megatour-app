// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/search_provider.dart';
import 'providers/wishlist_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/main_home_screen.dart';
import 'screens/services/service_list_screen.dart';
import 'screens/services/service_detail_screen.dart';
import 'screens/wishlist/wishlist_screen.dart';
import 'screens/cart/cart_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
      ],
      child: MaterialApp(
        title: 'Megatour',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
          ),
        ),
        home: const SplashScreen(),
        onGenerateRoute: (settings) {
          // Fix: Handle the specific name being called ('/hotel-detail')
          if (settings.name == '/service-detail' || settings.name == '/hotel-detail' || settings.name == '/tour-detail') {
            
            // Safety Check: If arguments are just an int (like the error shows), wrap it
            final dynamic args = settings.arguments;
            
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (context) => ServiceDetailScreen(
                  serviceId: args['id'],
                  serviceType: args['type'] ?? (settings.name == '/hotel-detail' ? 'hotel' : 'tour'),
                ),
              );
            } 
            
            // Fallback if only an ID was passed (matches your error log: RouteSettings("/hotel-detail", 1))
            if (args is int) {
              return MaterialPageRoute(
                builder: (context) => ServiceDetailScreen(
                  serviceId: args,
                  serviceType: settings.name == '/hotel-detail' ? 'hotel' : 'tour',
                ),
              );
            }
          }
          return null;
        },
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const MainHomeScreen(),
          '/wishlist': (context) => const WishlistScreen(),
          '/cart': (context) => const CartScreen(),
        },
      ),
    );
  }
}

// Splash Screen - Check authentication status
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
  final authProvider = context.read<AuthProvider>();

  // Initialize auth silently (restore token if exists)
  await authProvider.initialize();

  // Optional splash delay
  await Future.delayed(const Duration(seconds: 2));

  if (!mounted) return;

  // ALWAYS go to home
  Navigator.of(context).pushReplacementNamed('/home');
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.travel_explore,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              'Megatour',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}