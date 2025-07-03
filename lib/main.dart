// lib/main.dart
import 'package:bussus_crm/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'providers/dashboard_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_text_styles.dart';
import 'theme/app_dimensions.dart';
import 'providers/tabs_provider.dart';
import 'screens/webview_screen.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF73BEF7),
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => TabsProvider()),
        ChangeNotifierProvider(create: (_) => AppsProvider()),

      ],
      child: Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          return MaterialApp(
            title: 'Materio',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: auth.isInitialized
                ? (auth.isAuth ? MainLayout() : LoginScreen())
                : FutureBuilder(
                    future: auth.tryAutoLogin(),
                    builder: (ctx, snapshot) {
                      return Scaffold(
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: AppDimensions.spacingL),
                              Text('Loading...', style: AppTextStyles.bodyMedium),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            routes: {
              '/login': (ctx) => LoginScreen(),
              '/home': (ctx) => MainLayout(initialIndex: 0),
              '/webview': (ctx) => const InAppWebViewScreen(),
            },
          );
        },
      ),
    );
  }
}