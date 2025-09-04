import '../core/request.dart';

/// 去重过滤器接口
abstract class DuplicateFilter {
  /// 检查请求是否已存在
  Future<bool> isDuplicate(Request request);
  
  /// 标记请求为已处理
  Future<void> markAsProcessed(Request request);
  
  /// 批量检查请求是否已存在
  Future<List<bool>> areDuplicates(List<Request> requests);
  
  /// 批量标记请求为已处理
  Future<void> markBatchAsProcessed(List<Request> requests);
  
  /// 获取去重统计信息
  DuplicateFilterStats getStats();
  
  /// 清理过滤器数据
  Future<void> clear();
  
  /// 关闭过滤器
  Future<void> close();
}

/// 去重过滤器统计信息
class DuplicateFilterStats {
  final int totalChecked;
  final int totalDuplicates;
  final int totalProcessed;
  final double duplicateRate;
  final Duration averageCheckTime;
  final DateTime lastResetTime;
  final Map<String, dynamic>? additionalInfo;

  const DuplicateFilterStats({
    required this.totalChecked,
    required this.totalDuplicates,
    required this.totalProcessed,
    required this.duplicateRate,
    required this.averageCheckTime,
    required this.lastResetTime,
    this.additionalInfo,
  });

  @override
  String toString() {
    return 'DuplicateFilterStats('
        'totalChecked: $totalChecked, '
        'totalDuplicates: $totalDuplicates, '
        'duplicateRate: ${(duplicateRate * 100).toStringAsFixed(2)}%, '
        'averageCheckTime: ${averageCheckTime.inMilliseconds}ms)';
  }
}

/// 去重过滤器配置
class DuplicateFilterConfig {
  final bool enabled;
  final String type;
  final bool useRedis;
  final int memoryCacheSize;
  final Duration redisTtl;
  final bool enableCompression;
  final bool enableBloomFilter;
  final double falsePositiveRate;
  final List<String> excludeParams;

  const DuplicateFilterConfig({
    this.enabled = true,
    this.type = 'hybrid', // 'memory', 'redis', 'hybrid'
    this.useRedis = true,
    this.memoryCacheSize = 10000,
    this.redisTtl = const Duration(days: 7),
    this.enableCompression = false,
    this.enableBloomFilter = false,
    this.falsePositiveRate = 0.01,
    this.excludeParams = const [],
  });

  factory DuplicateFilterConfig.fromMap(Map<String, dynamic> map) {
    return DuplicateFilterConfig(
      enabled: map['enabled'] ?? true,
      type: map['type'] ?? 'hybrid',
      useRedis: map['useRedis'] ?? true,
      memoryCacheSize: map['memoryCacheSize'] ?? 10000,
      redisTtl: Duration(
        milliseconds: map['redisTtl'] ?? Duration(days: 7).inMilliseconds,
      ),
      enableCompression: map['enableCompression'] ?? false,
      enableBloomFilter: map['enableBloomFilter'] ?? false,
      falsePositiveRate: map['falsePositiveRate'] ?? 0.01,
      excludeParams: List<String>.from(map['excludeParams'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'type': type,
      'useRedis': useRedis,
      'memoryCacheSize': memoryCacheSize,
      'redisTtl': redisTtl.inMilliseconds,
      'enableCompression': enableCompression,
      'enableBloomFilter': enableBloomFilter,
      'falsePositiveRate': falsePositiveRate,
      'excludeParams': excludeParams,
    };
  }
}