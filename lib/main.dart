import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() {
  runApp(const KestrelApp());
}

class KestrelApp extends StatelessWidget {
  const KestrelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kestrel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00C853),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ConnectionTest(),
    );
  }
}

class ConnectionTest extends StatefulWidget {
  const ConnectionTest({super.key});

  @override
  State<ConnectionTest> createState() => _ConnectionTestState();
}

class _ConnectionTestState extends State<ConnectionTest> {
  String _status = 'Verbinde...';

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    try {
      final data = await ApiService.getDashboard();
      setState(() {
        _status = '✓ Verbunden\nBudget: €${data['budget']['total_eur']}';
      });
    } catch (e) {
      setState(() {
        _status = '✗ Fehler: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          _status,
          style: const TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}