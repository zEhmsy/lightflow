import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/discovery_service.dart';
import '../../core/models/device_info.dart';
import '../../core/services/led_api.dart';
import '../../core/repositories/led_repository.dart';
import '../../core/storage/devices_store.dart';
import '../controller/controller_page.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});
  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final _svc = DiscoveryService();
  final _store = DevicesStore();
  bool _loading = true;
  List<DeviceInfo> _found = const [];

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    try {
      final res = await _svc.discover(listenMs: 900);
      res.sort((a,b) => (b.reachable ? 1 : 0).compareTo(a.reachable ? 1 : 0));
      setState(() => _found = res);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect(DeviceInfo d) async {
    final base = 'http://${d.ip}:${d.port}';
    await _store.upsert(d);
    if (!mounted) return;
    final repo = LedRepository(LedApi(base));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => Provider.value(
          value: repo,
          child: ControllerPage(baseUrl: base),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scansione dispositivi')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _found.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Nessun dispositivo trovato'),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _run,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Riprova'),
                        )
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _found.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final d = _found[i];
                      return Card(
                        child: ListTile(
                          title: Text(d.name.isNotEmpty ? d.name : d.id),
                          subtitle: Text('${d.ip}:${d.port}  •  id: ${d.id}  •  strips: ${d.strips}'),
                          trailing: d.reachable
                              ? const Icon(Icons.check_circle, color: Colors.lightGreen)
                              : const Icon(Icons.help_outline),
                          onTap: () => _connect(d),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _run,
        icon: const Icon(Icons.refresh),
        label: const Text('Scansiona'),
      ),
    );
  }
}
