import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/led_api.dart';
import '../../core/repositories/led_repository.dart';
import '../../core/storage/settings_store.dart';
import '../controller/controller_page.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _ipCtrl = TextEditingController();
  bool _loading = false;
  final store = SettingsStore();

  @override
  void initState() {
    super.initState();
    store.getLastBase().then((v) => setState(() => _ipCtrl.text = v ?? ''));
  }

  String _normalize(String input) {
    final s = input.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return 'http://$s';
  }

  Future<void> _connect() async {
    final base = _normalize(_ipCtrl.text);
    if (base.isEmpty) {
      _snack('Inserisci un indirizzo valido (es. 192.168.1.120:80).');
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = LedRepository(LedApi(base));
      await repo.load(); // ping /state
      await store.setLastBase(base);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => Provider.value(
            value: repo,
            child: ControllerPage(baseUrl: base),
          ),
        ),
      );
    } catch (e) {
      _snack('Connessione fallita: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Controller 8 Strisce LED')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Inserisci IP o IP:porta del microcontrollore'),
                const SizedBox(height: 12),
                TextField(
                  controller: _ipCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Indirizzo (es. 192.168.1.120:80)',
                    prefixIcon: Icon(Icons.link),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _connect,
                    icon: _loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.power_settings_new),
                    label: const Text('Connetti'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}