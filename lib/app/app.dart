import 'package:flutter/material.dart';
import '../core/navigator_key.dart';
import '../core/theme.dart';
import '../screens/dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey:           navigatorKey,
      title:                  'LeadMantraCRM',
      debugShowCheckedModeBanner: false,
      theme:                  AppTheme.light(),
      routes: {
        '/login':     (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
      },
      home:                   const _Splash(),
    );
  }
}

// Loads persisted session then routes to Dashboard or Login.
class _Splash extends StatefulWidget {
  const _Splash();

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    await AuthService.instance.loadSession();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AuthService.instance.isLoggedIn
            ? const DashboardScreen()
            : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/images/logo_1 1.png',
          width: 200,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, st) => const Text(
            'LeadMantraCRM',
            style: TextStyle(
              fontSize:   22,
              fontWeight: FontWeight.w700,
              color:      Color(0xFF1A237E),
            ),
          ),
        ),
      ),
    );
  }
}
