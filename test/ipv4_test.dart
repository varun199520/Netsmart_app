import 'package:flutter_test/flutter_test.dart';
import 'package:netsmart/services/ipv4.dart';

void main() {
  test('parses address/prefix and computes the usual fields', () {
    final s = parseSubnet('10.20.30.77/26');
    expect(s.cidr, '10.20.30.64/26');
    expect(formatIpv4(s.mask), '255.255.255.192');
    expect(formatIpv4(s.wildcard), '0.0.0.63');
    expect(formatIpv4(s.broadcast), '10.20.30.127');
    expect(formatIpv4(s.firstUsable), '10.20.30.65');
    expect(formatIpv4(s.lastUsable), '10.20.30.126');
    expect(s.usableHosts, 62);
  });

  test('accepts a dotted mask and handles /31 and /32', () {
    expect(parseSubnet('192.0.2.9', '255.255.255.248').cidr, '192.0.2.8/29');
    expect(parseSubnet('192.0.2.9/31').usableHosts, 2);
    expect(parseSubnet('192.0.2.9/32').usableHosts, 1);
  });

  test('rejects bad input with a readable message', () {
    expect(() => parseSubnet('10.0.0.256/24'), throwsFormatException);
    expect(() => parseSubnet('10.0.0.1', '255.0.255.0'), throwsFormatException);
    expect(() => parseSubnet('10.0.0.1'), throwsFormatException);
    expect(parsePrefix('/24'), 24);
    expect(parsePrefix('33'), isNull);
  });

  test('splits a supernet', () {
    final parts = parseSubnet('10.0.0.0/22').split(24);
    expect(parts.map((p) => p.cidr), ['10.0.0.0/24', '10.0.1.0/24', '10.0.2.0/24', '10.0.3.0/24']);
    expect(parseSubnet('10.0.0.0/16').split(30, limit: 10), hasLength(10));
  });
}
