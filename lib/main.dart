import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/providers/cart_provider.dart';
import 'package:kologsoft/providers/cashier_provider.dart';
import 'package:kologsoft/providers/dashboard_provider.dart';
import 'package:kologsoft/providers/theme_provider.dart';
import 'package:kologsoft/providers/routes.dart';
import 'package:kologsoft/providers/SalesProvider.dart';
import 'package:kologsoft/screens/home_dashboard.dart';
import 'package:kologsoft/services/domain_detector.dart';
import 'package:kologsoft/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'package:kologsoft/providers/StockProvider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  final preferences = await SharedPreferences.getInstance();

  // Register Hive adapters
  // Hive.registerAdapter(ItemModelAdapter());

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore offline persistence
  await _enableFirestoreOffline();

  // Initialize storage service

  runApp(MyApp(preferences: preferences));
}

Future<void> _enableFirestoreOffline() async {
  try {
    final firestore = FirebaseFirestore.instance;

    // Enable offline persistence for mobile and desktop platforms
    if (!kIsWeb) {
      await firestore.enableNetwork();

      // Configure persistence settings
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      debugPrint('✅ Firestore offline persistence enabled');
    } else {
      // For web, enable persistence differently
      try {
        firestore.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        debugPrint('✅ Firestore web persistence enabled');
      } catch (e) {
        debugPrint('⚠️ Web persistence may already be enabled: $e');
      }
    }
  } catch (e) {
    debugPrint('⚠️ Firestore persistence error: $e');
    // Persistence can fail if already enabled, which is fine
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.preferences});

  final SharedPreferences preferences;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final datafeed = Datafeed();
            //datafeed.setAppHost(DomainDetector.host);
            // In case setAppHost is called before listeners attach, kick off resolution.
            //Future.microtask(datafeed.resolveTenantFromHost);
            return datafeed;
          },
        ),
        ChangeNotifierProvider(create: (_) => StockProvider()),
        ChangeNotifierProvider(create: (_) => CashierProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(
            preferences: preferences,
            isLightTheme: preferences.getBool('isLightTheme') ?? false,
          ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          initialRoute: Routes.login,
          routes: pages,
          title: 'KologSoft POS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeProvider.themeMode,
        ),
      ),
    );
  }
}
