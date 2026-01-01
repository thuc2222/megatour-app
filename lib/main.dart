import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/search_provider.dart';
import 'providers/wishlist_provider.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/main_home_screen.dart';
import 'screens/services/service_detail_screen.dart';
import 'screens/wishlist/wishlist_screen.dart';
import 'screens/cart/cart_screen.dart';
//import 'screens/booking/booking_history_screen.dart';
//import 'screens/profile/edit_profile_screen.dart';


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

        /// App entry
        home: const SplashScreen(),

        /// Dynamic service detail routing
        onGenerateRoute: (settings) {
          if (settings.name == '/service-detail' ||
              settings.name == '/hotel-detail' ||
              settings.name == '/tour-detail') {
            final args = settings.arguments;

            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => ServiceDetailScreen(
                  serviceId: args['id'],
                  serviceType: args['type'] ??
                      (settings.name == '/hotel-detail' ? 'hotel' : 'tour'),
                ),
              );
            }

            if (args is int) {
              return MaterialPageRoute(
                builder: (_) => ServiceDetailScreen(
                  serviceId: args,
                  serviceType:
                      settings.name == '/hotel-detail' ? 'hotel' : 'tour',
                ),
              );
            }
          }
          return null;
        },

        routes: {
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/home': (_) => const MainHomeScreen(),
          '/wishlist': (_) => const WishlistScreen(),
          '/cart': (_) => const CartScreen(),
          //'/booking-history': (_) => const BookingHistoryScreen(),
          //'/edit-profile': (_) => const EditProfileScreen(),
        },
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Splash Screen (Guest-First, No Login Gate)
/// ---------------------------------------------------------------------------

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    // Restore auth silently (guest or logged-in)
    await context.read<AuthProvider>().initialize();

    // Splash delay (branding / perceived performance)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Always go to Home (guest-first)
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
                    letterSpacing: 1.5,
                    color: Colors.blue,
                  ),
            ),
            const SizedBox(height: 48),

            /// Subtle animation (no controller, no risk)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOut,
              builder: (_, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: const CircularProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}
