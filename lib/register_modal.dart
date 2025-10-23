import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'verify_email_page.dart';

Future<void> showRegisterModal(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _RegisterSheet(),
  );
}

class _RegisterSheet extends StatefulWidget {
  const _RegisterSheet({super.key});

  @override
  State<_RegisterSheet> createState() => _RegisterSheetState();
}

class _RegisterSheetState extends State<_RegisterSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirma = TextEditingController();

  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    _confirma.dispose();
    super.dispose();
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este e-mail já está em uso.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'weak-password':
        return 'Senha fraca. Tente ao menos 6 caracteres.';
      case 'operation-not-allowed':
        return 'Cadastro desabilitado no momento.';
      case 'network-request-failed':
        return 'Falha de rede. Verifique sua conexão.';
      default:
        return 'Não foi possível cadastrar. (${e.code})';
    }
  }

Future<void> _criarConta() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _loading = true;
    _erro = null;
  });

  try {
    // Cria o usuário
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: _email.text.trim(),
      password: _senha.text.trim(),
    );

    final uid = cred.user!.uid;

    // Cria o documento no Firestore
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'nome': _nome.text.trim(),
      'email': _email.text.trim().toLowerCase(),
      'role': 'enfermeiro',
      'ativo': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Aguarda a atualização da autenticação do usuário
    await Future.delayed(const Duration(seconds: 1));

    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;

    // Envia o e-mail de verificação com segurança
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }

    // Fecha o modal atual
    if (!mounted) return;
    Navigator.of(context).pop();

    // Abre a tela de verificação
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerifyEmailPage(email: _email.text.trim()),
      ),
    );

    // Exibe feedback visual
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('E-mail de verificação enviado! Verifique sua caixa de entrada.'),
        duration: Duration(seconds: 4),
      ),
    );
  } on FirebaseAuthException catch (e) {
    setState(() => _erro = _mapFirebaseError(e));
  } catch (e) {
    setState(() => _erro = 'Erro inesperado ao criar a conta.');
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    'Criar conta',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),

                  _buildField(_nome, 'Nome', Icons.person, false, (v) {
                    if (v == null || v.isEmpty) return 'Informe seu nome';
                    return null;
                  }),
                  const SizedBox(height: 12),
                  _buildField(_email, 'E-mail', Icons.email, false, (v) {
                    if (v == null || !v.contains('@')) return 'E-mail inválido';
                    return null;
                  }),
                  const SizedBox(height: 12),
                  _buildField(_senha, 'Senha', Icons.lock, _obscure1, (v) {
                    if (v == null || v.length < 6) {
                      return 'Mínimo de 6 caracteres';
                    }
                    return null;
                  }, toggle: () => setState(() => _obscure1 = !_obscure1)),
                  const SizedBox(height: 12),
                  _buildField(_confirma, 'Confirmar senha', Icons.lock_outline,
                      _obscure2, (v) {
                    if (v != _senha.text) return 'As senhas não conferem';
                    return null;
                  }, toggle: () => setState(() => _obscure2 = !_obscure2)),
                  const SizedBox(height: 12),

                  if (_erro != null)
                    Text(_erro!,
                        style: const TextStyle(color: Colors.red, fontSize: 14)),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _loading ? null : () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : _criarConta,
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Cadastrar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController c,
    String label,
    IconData icon,
    bool obscure,
    FormFieldValidator<String> validator, {
    VoidCallback? toggle,
  }) {
    return TextFormField(
      controller: c,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.lightBlue),
        suffixIcon: toggle != null
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: toggle,
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
