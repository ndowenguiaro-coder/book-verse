import 'package:flutter/material.dart';
import 'pages/library_home_page.dart';
import 'pages/login_page.dart';
import 'services/auth_service.dart';
import 'core/animations/animation_constants.dart';

// Émulateur Android : 10.0.2.2 pointe vers localhost de la machine hôte.
// Simulateur iOS / Flutter web : utiliser http://127.0.0.1:8000
// Appareil physique : IP locale de votre machine, ex. http://192.168.1.20:8000
const String kBaseUrl = String.fromEnvironment(
  'BOOKVERSE_API_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

void main() {
  runApp(const PdfLibraryApp());
}

class PdfLibraryApp extends StatelessWidget {
  const PdfLibraryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bibliothèque PDF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const _StartupGate(),
    );
  }
}

/// Vérifie s'il existe déjà un jeton de connexion valide et envoie
/// l'utilisateur directement vers la bibliothèque, sinon vers la connexion.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  final _authService = AuthService(baseUrl: kBaseUrl);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authService.isLoggedIn(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: _BookVerseLoader()));
        }
        if (snapshot.data == true) {
          return LibraryHomePage(baseUrl: kBaseUrl, authService: _authService);
        }
        return LoginPage(baseUrl: kBaseUrl, authService: _authService);
      },
    );
  }
}

class _BookVerseLoader extends StatefulWidget { const _BookVerseLoader(); @override State<_BookVerseLoader> createState()=>_BookVerseLoaderState(); }
class _BookVerseLoaderState extends State<_BookVerseLoader> with SingleTickerProviderStateMixin { late final AnimationController c=AnimationController(vsync:this,duration:BookVerseMotion.immersive)..repeat(reverse:true); @override void dispose(){c.dispose();super.dispose();} @override Widget build(BuildContext context)=>AnimatedBuilder(animation:c,builder:(_,__)=>Transform.scale(scale:0.96+c.value*0.08,child:const Icon(Icons.menu_book_rounded,size:64,color:Color(0xFF4F46E5)))); }
