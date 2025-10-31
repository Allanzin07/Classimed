import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Import das suas pages
import 'splash_screen.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'register_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase antes de rodar o app
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ClassiMedApp());
}

class ClassiMedApp extends StatelessWidget {
  const ClassiMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ClassiMed',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Tela inicial (Splash verifica login depois)
      initialRoute: '/',

      // Rotas nomeadas do app
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
      },

      // 🔹 Controle automático de rota inicial com base no login
      // (Opcional: se quiser pular a splash)
      // home: FirebaseAuth.instance.currentUser == null
      //     ? const LoginPage()
      //     : const HomePage(),
    );
  }
}
