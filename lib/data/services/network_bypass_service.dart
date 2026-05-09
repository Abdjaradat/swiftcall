import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles network bypass for restricted environments.
/// Supports HTTP/SOCKS5 proxy configuration and fallback TURN servers.
class NetworkBypassService {
  static NetworkBypassService get instance => _instance;
  static final NetworkBypassService _instance = NetworkBypassService._();
  NetworkBypassService._();

  static const String _proxyHostKey    = 'proxy_host';
  static const String _proxyPortKey    = 'proxy_port';
  static const String _proxyUserKey    = 'proxy_user';
  static const String _proxyPassKey    = 'proxy_pass';
  static const String _proxyTypeKey    = 'proxy_type';  // 'http' | 'socks5' | 'none'
  static const String _bypassEnabledKey = 'bypass_enabled';

  ProxyConfig? _activeProxy;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_bypassEnabledKey) ?? false;
    if (!enabled) return;

    final host = prefs.getString(_proxyHostKey);
    final port = prefs.getInt(_proxyPortKey);
    if (host == null || port == null) return;

    _activeProxy = ProxyConfig(
      host: host,
      port: port,
      username: prefs.getString(_proxyUserKey),
      password: prefs.getString(_proxyPassKey),
      type: ProxyType.values.firstWhere(
        (t) => t.name == (prefs.getString(_proxyTypeKey) ?? 'http'),
        orElse: () => ProxyType.http,
      ),
    );
  }

  Future<void> saveConfig(ProxyConfig? config) async {
    final prefs = await SharedPreferences.getInstance();
    if (config == null) {
      await prefs.setBool(_bypassEnabledKey, false);
      _activeProxy = null;
      return;
    }
    await prefs.setBool(_bypassEnabledKey, true);
    await prefs.setString(_proxyHostKey, config.host);
    await prefs.setInt(_proxyPortKey, config.port);
    await prefs.setString(_proxyTypeKey, config.type.name);
    if (config.username != null) await prefs.setString(_proxyUserKey, config.username!);
    if (config.password != null) await prefs.setString(_proxyPassKey, config.password!);
    _activeProxy = config;
  }

  /// Applies proxy to a [Dio] client
  Dio buildDio() {
    final dio = Dio();
    final proxy = _activeProxy;
    if (proxy == null) return dio;

    (dio.httpClientAdapter as dynamic).onHttpClientCreate = (HttpClient client) {
      client.findProxy = (uri) {
        return proxy.type == ProxyType.socks5
            ? 'SOCKS5 ${proxy.host}:${proxy.port}'
            : 'PROXY ${proxy.host}:${proxy.port}';
      };
      if (proxy.username != null && proxy.password != null) {
        client.addProxyCredentials(
          proxy.host,
          proxy.port,
          'Basic',
          HttpClientBasicCredentials(proxy.username!, proxy.password!),
        );
      }
      return client;
    };
    return dio;
  }

  ProxyConfig? get activeProxy => _activeProxy;
  bool get isEnabled => _activeProxy != null;

  /// Extra TURN/STUN ice servers for WebRTC behind restrictive NATs
  List<Map<String, dynamic>> get iceServers => [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    {
      'urls': [
        'turn:openrelay.metered.ca:80',
        'turn:openrelay.metered.ca:443',
        'turn:openrelay.metered.ca:443?transport=tcp',
      ],
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
    {
      'urls': 'turn:relay.metered.ca:80',
      'username': 'e9b4b7e4b1a61f0b',
      'credential': 'SwiftCall',
    },
  ];

  Future<bool> testConnection() async {
    try {
      final dio = buildDio();
      final res = await dio
          .get('https://www.google.com')
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class ProxyConfig {
  final String host;
  final int port;
  final String? username;
  final String? password;
  final ProxyType type;

  const ProxyConfig({
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.type = ProxyType.http,
  });

  @override
  String toString() => '${type.name}://$host:$port';
}

enum ProxyType { http, socks5 }
