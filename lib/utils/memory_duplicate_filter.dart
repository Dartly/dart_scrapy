import 'dart:async';
import '../core/request.dart';
import 'duplicate_filter.dart';
import 'fingerprint.dart';
import 'logger.dart';

/// 内存去重过滤器
class MemoryDuplicateFilter implements DuplicateFilter {
  final String _spiderName;
  final DuplicateFilterConfig _config;
  
  final Set<String> _fingerprints = <String>{};
  int _totalChecked = 0;
  int _totalDuplicates = 0;
  int _totalProcessed = 0;
  Duration _totalCheckTime = Duration.zero;
  DateTime _lastResetTime = DateTime.now();

  /// 构造函数
  MemoryDuplicateFilter({
    required String spiderName,
    required DuplicateFilterConfig config,
  }) : _spiderName = spiderName,
       _config = config;

  @override
  Future<bool> isDuplicate(Request request) async {
    final stopwatch = Stopwatch()..start();
    
    _totalChecked++;
    
    final fingerprint = _generateFingerprint(request);
    final isDuplicate = _fingerprints.contains(fingerprint);
    
    if (isDuplicate) {
      _totalDuplicates++;
      DartScrapyLogger.debug('Duplicate URL found: ${request.url}');
    }

    _totalCheckTime += stopwatch.elapsed;
    return isDuplicate;
  }

  @override
  Future<void> markAsProcessed(Request request) async {
    final fingerprint = _generateFingerprint(request);
    _fingerprints.add(fingerprint);
    _totalProcessed++;
  }

  @override
  Future<List<bool>> areDuplicates(List<Request> requests) async {
    final results = List<bool>.filled(requests.length, false);
    
    for (var i = 0; i < requests.length; i++) {
      final stopwatch = Stopwatch()..start();
      
      _totalChecked++;
      
      final fingerprint = _generateFingerprint(requests[i]);
      final isDuplicate = _fingerprints.contains(fingerprint);
      
      if (isDuplicate) {
        _totalDuplicates++;
        results[i] = true;
      }
      
      _totalCheckTime += stopwatch.elapsed;
    }
    
    return results;
  }

  @override
  Future<void> markBatchAsProcessed(List<Request> requests) async {
    for (final request in requests) {
      final fingerprint = _generateFingerprint(request);
      _fingerprints.add(fingerprint);
    }
    _totalProcessed += requests.length;
  }

  @override
  DuplicateFilterStats getStats() {
    final averageCheckTime = _totalChecked > 0 
        ? _totalCheckTime ~/ _totalChecked 
        : Duration.zero;
    
    final duplicateRate = _totalChecked > 0 
        ? _totalDuplicates / _totalChecked 
        : 0.0;

    return DuplicateFilterStats(
      totalChecked: _totalChecked,
      totalDuplicates: _totalDuplicates,
      totalProcessed: _totalProcessed,
      duplicateRate: duplicateRate,
      averageCheckTime: averageCheckTime,
      lastResetTime: _lastResetTime,
    );
  }

  @override
  Future<void> clear() async {
    _fingerprints.clear();
    _resetStats();
    DartScrapyLogger.info('Memory duplicate filter cleared');
  }

  @override
  Future<void> close() async {
    // 内存过滤器不需要特殊清理
  }

  /// 生成指纹
  String _generateFingerprint(Request request) {
    return FingerprintGenerator.generateForSpider(
      request.url,
      _spiderName,
      excludeParams: _config.excludeParams,
    );
  }

  /// 重置统计信息
  void _resetStats() {
    _totalChecked = 0;
    _totalDuplicates = 0;
    _totalProcessed = 0;
    _totalCheckTime = Duration.zero;
    _lastResetTime = DateTime.now();
  }

  /// 获取内存使用量（估算）
  int getMemoryUsage() {
    // 简单估算：每个指纹约50字节
    return _fingerprints.length * 50;
  }

  /// 获取已处理的URL数量
  int getProcessedCount() => _fingerprints.length;
}