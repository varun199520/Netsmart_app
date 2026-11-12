// switchport_model.dart

class SwitchPort {
  final String interface;
  final String linkStatus;
  final String lastInput;

  SwitchPort({
    required this.interface,
    required this.linkStatus,
    required this.lastInput,
  });

  factory SwitchPort.fromJson(Map<String, dynamic> json) {
    return SwitchPort(
      interface: json['interface'],
      linkStatus: json['link_status'],
      lastInput: json['last_input'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'interface': interface,
      'link_status': linkStatus,
      'last_input': lastInput,
    };
  }
}

class SwitchData {
  final List<SwitchPort> unusedPorts;
  final int totalPortCount;
  final int totalPortUsed;
  final int totalPortUnused;
  final double usedPortPercentage;
  final double unusedPortPercentage;
  final String switchUptime;
  final String switchName;

  SwitchData({
    required this.unusedPorts,
    required this.totalPortCount,
    required this.totalPortUsed,
    required this.totalPortUnused,
    required this.usedPortPercentage,
    required this.unusedPortPercentage,
    required this.switchUptime,
    required this.switchName,
  });

  factory SwitchData.fromJson(Map<String, dynamic> json) {
    var unusedPortsJson = json['unused_ports'] as List;
    List<SwitchPort> unusedPortsList = unusedPortsJson.map((json) => SwitchPort.fromJson(json)).toList();

    return SwitchData(
      unusedPorts: unusedPortsList,
      totalPortCount: json['total_port_count'],
      totalPortUsed: json['total_port_used'],
      totalPortUnused: json['total_port_unused'],
      usedPortPercentage: json['used_port_percentage'],
      unusedPortPercentage: json['unused_port_percentage'],
      switchUptime: json['switch_uptime'],
      switchName: json['switch'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unused_ports': unusedPorts.map((port) => port.toJson()).toList(),
      'total_port_count': totalPortCount,
      'total_port_used': totalPortUsed,
      'total_port_unused': totalPortUnused,
      'used_port_percentage': usedPortPercentage,
      'unused_port_percentage': unusedPortPercentage,
      'switch_uptime': switchUptime,
      'switch': switchName,
    };
  }
}
