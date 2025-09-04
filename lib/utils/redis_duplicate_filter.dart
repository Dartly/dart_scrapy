// ignore_for_file: unused_field

import 'dart:async';
import '../core/request.dart';
import 'duplicate_filter.dart';
import 'fingerprint.dart';
import 'redis_manager.dart';
import 'redis_config.dart';
import 'logger.dart';

/// Redis去重过滤器
class RedisDuplicateFilter implements DuplicateFilter {
  final String _spiderName;
  final RedisConfig _redisConfig;
  final DuplicateFilterConfig _config;
  
  int _totalChecked = 0;
  int _totalDuplicates = 0;
  int _totalProcessed = 0;
  Duration _totalCheckTime = Duration.zero;
  DateTime _lastResetTime = DateTime.now();

  /// 构造函数
  RedisDuplicateFilter({
    required String spiderName,
    required RedisConfig redisConfig,
    required DuplicateFilterConfig config,
  }) : _spiderName = spiderName,
       _redisConfig = redisConfig,
       _config = config;

  /// 获取Redis键
  String _getRedisKey() {
    return 'scrapy:duplicates:$_spiderName:fingerprints';
  }

  @override
  Future<bool> isDuplicate(Request request) async {
    if (!_config.enabled) return false;
    
    final stopwatch = Stopwatch()..start();
    
    try {
      _totalChecked++;
      
      final fingerprint = _generateFingerprint(request);
      final key = _getRedisKey();
      
      final command = await RedisManager().getCommand();
      if (command == null) {
        DartScrapyLogger.warning('Redis not available, skipping duplicate check');
        return false;
      }

      final exists = await command.send_object(['SISMEMBER', key, fingerprint]);
      final isDuplicate = exists == 1;
      
      if (isDuplicate) {
        _totalDuplicates++;
        DartScrapyLogger.debug('Duplicate URL found: ${request.url}');
      }

      _totalCheckTime += stopwatch.elapsed;
      return isDuplicate;
    } catch (e) {
      DartScrapyLogger.error('Error checking duplicate: $e');
      _totalCheckTime += stopwatch.elapsed;
      return false; // 出错时默认不认为是重复
    }
  }

  @override
  Future<void> markAsProcessed(Request request) async {
    try {
      final fingerprint = _generateFingerprint(request);
      final key = _getRedisKey();
      
      final command = await RedisManager().getCommand();
      if (command == null) {
        DartScrapyLogger.warning('Redis not available, skipping mark as processed');
        return;
      }

      await command.send_object([
        'SADD',
        key,
        fingerprint,
      ]);

      // 设置TTL
      if (_config.redisTtl.inSeconds > 0) {
        await command.send_object([
          'EXPIRE',
          key,
          _config.redisTtl.inSeconds,
        ]);
      }

      _totalProcessed++;
    } catch (e) {
      DartScrapyLogger.error('Error marking as processed: $e');
    }
  }

  @override
  Future<List<bool>> areDuplicates(List<Request> requests) async {
    final results = List<bool>.filled(requests.length, false);
    
    if (requests.isEmpty) return results;

    try {
      final fingerprints = requests.map(_generateFingerprint).toList();
      final key = _getRedisKey();
      
      final command = await RedisManager().getCommand();
      if (command == null) {
        return results;
      }

      // 批量检查，使用事务
      final responses = <dynamic>[];
      for (final fingerprint in fingerprints) {
        final response = await command.send_object(['SISMEMBER', key, fingerprint]);
        responses.add(response);
      }
      
      for (var i = 0; i < responses.length; i++) {
        results[i] = responses[i] == 1;
        if (results[i]) _totalDuplicates++;
      }
      
      _totalChecked += requests.length;
    } catch (e) {
      DartScrapyLogger.error('Error batch checking duplicates: $e');
    }

    return results;
  }

  @override
  Future<void> markBatchAsProcessed(List<Request> requests) async {
    if (requests.isEmpty) return;

    try {
      final fingerprints = requests.map(_generateFingerprint).toList();
      final key = _getRedisKey();
      
      final command = await RedisManager().getCommand();
      if (command == null) return;

      // 批量添加
      if (fingerprints.isNotEmpty) {
        final saddArgs = ['SADD', key, ...fingerprints];
        await command.send_object(saddArgs);
      }
      
      // 设置TTL
      if (_config.redisTtl.inSeconds > 0) {
        await command.send_object(['EXPIRE', key, _config.redisTtl.inSeconds]);
      }
      _totalProcessed += requests.length;
    } catch (e) {
      DartScrapyLogger.error('Error batch marking as processed: $e');
    }
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
    try {
      final key = _getRedisKey();
      final command = await RedisManager().getCommand();
      
      if (command != null) {
        await command.send_object(['DEL', key]);
      }
      
      _resetStats();
    } catch (e) {
      DartScrapyLogger.error('Error clearing duplicate filter: $e');
    }
  }

  @override
  Future<void> close() async {
    // 由RedisManager统一管理连接
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

  /// 获取已处理的URL数量
  Future<int> getProcessedCount() async {
    try {
      final key = _getRedisKey();
      final command = await RedisManager().getCommand();
      
      if (command == null) return 0;
      
      final count = await command.send_object(['SCARD', key]);
      return count is int ? count : 0;
    } catch (e) {
      DartScrapyLogger.error('Error getting processed count: $e');
      return 0;
    }
  }
}