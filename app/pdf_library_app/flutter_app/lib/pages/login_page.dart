import 'package:flutter/material.dart';
import '../core/animations/animation_constants.dart';
import '../services/auth_service.dart';
import 'library_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.baseUrl, required this.authService});
  final String baseUrl;
  final AuthService authService;
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _nameController = TextEditingController();
  bool _register = false, _submitting = false, _showPassword = false;
  String? _error;

  String? _emailValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) return 'Adresse e-mail invalide';
    return null;
  }
  String? _passwordValidator(String? v) => (v == null || v.length < 8) ? 'Au moins 8 caractères' : null;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final email = _emailController.text.trim().toLowerCase();
      if (_register) {
        await widget.authService.register(email: email, password: _passwordController.text, displayName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim());
      } else {
        await widget.authService.login(email: email, password: _passwordController.text);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LibraryHomePage(baseUrl: widget.baseUrl, authService: widget.authService)));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally { if (mounted) setState(() => _submitting = false); }
  }

  @override void dispose(){_emailController.dispose();_passwordController.dispose();_confirmController.dispose();_nameController.dispose();super.dispose();}

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: AnimatedContainer(
        duration: BookVerseMotion.content, curve: BookVerseMotion.standardCurve,
        padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 30, offset: const Offset(0, 16))]),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.menu_book_rounded, size: 58, color: Color(0xFF4F46E5)),
          const SizedBox(height: 12),
          AnimatedSwitcher(duration: BookVerseMotion.standard, child: Text(_register ? 'Créer votre bibliothèque' : 'Bienvenue dans BookVerse', key: ValueKey(_register), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
          const SizedBox(height: 8),
          Text(_register ? 'Un compte pour synchroniser vos lectures.' : 'Retrouvez vos livres et votre progression.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          if (_register) ...[TextFormField(controller: _nameController, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText:'Nom affiché (optionnel)', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())), const SizedBox(height: 12)],
          TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText:'E-mail', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()), validator: _emailValidator),
          const SizedBox(height: 12),
          TextFormField(controller: _passwordController, obscureText: !_showPassword, textInputAction: _register ? TextInputAction.next : TextInputAction.done, autofillHints: const [AutofillHints.password], decoration: InputDecoration(labelText:'Mot de passe', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed:()=>setState(()=>_showPassword=!_showPassword), icon: Icon(_showPassword?Icons.visibility_off:Icons.visibility)), border: const OutlineInputBorder()), validator: _passwordValidator),
          if (_register) ...[const SizedBox(height: 12), TextFormField(controller: _confirmController, obscureText: !_showPassword, decoration: const InputDecoration(labelText:'Confirmer le mot de passe', prefixIcon: Icon(Icons.verified_user_outlined), border: OutlineInputBorder()), validator:(v)=>v!=_passwordController.text?'Les mots de passe ne correspondent pas.':null)],
          if (_error != null) ...[const SizedBox(height: 12), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12)), child: Text(_error!, style: const TextStyle(color: Color(0xFFBE123C))))],
          const SizedBox(height: 20),
          FilledButton(onPressed:_submitting?null:_submit, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical:15), backgroundColor: const Color(0xFF4F46E5)), child:_submitting?const SizedBox(height:22,width:22,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):Text(_register?'Créer mon compte':'Se connecter')),
          const SizedBox(height: 8),
          TextButton(onPressed:_submitting?null:()=>setState((){_register=!_register;_error=null;}), child:Text(_register?'J’ai déjà un compte':'Créer un compte')),
        ])),
      ))))),
    );
  }
}
