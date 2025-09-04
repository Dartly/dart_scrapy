import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

/// robots.txt解析器
class RobotsTxtParser {
  final Map<String, List<String>> _rules = {};
  final Map<String, DateTime> _cacheExpiry = {};
  final Duration _cacheDuration = Duration(hours: 24);
  final http.Client _client = http.Client();

  /// 检查URL是否被允许
  Future<bool> isAllowed(String url, {String userAgent = '*'}) async {
    try {
      final uri = Uri.parse(url);
      final robotsUrl = '${uri.scheme}://${uri.host}/robots.txt';
      
      // 检查缓存
      if (_shouldRefreshCache(robotsUrl)) {
        await _loadRobotsTxt(robotsUrl, userAgent: userAgent);
      }
      
      return _checkRules(uri.path, userAgent, robotsUrl);
    } catch (e) {
      DartScrapyLogger.warning('Failed to check robots.txt for $url: $e');
      return true; // 如果出错，默认允许访问
    }
  }

  /// 检查是否需要刷新缓存
  bool _shouldRefreshCache(String robotsUrl) {
    final expiry = _cacheExpiry[robotsUrl];
    return expiry == null || DateTime.now().isAfter(expiry);
  }

  /// 加载robots.txt文件
  Future<void> _loadRobotsTxt(String robotsUrl, {String userAgent = '*'}) async {
    try {
      final response = await _client.get(Uri.parse(robotsUrl));
      
      if (response.statusCode == 200) {
        final content = utf8.decode(response.bodyBytes);
        _parseRobotsTxt(content, robotsUrl, userAgent: userAgent);
        _cacheExpiry[robotsUrl] = DateTime.now().add(_cacheDuration);
      } else if (response.statusCode == 404) {
        // robots.txt不存在，允许所有访问
        _rules[robotsUrl] = [];
        _cacheExpiry[robotsUrl] = DateTime.now().add(_cacheDuration);
      }
    } catch (e) {
      DartScrapyLogger.warning('Failed to load robots.txt from $robotsUrl: $e');
      _rules[robotsUrl] = []; // 出错时允许所有访问
    }
  }

  /// 解析robots.txt内容
  void _parseRobotsTxt(String content, String robotsUrl, {String userAgent = '*'}) {
    final lines = content.split('\n');
    String? currentUserAgent;
    final rules = <String>[];
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      
      final parts = trimmed.split(':');
      if (parts.length < 2) continue;
      
      final key = parts[0].trim().toLowerCase();
      final value = parts.sublist(1).join(':').trim();
      
      switch (key) {
        case 'user-agent':
          currentUserAgent = value;
          break;
        case 'disallow':
          if (currentUserAgent != null && 
              (currentUserAgent == '*' || currentUserAgent == userAgent)) {
            rules.add(value);
          }
          break;
        case 'allow':
          if (currentUserAgent != null && 
              (currentUserAgent == '*' || currentUserAgent == userAgent)) {
            rules.add('ALLOW:$value');
          }
          break;
      }
    }
    
    _rules[robotsUrl] = rules;
  }

  /// 检查URL路径是否匹配规则
  bool _checkRules(String path, String userAgent, String robotsUrl) {
    final rules = _rules[robotsUrl] ?? [];
    if (rules.isEmpty) return true;
    
    // 首先检查ALLOW规则
    for (final rule in rules) {
      if (rule.startsWith('ALLOW:')) {
        final allowPath = rule.substring(6);
        if (_matchesPattern(path, allowPath)) {
          return true;
        }
      }
    }
    
    // 然后检查DISALLOW规则
    for (final rule in rules) {
      if (!rule.startsWith('ALLOW:') && _matchesPattern(path, rule)) {
        return false; // 如果匹配DISALLOW规则，禁止访问
      }
    }
    
    return true; // 默认允许访问
  }

  /// 检查路径是否匹配模式
  bool _matchesPattern(String path, String pattern) {
    if (pattern.isEmpty) return true; // 空模式匹配所有路径
    
    // 处理通配符
    if (pattern.contains('*')) {
      final regexPattern = pattern
          .replaceAll('.', r'\.')
          .replaceAll('*', '.*')
          .replaceAll(r'$', r'\$');
      return RegExp('^$regexPattern').hasMatch(path);
    }
    
    // 精确匹配或前缀匹配
    return path.startsWith(pattern);
  }

  /// 清理缓存
  void clearCache() {
    _rules.clear();
    _cacheExpiry.clear();
  }

  /// 关闭解析器
  Future<void> close() async {
    _client.close();
    clearCache();
  }
}

/// robots.txt检查器
class RobotsTxtChecker {
  static final RobotsTxtParser _parser = RobotsTxtParser();

  /// 检查URL是否被允许
  static Future<bool> isAllowed(String url, {String userAgent = '*'}) async {
    return await _parser.isAllowed(url, userAgent: userAgent);
  }

  /// 清理缓存
  static void clearCache() {
    _parser.clearCache();
  }

  /// 关闭检查器
  static Future<void> close() async {
    await _parser.close();
  }
}