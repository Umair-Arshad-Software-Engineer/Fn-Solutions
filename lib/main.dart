import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'Adminpages/dashboard.dart';
import 'Auth/login.dart';
import 'Auth/register.dart';
import 'ManagerPages/dashboard.dart';
import 'Workers/dashboard.dart';
import 'firebase_options.dart';
import 'lanprovider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // runApp(const MyApp());
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fn Solutions',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/manager-dashboard': (context) => const ManagerDashboard(),
        '/worker-dashboard': (context) => const WorkerDashboard(),
      },
    );
  }
}