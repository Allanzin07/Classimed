import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_modal.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final AnimationController _ctrl;
  bool _loading = false;
  bool _obscure = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _msgErroFirebase(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'user-disabled':
        return 'Usuário desabilitado.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente em instantes.';
      case 'network-request-failed':
        return 'Falha de rede. Verifique sua conexão.';
      default:
        return 'Falha ao autenticar. (${e.code})';
    }
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _erro = null;
    });

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = cred.user;

      if (user != null && !user.emailVerified) {
        // Se o e-mail ainda não foi verificado
        await FirebaseAuth.instance.signOut();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verifique seu e-mail antes de entrar.'),
            duration: Duration(seconds: 3),
          ),
        );

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '/verify-email',
          arguments: _emailController.text.trim(), // passa o e-mail
        );
        return;
      }

      // Se já está verificado
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login realizado com sucesso!")),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      setState(() => _erro = _msgErroFirebase(e));
    } catch (_) {
      setState(() => _erro = 'Ocorreu um erro inesperado ao autenticar.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRegister() async {
    await showRegisterModal(context);
  }

  Future<void> _onResetSenha() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _erro = 'Informe o e-mail para recuperar a senha.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail de redefinição enviado.')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _erro = _msgErroFirebase(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          final wave = math.sin(t * math.pi);
          final centerY = -0.4 + (wave * 0.08);
          final radius = 1.15 + (wave * 0.12);
          final inner =
              Color.lerp(const Color(0xFFB3E5FC), const Color(0xFFACE7FF), wave)!;

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, centerY),
                radius: radius,
                colors: [inner, Colors.white],
                stops: const [0.2, 1.0],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 350),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/logo-robo-nome.png',
                            width: 140, height: 140),
                        const SizedBox(height: 32),

                        // E-mail
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Informe o e-mail';
                            if (!v.contains('@')) return 'E-mail inválido';
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: "E-mail",
                            prefixIcon: const Icon(Icons.email,
                                color: Colors.lightBlue),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Senha
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Informe a senha'
                              : null,
                          decoration: InputDecoration(
                            labelText: "Senha",
                            prefixIcon:
                                const Icon(Icons.lock, color: Colors.lightBlue),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : _onResetSenha,
                            child: const Text('Esqueci a senha'),
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (_erro != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(_erro!,
                                style: const TextStyle(color: Colors.red)),
                          ),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _onLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightBlueAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 3,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text("Entrar",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _loading ? null : _onRegister,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(
                                  color: Colors.lightBlueAccent, width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              "Registrar-se",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.lightBlueAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
