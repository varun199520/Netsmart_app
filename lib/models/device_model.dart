class Device {
  final String ip;
  final String mac;
  final String deviceName;
  final DateTime lastSeen;
  final bool recent;
  final String vlan;
  final String port;
  final String switchName;

  Device({
    required this.ip,
    required this.mac,
    required this.deviceName,
    required this.lastSeen,
    this.recent = false,
    required this.vlan,
    required this.port,
    required this.switchName,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      ip: json['ip'] ?? 'Unknown IP',
      mac: json['mac'] ?? 'Unknown MAC',
      deviceName: json['deviceName'] ?? json['device_name'] ?? 'Unknown Device Name',
      lastSeen: DateTime.tryParse(json['lastSeen'] ?? json['last_seen']) ?? DateTime.now(),
      recent: json['recent'] ?? false,
      vlan: json['vlan'] ?? 'Unknown VLAN',
      port: json['port'] ?? 'Unknown Port',
      switchName: json['switchName'] ?? json['switch_name'] ?? 'Unknown Switch',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ip': ip,
      'mac': mac,
      'device_name': deviceName,
      'last_seen': lastSeen.toIso8601String(),
      'recent': recent,
      'vlan': vlan,
      'port': port,
      'switch_name': switchName,
    };
  }

  @override
  String toString() {
    return 'Device(ip: $ip, mac: $mac, deviceName: $deviceName, lastSeen: $lastSeen, recent: $recent, vlan: $vlan, port: $port, switchName: $switchName)';
  }
}
