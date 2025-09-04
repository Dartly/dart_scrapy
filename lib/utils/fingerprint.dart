import 'dart:convert';
import 'package:crypto/crypto.dart';

/// URL指纹生成器
class FingerprintGenerator {
  /// 生成URL指纹
  static String generate(String url, {List<String>? excludeParams}) {
    final normalizedUrl = _normalizeUrl(url, excludeParams: excludeParams);
    final bytes = utf8.encode(normalizedUrl);
    final digest = sha256.convert(bytes);
    return 'fp:${digest.toString().substring(0, 16)}';
  }

  /// 标准化URL
  static String _normalizeUrl(String url, {List<String>? excludeParams}) {
    try {
      final uri = Uri.parse(url.trim());
      
      // 构建基础URL
      final buffer = StringBuffer();
      buffer.write(uri.scheme.toLowerCase());
      buffer.write('://');
      buffer.write(uri.host.toLowerCase());
      
      // 标准化路径
      var path = uri.path;
      if (path.isEmpty) {
        path = '/';
      } else {
        // 移除多余斜杠
        path = path.replaceAll(RegExp(r'/+'), '/');
        // 确保以/开头
        if (!path.startsWith('/')) {
          path = '/$path';
        }
      }
      buffer.write(path);
      
      // 处理查询参数
      final params = Map<String, String>.from(uri.queryParameters);
      
      // 移除需要排除的参数
      final excludeList = excludeParams ?? _defaultExcludedParams;
      for (final param in excludeList) {
        params.remove(param);
      }
      
      // 按字母顺序排序参数
      if (params.isNotEmpty) {
        buffer.write('?');
        final sortedKeys = params.keys.toList()..sort();
        final paramPairs = sortedKeys.map((key) => '$key=${params[key]}');
        buffer.write(paramPairs.join('&'));
      }
      
      return buffer.toString();
    } catch (e) {
      // 如果解析失败，返回原始URL的哈希
      return url;
    }
  }

  /// 默认需要排除的参数列表
  static final List<String> _defaultExcludedParams = [
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'fbclid',
    'gclid',
    'ref',
    'source',
    '_ga',
    '_gl',
  ];

  /// 为特定爬虫生成带前缀的指纹
  static String generateForSpider(String url, String spiderName, {
    List<String>? excludeParams,
  }) {
    final fingerprint = generate(url, excludeParams: excludeParams);
    return '$spiderName:$fingerprint';
  }

  /// 批量生成指纹
  static List<String> generateBatch(List<String> urls, {
    List<String>? excludeParams,
  }) {
    return urls.map((url) => generate(url, excludeParams: excludeParams)).toList();
  }

  /// 验证指纹格式
  static bool isValidFingerprint(String fingerprint) {
    return fingerprint.startsWith('fp:') && fingerprint.length == 20;
  }
}