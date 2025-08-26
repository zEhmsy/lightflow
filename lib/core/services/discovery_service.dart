import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';

import '../models/device_info.dart';
import '../services/led_api.dart';

class DiscoveryService {
  static const int _udpPort = 49999;
  static const String _udpPayload = 'LEDCTRL_DISCOVER_V1';
  static final InternetAddress _bcast = InternetAddress('255.255.255.255');
  static final InternetAddress _mcast = InternetAddress('239.255.0.1');

  /// Scoperta dispositivi.
  /// - iOS/Android: 1) mDNS/Bonjour  2) UDP JSON  3) sweep HTTP /24
  Future<List<DeviceInfo>> discover({int listenMs = 900}) async {
    // 1) mDNS / Bonjour
    final viaMdns = await _discoverMdnsBonjour(
      timeout: Duration(milliseconds: 2500),
    );
    if (viaMdns.isNotEmpty) {
      return _confirmHttp(viaMdns);
    }

    // 2) UDP JSON (potrebbe fallire su iOS, non è un problema)
    final viaUdp = await _discoverUdpJson(timeout: Duration(milliseconds: listenMs));
    if (viaUdp.isNotEmpty) {
      return _confirmHttp(viaUdp);
    }

    // 3) Sweep HTTP /24 (leggero e parallelo)
    final viaSweep = await _discoverHttpSweep(
      timeoutPerHostMs: 350,
      concurrency: Platform.isIOS ? 16 : 32,
    );
    return viaSweep;
  }

  /* =========================
   *  1) mDNS / Bonjour
   * ========================= */
  Future<List<DeviceInfo>> _discoverMdnsBonjour({required Duration timeout}) async {
    final client = MDnsClient();
    final out = <DeviceInfo>[];
    StreamSubscription<PtrResourceRecord>? sub;

    try {
      await client.start();

      // raccogli PTR _ledctrl._tcp
      final ptrRecords = <PtrResourceRecord>[];
      sub = client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer('_ledctrl._tcp'),
          )
          .listen(
            (rec) => ptrRecords.add(rec),
            onError: (_) {},
          );

      // attendi un po' di annunci
      await Future.delayed(timeout);

      // smetti di ascoltare, ma NON fermare ancora il client
      await sub.cancel();
      sub = null;

      // ora risolvi SRV e A/AAAA
      for (final ptr in ptrRecords) {
        final srvList = await client
            .lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
            )
            .toList();

        for (final srv in srvList) {
          final host = srv.target; // es. led-AB12CD.local
          final port = srv.port;

          final aList = await client
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(host),
              )
              .toList();

          for (final a in aList) {
            final ip = a.address.address;
            final name = _extractInstanceName(ptr.domainName) ?? host.split('.').first;
            final id = name.startsWith('led-') ? name.substring(4).toUpperCase() : name;

            out.add(DeviceInfo(
              t: 'MDNS',
              id: id,
              name: name,
              ip: ip,
              port: port,
              api: '/state',
              apiv: 1,
              strips: 8,
              reachable: false,
            ));
          }
        }
      }
    } catch (_) {
      // ignora: passeremo agli step successivi
    } finally {
      try { await sub?.cancel(); } catch (_) {}
      // ⚠️ stop() può essere void: NON usare await qui
      try { client.stop(); } catch (_) {}
    }

    return _dedup(out);
  }

  String? _extractInstanceName(String domainName) { // "<istanza>._ledctrl._tcp.local."
    final idx = domainName.indexOf('._ledctrl._tcp');
    if (idx > 0) return domainName.substring(0, idx);
    return null;
  }

  /* =========================
   *  2) UDP JSON (compat)
   * ========================= */
  Future<List<DeviceInfo>> _discoverUdpJson({required Duration timeout}) async {
    final results = <String, DeviceInfo>{};
    RawDatagramSocket? sock;
    StreamSubscription<RawSocketEvent>? sub;

    try {
      try {
        sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _udpPort, reuseAddress: true);
      } catch (_) {
        sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: true);
      }
      sock.broadcastEnabled = true;
      try { sock.joinMulticast(_mcast); } catch (_) {}

      final data = utf8.encode(_udpPayload);
      try { sock.send(data, _bcast, _udpPort); } catch (_) {}
      try { sock.send(data, _mcast, _udpPort); } catch (_) {}

      sub = sock.listen((evt) {
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

      await Future.delayed(timeout);
    } catch (_) {
      // ignora
    } finally {
      try { await sub?.cancel(); } catch (_) {}
      try { sock?.close(); } catch (_) {}
    }

    return results.values.toList();
  }

  /* =========================
   *  3) HTTP /24 sweep
   * ========================= */
  Future<List<DeviceInfo>> _discoverHttpSweep({
    required int timeoutPerHostMs,
    required int concurrency,
  }) async {
    final ifaceIp = await _pickLocalIPv4();
    if (ifaceIp == null) return [];

    final parts = ifaceIp.split('.');
    if (parts.length != 4) return [];
    final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';

    final self = ifaceIp;
    final hosts = <String>[
      for (var i = 1; i <= 254; i++) '$prefix.$i',
    ].where((ip) => ip != self).toList();

    final found = <DeviceInfo>[];
    final pool = _Pool(concurrency);

    await Future.wait(hosts.map((ip) {
      return pool.withResource(() async {
        final base = 'http://$ip:80';
        try {
          final r = await http
              .get(Uri.parse('$base/state'))
              .timeout(Duration(milliseconds: timeoutPerHostMs));

          if (r.statusCode == 200) {
            final j = jsonDecode(r.body);
            if (j is Map && j['used'] is List) {
              final strips = (j['used'] as List).length;
              found.add(DeviceInfo(
                t: 'SWEEP',
                id: ip,
                name: '',
                ip: ip,
                port: 80,
                api: '/state',
                apiv: 1,
                strips: strips,
                reachable: true,
              ));
            }
          }
        } catch (_) {
          // nessuna risposta = non è il nostro device
        }
      });
    }));

    // già reachables; restituisci ordinati
    found.sort((a, b) {
      final ar = a.reachable ? 1 : 0;
      final br = b.reachable ? 1 : 0;
      return br.compareTo(ar);
    });
    return _dedup(found);
  }

  Future<String?> _pickLocalIPv4() async {
    try {
      final ifs = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: true,
      );

      // Preferisci Wi-Fi su iOS (en0). Altrimenti la prima IPv4 “privata”.
      InternetAddress? best;
      for (final i in ifs) {
        for (final a in i.addresses) {
          if (i.name == 'en0' && _isPrivate(a.address)) return a.address;
          best ??= a;
        }
      }
      final candidate = best?.address;
      if (candidate != null && _isPrivate(candidate)) return candidate;
      return candidate;
    } catch (_) {
      return null;
    }
  }

  bool _isPrivate(String ip) {
    return ip.startsWith('10.') ||
        ip.startsWith('192.168.') ||
        ip.startsWith('172.16.') ||
        ip.startsWith('172.17.') ||
        ip.startsWith('172.18.') ||
        ip.startsWith('172.19.') ||
        ip.startsWith('172.20.') ||
        ip.startsWith('172.21.') ||
        ip.startsWith('172.22.') ||
        ip.startsWith('172.23.') ||
        ip.startsWith('172.24.') ||
        ip.startsWith('172.25.') ||
        ip.startsWith('172.26.') ||
        ip.startsWith('172.27.') ||
        ip.startsWith('172.28.') ||
        ip.startsWith('172.29.') ||
        ip.startsWith('172.30.') ||
        ip.startsWith('172.31.');
  }

  /* =========================
   *  Conferma reachability
   * ========================= */
  Future<List<DeviceInfo>> _confirmHttp(List<DeviceInfo> list) async {
    final futures = list.map((d) async {
      try {
        final api = LedApi('http://${d.ip}:${d.port}');
        await api.fetchState(timeout: const Duration(milliseconds: 600));
        return DeviceInfo.fromJson(d.toJson(), reachable: true);
      } catch (_) {
        return d; // lascia reachable=false
      }
    }).toList();

    final confirmed = await Future.wait(futures);
    // ordina con i raggiungibili in alto
    confirmed.sort((a, b) {
      final ar = a.reachable ? 1 : 0;
      final br = b.reachable ? 1 : 0;
      return br.compareTo(ar);
    });
    return _dedup(confirmed);
  }

  List<DeviceInfo> _dedup(List<DeviceInfo> items) {
    final map = <String, DeviceInfo>{};
    for (final d in items) {
      final key = d.id.isNotEmpty ? d.id : d.ip;
      map[key] = d;
    }
    return map.values.toList();
  }
}

/* ---------- mini pool per limitare la concorrenza ---------- */
class _Pool {
  int _avail;
  final _queue = <Completer<void>>[];
  _Pool(this._avail);

  Future<T> withResource<T>(Future<T> Function() task) async {
    if (_avail == 0) {
      final c = Completer<void>();
      _queue.add(c);
      await c.future;
    }
    _avail--;
    try {
      return await task();
    } finally {
      _avail++;
      if (_queue.isNotEmpty) {
        _queue.removeAt(0).complete();
      }
    }
  }
}
