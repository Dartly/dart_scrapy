// ignore_for_file: unused_field

import 'dart:async';
import '../core/request.dart';
import 'duplicate_filter.dart';
import 'memory_duplicate_filter.dart';
import 'redis_duplicate_filter.dart';
import 'redis_config.dart';
import 'logger.dart';

/// 混合去重过滤器（内存 + Redis）
class HybridDuplicateFilter implements DuplicateFilter {
  final String _spiderName;
  final DuplicateFilterConfig _config;
  
  late final MemoryDuplicateFilter _memoryFilter;
  late final RedisDuplicateFilter? _redisFilter;
  
  bool _useRedis;
  int _totalChecked = 0;
  int _totalDuplicates = 0;
  int _totalProcessed = 0;
  Duration _totalCheckTime = Duration.zero;
  DateTime _lastResetTime = DateTime.now();

  /// 构造函数
  HybridDuplicateFilter({
    required String spiderName,
    required DuplicateFilterConfig config,
    RedisConfig? redisConfig,
  }) : _spiderName = spiderName,
       _config = config,
       _useRedis = config.useRedis && redisConfig != null {
    
    _memoryFilter = MemoryDuplicateFilter(
      spiderName: spiderName,
      config: config,
    );
    
    if (_useRedis && redisConfig != null) {
      _redisFilter = RedisDuplicateFilter(
        spiderName: spiderName,
        redisConfig: redisConfig,
        config: config,
      );
    } else {
      _redisFilter = null;
      if (config.useRedis) {
        DartScrapyLogger.warning(
          'Redis configuration not provided, falling back to memory-only deduplication'
        );
      }
    }
  }

  @override
  Future<bool> isDuplicate(Request request) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      _totalChecked++;
      
      // 1. 先检查内存
      final memoryDuplicate = await _memoryFilter.isDuplicate(request);
      if (memoryDuplicate) {
        _totalDuplicates++;
        _totalCheckTime += stopwatch.elapsed;
        return true;
      }

      // 2. 如果内存中没有，检查Redis
      if (_useRedis && _redisFilter != null) {
        final redisDuplicate = await _redisFilter!.isDuplicate(request);
        if (redisDuplicate) {
          _totalDuplicates++;
          _totalCheckTime += stopwatch.elapsed;
          return true;
        }
      }

      _totalCheckTime += stopwatch.elapsed;
      return false;
    } catch (e) {
      DartScrapyLogger.error('Error checking duplicate: $e');
      _totalCheckTime += stopwatch.elapsed;
      return false;
    }
  }

  @override
  Future<void> markAsProcessed(Request request) async {
    try {
      // 1. 标记到内存
      await _memoryFilter.markAsProcessed(request);
      
      // 2. 标记到Redis
      if (_useRedis && _redisFilter != null) {
        await _redisFilter!.markAsProcessed(request);
      }
      
      _totalProcessed++;
    } catch (e) {
      DartScrapyLogger.error('Error marking as processed: $e');
    }
  }

  @override
  Future<List<bool>> areDuplicates(List<Request> requests) async {
    if (requests.isEmpty) return [];

    final results = List<bool>.filled(requests.length, false);
    
    try {
      // 1. 先检查内存
      final memoryResults = await _memoryFilter.areDuplicates(requests);
      
      // 2. 找出内存中不重复的请求
      final remainingRequests = <Request>[];
      final remainingIndices = <int>[];
      
      for (var i = 0; i < requests.length; i++) {
        if (!memoryResults[i]) {
          remainingRequests.add(requests[i]);
          remainingIndices.add(i);
        } else {
          results[i] = true;
        }
      }
      
      // 3. 检查Redis中的剩余请求
      if (_useRedis && _redisFilter != null && remainingRequests.isNotEmpty) {
        final redisResults = await _redisFilter!.areDuplicates(remainingRequests);
        
        for (var i = 0; i < remainingIndices.length; i++) {
          final originalIndex = remainingIndices[i];
          results[originalIndex] = redisResults[i];
        }
      }
      
      _totalChecked += requests.length;
      _totalDuplicates += results.where((r) => r).length;
    } catch (e) {
      DartScrapyLogger.error('Error batch checking duplicates: $e');
    }

    return results;
  }

  @override
  Future<void> markBatchAsProcessed(List<Request> requests) async {
    if (requests.isEmpty) return;

    try {
      // 1. 标记到内存
      await _memoryFilter.markBatchAsProcessed(requests);
      
      // 2. 标记到Redis
      if (_useRedis && _redisFilter != null) {
        await _redisFilter!.markBatchAsProcessed(requests);
      }
      
      _totalProcessed += requests.length;
    } catch (e) {
      DartScrapyLogger.error('Error batch marking as processed: $e');
    }
  }

  @override
  DuplicateFilterStats getStats() {
    final memoryStats = _memoryFilter.getStats();
    
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
      additionalInfo: {
        'memory_processed': memoryStats.totalProcessed,
        'memory_usage': _memoryFilter.getMemoryUsage(),
        'redis_enabled': _useRedis,
        'redis_processed': _redisFilter?.getStats().totalProcessed ?? 0,
      },
    );
  }

  @override
  Future<void> clear() async {
    try {
      await _memoryFilter.clear();
      
      if (_useRedis && _redisFilter != null) {
        await _redisFilter!.clear();
      }
      
      _resetStats();
    } catch (e) {
      DartScrapyLogger.error('Error clearing hybrid filter: $e');
    }
  }

  @override
  Future<void> close() async {
    try {
      await _memoryFilter.close();
      
      if (_useRedis && _redisFilter != null) {
        await _redisFilter!.close();
      }
    } catch (e) {
      DartScrapyLogger.error('Error closing hybrid filter: $e');
    }
  }

  /// 获取内存使用量
  int getMemoryUsage() => _memoryFilter.getMemoryUsage();

  /// 获取Redis状态
  Map<String, dynamic> getRedisStatus() {
    if (!_useRedis || _redisFilter == null) {
      return {'enabled': false};
    }

    return {
      'enabled': true,
      'processed_count': _redisFilter!.getProcessedCount(),
    };
  }

  /// 切换Redis使用状态
  Future<void> setUseRedis(bool useRedis) async {
    _useRedis = useRedis && _redisFilter != null;
    DartScrapyLogger.info('Redis usage switched to: $_useRedis');
  }

  /// 重置统计信息
  void _resetStats() {
    _totalChecked = 0;
    _totalDuplicates = 0;
    _totalProcessed = 0;
    _totalCheckTime = Duration.zero;
    _lastResetTime = DateTime.now();
  }
}