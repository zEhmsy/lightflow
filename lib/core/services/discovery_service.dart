import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/device_info.dart';
import '../services/led_api.dart';

class DiscoveryService {
  static const int port = 49999;
  static const String payload = 'LEDCTRL_DISCOVER_V1';
  static final InternetAddress bcast = InternetAddress('255.255.255.255');
  static final InternetAddress mcast = InternetAddress('239.255.0.1');

  Future<List<DeviceInfo>> discover({int listenMs = 900}) async {
    final results = <String, DeviceInfo>{};

    RawDatagramSocket? sock;
    try {
      sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: true);
    } catch (_) {
      // fallback: porta random
      sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: true);
    }
    sock.broadcastEnabled = true;

    // prova a join multicast (se negato su iOS/Android, ignora)
    try { sock.joinMulticast(mcast); } catch (_) {}

    // invia broadcast
    final data = utf8.encode(payload);
    try { sock.send(data, bcast, port); } catch (_) {}
    // invia multicast
    try { sock.send(data, mcast, port); } catch (_) {}

    final completer = Completer<List<DeviceInfo>>();
    final sub = sock.listen((evt) {
      if (evt == RawSocketEvent.read) {
        final dg = sock!.receive();
        if (dg == null) return;
        try {
          final txt = utf8.decode(dg.data);
          final j = jsonDecode(txt);
          if (j is Map<String, dynamic>) {
            final d = DeviceInfo.fromJson(j);
            if (d.ip.isNotEmpty) {
              results[d.id.isNotEmpty ? d.id : d.ip] = d;
            }
          }
        } catch (_) {}
      }
    });

    // attesa
    await Future.delayed(Duration(milliseconds: listenMs));
    await sub.cancel();
    sock.close();

    // conferma HTTP /state in parallelo
    final out = results.values.toList();
    final futures = out.map((d) async {
      try {
        final api = LedApi('http://${d.ip}:${d.port}');
        await api.fetchState(timeout: const Duration(milliseconds: 600));
        return DeviceInfo.fromJson(d.toJson()..['reachable']=true, reachable: true);
      } catch (_) {
        return d; // reachable=false
      }
    }).toList();

    return await Future.wait(futures);
  }
}
