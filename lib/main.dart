import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'providers/dashboard_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

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
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          return MaterialApp(
            title: 'Materio',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primaryColor: Colors.blue,
              scaffoldBackgroundColor: Color(0xFFE0F7FA),
              appBarTheme: const AppBarTheme(
                color: Colors.blue,
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Color(0xFF87CEEB),
                  statusBarBrightness: Brightness.light,
                  statusBarIconBrightness: Brightness.dark,
                ),
              ),
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            home: auth.isInitialized
                ? (auth.isAuth ? HomeScreen() : LoginScreen())
                : FutureBuilder(
              future: auth.tryAutoLogin(),
              builder: (ctx, snapshot) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading...'),
                      ],
                    ),
                  ),
                );
              },
            ),
            routes: {
              '/login': (ctx) => LoginScreen(),
              '/home': (ctx) => HomeScreen(),
            },
          );
        },
      ),
    );
  }
}