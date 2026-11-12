import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models/device_model.dart';
import 'models/switchport_model.dart';

class ApiService {
  final String baseURL = 'https://netsmart.stanfordmed.org';
//device by mac/ip

  Future<Device> fetchDeviceByIPOrMac(String ipOrMac) async {
//https://dev-netsmart.stanfordmed.org/deviceTracker/api/wired-lookup?address=10.250.79.233
    print(ipOrMac);
    final response = await http.get(
        Uri.parse('$baseURL/deviceTracker/api/wired-lookup?address=$ipOrMac'));

    if (response.statusCode == 200) {
      print(json.decode(response.body));
      if (json.decode(response.body)['success'] == false) {
        throw Exception('Failed to load device data:\n\n' + response.body);
      }
      print('step 0 succeeded');
      Device device = Device.fromJson(json.decode(response.body)["response"]);
      print('step 1 succeeded');
      print(device);
      return device;
    } else {
      print(response.body + "error 404");
      throw Exception('Failed to load device data:\n\n' + response.body);
    }
  }

//device by switch
  Future<List<Device>> fetchDevicesBySwitchID(String switchid) async {
    try {
      final response = await http.get(Uri.parse(baseURL +
          '/deviceTracker/api/switch-wired-lookup?switch=' +
          switchid));
      if (json.decode(response.body)['success'] == false) {
        throw Exception('Failed to load device data:\n\n' + response.body);
      }

      if (response.statusCode == 200) {
        Map<String, dynamic> json = jsonDecode(response.body);
        List<dynamic> deviceListJson = json['response']['ip_list'];
        print(deviceListJson);
        List<Device> devices =
            deviceListJson.map((json) => Device.fromJson(json)).toList();
        print(devices);
        return devices;
      } else {
        throw Exception('Failed to load device data:\n\n' + response.body);
      }
    } catch (e) {
      throw Exception('Failed to load device data' + e.toString());
    }
  }

  List<Device> _getFallbackDevices() {
    List<Map<String, dynamic>> fallbackJson = [
      {
        "ip": "192.168.1.1",
        "mac": "00:11:22:33:44:55",
        "device_name": "Fallback Device 1",
        "last_seen": "2024-01-01T00:00:00.000Z",
        "recent": true,
        "vlan": "100",
        "port": "GigabitEthernet1/1",
        "switch_name": "Fallback Switch 1"
      },
      {
        "ip": "192.168.1.2",
        "mac": "00:11:22:33:44:56",
        "device_name": "Fallback Device 2",
        "last_seen": "2024-01-02T00:00:00.000Z",
        "recent": true,
        "vlan": "200",
        "port": "GigabitEthernet1/2",
        "switch_name": "Fallback Switch 2"
      },
    ];
    return fallbackJson.map((json) => Device.fromJson(json)).toList();
  }

  Future<SwitchData> fetchSwitchportData(String switchid) async {
    try {
      final response = await http.get(Uri.parse(baseURL +
          '/switchport_stat/api/switchport_status?switch=' +
          switchid));
      if (json.decode(response.body)['success'] == false) {
        throw Exception('Failed to load device data:\n\n' + response.body);
      }

      print(response.body);
      if (response.statusCode == 200) {
        Map<String, dynamic> json = jsonDecode(response.body)['resposnse'];
        print(json);
        return SwitchData.fromJson(json);
      } else {
        throw Exception('Failed to load device data:\n\n' + response.body);
      }
    } catch (e) {
      throw Exception('Failed to load device data' + e.toString());
    }
  }

  SwitchData _getFallbackSwitchportData() {
    List<Map<String, dynamic>> fallbackJson = [
      {
        "interface": "GigabitEthernet1/1",
        "link_status": "down",
        "last_input": "never"
      },
      {
        "interface": "GigabitEthernet1/12",
        "link_status": "down",
        "last_input": "never"
      },
    ];

    return SwitchData(
      unusedPorts:
          fallbackJson.map((json) => SwitchPort.fromJson(json)).toList(),
      totalPortCount: 373,
      totalPortUsed: 188,
      totalPortUnused: 185,
      usedPortPercentage: 50.4,
      unusedPortPercentage: 49.6,
      switchUptime: "2 years",
      switchName: "STNNWK-21-SA01",
    );
  }
}
