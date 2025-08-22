class DeviceInfo {
  final String t;
  final String id;
  final String name;
  final String ip;
  final int port;
  final String api;
  final int apiv;
  final int strips;
  final bool reachable; // risultato della GET /state


  const DeviceInfo({
    required this.t,
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.api,
    required this.apiv,
    required this.strips,
    required this.reachable,
  });


  factory DeviceInfo.fromJson(Map<String, dynamic> j, {bool reachable = false}) {
    return DeviceInfo(
      t: j['t']?.toString() ?? '',
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      ip: j['ip']?.toString() ?? '',
      port: (j['port'] as num?)?.toInt() ?? 80,
      api: j['api']?.toString() ?? '/state',
      apiv: (j['apiv'] as num?)?.toInt() ?? 1,
      strips: (j['strips'] as num?)?.toInt() ?? 8,
      reachable: reachable,
    );
  }


  Map<String, dynamic> toJson() => {
    't': t, 'id': id, 'name': name, 'ip': ip, 'port': port,
    'api': api, 'apiv': apiv, 'strips': strips, 'reachable': reachable,
  };
}
