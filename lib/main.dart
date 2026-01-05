import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/search_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/locale_provider.dart'; // ✅ ADD THIS

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/main_home_screen.dart';
import 'screens/services/service_detail_screen.dart';
import 'screens/wishlist/wishlist_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/news/article_detail_screen.dart';

// ✅ ADD THIS IMPORT
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
        ChangeNotifierProvider(create: (_) => LocaleProvider()), // ✅ ADD THIS
      ],
      child: Consumer<LocaleProvider>( // ✅ WRAP WITH CONSUMER
        builder: (context, localeProvider, child) {
          return MaterialApp(
            title: 'Megatour',
            debugShowCheckedModeBanner: false,

            // ✅ ADD LOCALIZATION
            locale: localeProvider.locale,
            supportedLocales: LocaleProvider.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            theme: ThemeData(
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: Colors.white,
              appBarTheme: const AppBarTheme(
                elevation: 0,
                centerTitle: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),

            home: const SplashScreen(),

            onGenerateRoute: (RouteSettings settings) {
              if (settings.name == '/article-detail') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (_) => ArticleDetailScreen(
                    article: args['article'],
                  ),
                );
              }

              if (settings.name == '/service-detail' ||
                  settings.name == '/hotel-detail' ||
                  settings.name == '/tour-detail') {
                final args = settings.arguments;

                if (args is Map<String, dynamic>) {
                  return MaterialPageRoute(
                    builder: (_) => ServiceDetailScreen(
                      serviceId: args['id'],
                      serviceType: args['type'] ??
                          (settings.name == '/hotel-detail'
                              ? 'hotel'
                              : 'tour'),
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
            },
          );
        },
      ),
    );
  }
}

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
    await context.read<AuthProvider>().initialize();
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.travel_explore, size: 96, color: Colors.blue),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}