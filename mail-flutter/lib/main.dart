import 'package:flutter/material.dart';
import 'session.dart';
import 'ui/theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MailApp());
}

class MailApp extends StatefulWidget {
  const MailApp({super.key});
  @override
  State<MailApp> createState() => _MailAppState();
}

class _MailAppState extends State<MailApp> {
  @override
  void initState() {
    super.initState();
    session.init();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Mail',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: AnimatedBuilder(
        animation: session,
        builder: (c, _) {
          if (!session.ready) {
            return const PageBackground(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          return session.loggedIn
              ? const HomeScreen()
              : const LoginScreen();
        },
      ),
    );
  }
}
