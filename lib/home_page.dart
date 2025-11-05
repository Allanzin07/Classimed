import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'nova_notificacao_page.dart';
import 'minhas_notificacoes_page.dart';
import 'dashboards_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _iniciarNotificacao() {
    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NovaNotificacaoPage()),
      );
    });
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao sair: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Fundo com gradiente
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.6),
                radius: 1.3,
                colors: [Color(0xFFB3E5FC), Colors.white],
                stops: [0.15, 1.0],
              ),
            ),
          ),

          // Conteúdo principal
          SafeArea(
            child: Column(
              children: [
                _AppBarLogo(),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GlowingCTA(
                          pulse: _pulse,
                          isLoading: _isLoading,
                          onTap: _isLoading ? null : _iniciarNotificacao,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          "Iniciar Nova Notificação",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.lightBlue[700],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Card "Minhas Notificações"
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _GlassCard(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    Colors.lightBlueAccent.withOpacity(0.15),
                                child: const Icon(Icons.notifications,
                                    color: Colors.lightBlueAccent),
                              ),
                              title: const Text("Minhas Notificações",
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                "Veja, edite ou apague notificações salvas",
                                style: TextStyle(
                                    color: Colors.black.withOpacity(0.6)),
                              ),
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const MinhasNotificacoesPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Drawer invisível apenas para permitir o botão flutuante abrir o menu
          _ModernDrawer(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
      floatingActionButton: Builder(
        builder: (context) => Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: IconButton(
            icon: const Icon(Icons.menu),
            color: Colors.lightBlue[700],
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: "Menu",
          ),
        ),
      ),
      drawer: _DrawerContent(onLogout: _logout),
      backgroundColor: Colors.transparent,
    );
  }
}

class _AppBarLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(56, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        border: const Border(bottom: BorderSide(color: Color(0x1F000000))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/logo.png', height: 44),
        ],
      ),
    );
  }
}

class _GlowingCTA extends StatelessWidget {
  final AnimationController pulse;
  final bool isLoading;
  final VoidCallback? onTap;

  const _GlowingCTA({
    required this.pulse,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.08).animate(
            CurvedAnimation(parent: pulse, curve: Curves.easeInOut),
          ),
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.lightBlueAccent.withOpacity(0.18),
              boxShadow: [
                BoxShadow(
                  color: Colors.lightBlueAccent.withOpacity(0.35),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          elevation: 6,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Ink(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF81D4FA), Color(0xFF29B6F6)],
                ),
              ),
              child: SizedBox(
                width: 110,
                height: 110,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: isLoading
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.add,
                            key: ValueKey('plus'),
                            size: 48,
                            color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ModernDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _DrawerContent extends StatelessWidget {
  final Future<void> Function() onLogout;

  const _DrawerContent({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Cabeçalho
          Container(
            height: 150,
            width: double.infinity,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB3E5FC), Colors.white],
              ),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                "Menu",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightBlue[800],
                ),
              ),
            ),
          ),

          // 🔹 Minhas Notificações
          ListTile(
            leading: Icon(Icons.notifications, color: Colors.lightBlue[700]),
            title: const Text("Minhas Notificações"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MinhasNotificacoesPage()),
              );
            },
          ),

          ListTile(
            leading: Icon(Icons.insights, color: Colors.lightBlue[700]),
            title: const Text("Dashboards"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardsPage()),
              );
            },
          ),

          // 🔹 Botão Sair
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red[700]),
            title: const Text(
              "Sair",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () async {
              Navigator.pop(context);
              await onLogout();
            },
          ),
        ],
      ),
    );
  }
}
