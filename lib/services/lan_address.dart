import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

class LanBindPlan {
  final String address;
  final bool siteLocal;

  const LanBindPlan({required this.address, required this.siteLocal});

  bool get localOnly => address == LanAddress.loopbackAddress;
}

class LanAddress {
  static const String loopbackAddress = '127.0.0.1';

  static LanBindPlan pinned(String address) => LanBindPlan(
        address: address,
        siteLocal: isSiteLocal(address),
      );

  static Future<LanBindPlan> resolve() async {
    final wifi = await _wifiAddress();
    if (wifi != null && isSiteLocal(wifi)) {
      return LanBindPlan(address: wifi, siteLocal: true);
    }
    final candidates = await _interfaceAddresses();
    for (final address in candidates) {
      if (isSiteLocal(address)) {
        return LanBindPlan(address: address, siteLocal: true);
      }
    }
    if (wifi != null) return LanBindPlan(address: wifi, siteLocal: false);
    if (candidates.isNotEmpty) {
      return LanBindPlan(address: candidates.first, siteLocal: false);
    }
    return const LanBindPlan(address: loopbackAddress, siteLocal: false);
  }

  static bool isSiteLocal(String value) {
    final octets = value.split('.');
    if (octets.length != 4) return false;
    final numbers = octets.map(int.tryParse).toList();
    if (numbers.any((n) => n == null)) return false;
    if (numbers.any((n) => n! < 0 || n > 255)) return false;
    final first = numbers[0]!;
    final second = numbers[1]!;
    if (first == 10) return true;
    if (first == 172 && second >= 16 && second <= 31) return true;
    if (first == 192 && second == 168) return true;
    return false;
  }

  static Future<String?> _wifiAddress() async {
    try {
      final ip = await NetworkInfo().getWifiIP();
      if (ip == null || ip.isEmpty) return null;
      return ip;
    } catch (e) {
      debugPrint('LanAddress: wifi lookup failed: $e');
      return null;
    }
  }

  static Future<List<String>> _interfaceAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      return [
        for (final interface in interfaces)
          for (final address in interface.addresses)
            if (address.type == InternetAddressType.IPv4) address.address,
      ];
    } catch (e) {
      debugPrint('LanAddress: interface lookup failed: $e');
      return const [];
    }
  }
}
