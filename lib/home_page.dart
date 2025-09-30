import 'package:flutter/material.dart';
import 'nova_notificacao_page.dart';
import 'minhas_notificacoes_page.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = false;

  void _iniciarNotificacao() {
    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _isLoading = false;
      });
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NovaNotificacaoPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.lightBlue[700]),
        title: Image.asset(
          'assets/logo.png',
          height: 50,
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.lightBlue[100],
              ),
              child: Center(
                child: Text(
                  "Menu",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.lightBlue[700],
                  ),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.notifications, color: Colors.lightBlue[700]),
              title: const Text("Minhas Notificações"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const MinhasNotificacoesPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            
            ElevatedButton(
              onPressed: _isLoading ? null : _iniciarNotificacao,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(32),
                elevation: 6,
              ),
              child: Icon(
                Icons.add,
                size: 48,
                color: Colors.lightBlue[700],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              "Iniciar Nova Notificação",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.lightBlue[700],
              ),
            ),

            const SizedBox(height: 24),

            if (_isLoading)
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
          ],
        ),
      ),
    );
  }
}
