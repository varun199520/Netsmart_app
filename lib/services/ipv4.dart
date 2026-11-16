/// IPv4 subnet math for the Subnet Calculator (runs on the phone, offline).
library;

class Ipv4Subnet {
  Ipv4Subnet(int address, this.prefix)
      : network = address & _mask(prefix),
        assert(prefix >= 0 && prefix <= 32);

  final int network;
  final int prefix;

  static int _mask(int prefix) => prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;

  int get mask => _mask(prefix);
  int get wildcard => ~mask & 0xFFFFFFFF;
  int get broadcast => network | wildcard;
  int get size => 1 << (32 - prefix);

  /// Usable host addresses (RFC 3021: a /31 has two, a /32 has one).
  int get usableHosts => prefix >= 31 ? size : size - 2;
  int get firstUsable => prefix >= 31 ? network : network + 1;
  int get lastUsable => prefix >= 31 ? broadcast : broadcast - 1;

  String get cidr => '${formatIpv4(network)}/$prefix';

  /// Splits this subnet into /[newPrefix] subnets (at most [limit] of them).
  List<Ipv4Subnet> split(int newPrefix, {int limit = 4096}) {
    final step = 1 << (32 - newPrefix);
    final count = 1 << (newPrefix - prefix);
    return [for (var i = 0; i < count && i < limit; i++) Ipv4Subnet(network + i * step, newPrefix)];
  }

}

int? parseIpv4(String text) {
  final parts = text.trim().split('.');
  if (parts.length != 4) return null;
  var value = 0;
  for (final p in parts) {
    if (p.isEmpty || p.length > 3 || !RegExp(r'^\d+$').hasMatch(p)) return null;
    final n = int.parse(p);
    if (n > 255) return null;
    value = (value << 8) | n;
  }
  return value;
}

String formatIpv4(int v) => [24, 16, 8, 0].map((s) => (v >> s) & 0xFF).join('.');

/// A prefix length ("24", "/24") or a dotted mask ("255.255.255.0"); null if invalid.
int? parsePrefix(String text) {
  final t = text.trim().replaceFirst('/', '');
  if (RegExp(r'^\d{1,2}$').hasMatch(t)) {
    final p = int.parse(t);
    return p <= 32 ? p : null;
  }
  final m = parseIpv4(t);
  if (m == null) return null;
  final prefix = 32 - (m ^ 0xFFFFFFFF).bitLength;
  return Ipv4Subnet._mask(prefix) == m ? prefix : null;
}

/// "10.1.2.3/24", or address + separate mask. Throws [FormatException] with a user-facing message.
Ipv4Subnet parseSubnet(String address, [String mask = '']) {
  var addr = address.trim();
  var maskText = mask.trim();
  if (addr.contains('/')) {
    final i = addr.indexOf('/');
    maskText = addr.substring(i + 1);
    addr = addr.substring(0, i);
  }
  final ip = parseIpv4(addr);
  if (ip == null) throw const FormatException('Enter a valid IPv4 address, e.g. 10.20.30.0');
  if (maskText.isEmpty) throw const FormatException('Enter a prefix length (24) or mask (255.255.255.0).');
  final prefix = parsePrefix(maskText);
  if (prefix == null) throw const FormatException('That mask is not valid. Use a prefix length (0–32) or a dotted mask.');
  return Ipv4Subnet(ip, prefix);
}
