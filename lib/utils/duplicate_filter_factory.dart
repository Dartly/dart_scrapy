import 'duplicate_filter.dart';
import 'memory_duplicate_filter.dart';
import 'redis_duplicate_filter.dart';
import 'hybrid_duplicate_filter.dart';
import 'redis_config.dart';

/// 去重过滤器类型枚举
enum DuplicateFilterType {
  memory,    // 仅内存去重
  redis,     // 仅Redis去重
  hybrid,    // 混合去重（内存+Redis）
}

/// 去重过滤器工厂类
class DuplicateFilterFactory {
  /// 创建去重过滤器
  static DuplicateFilter create({
    required String spiderName,
    required DuplicateFilterConfig config,
    RedisConfig? redisConfig,
  }) {
    switch (config.type) {
      // ignore: constant_pattern_never_matches_value_type
      case DuplicateFilterType.memory:
        return MemoryDuplicateFilter(
          spiderName: spiderName,
          config: config,
        );
        
      // ignore: constant_pattern_never_matches_value_type
      case DuplicateFilterType.redis:
        if (redisConfig == null) {
          throw ArgumentError(
            'Redis configuration is required for Redis duplicate filter'
          );
        }
        return RedisDuplicateFilter(
          spiderName: spiderName,
          redisConfig: redisConfig,
          config: config,
        );
        
      // ignore: constant_pattern_never_matches_value_type
      case DuplicateFilterType.hybrid:
        return HybridDuplicateFilter(
          spiderName: spiderName,
          config: config,
          redisConfig: redisConfig,
        );
        
      default:
        // 默认使用混合模式
        return HybridDuplicateFilter(
          spiderName: spiderName,
          config: config,
          redisConfig: redisConfig,
        );
    }
  }

  /// 从配置创建去重过滤器
  static DuplicateFilter createFromConfig({
    required String spiderName,
    Map<String, dynamic>? config,
    RedisConfig? redisConfig,
  }) {
    final filterConfig = DuplicateFilterConfig.fromMap(config ?? {});
    return create(
      spiderName: spiderName,
      config: filterConfig,
      redisConfig: redisConfig,
    );
  }

  /// 获取默认配置
  static DuplicateFilterConfig getDefaultConfig() {
    return DuplicateFilterConfig();
  }

  /// 验证配置
  static bool validateConfig({
    required DuplicateFilterType filterType,
    RedisConfig? redisConfig,
  }) {
    if (filterType == DuplicateFilterType.redis && redisConfig == null) {
      return false;
    }
    return true;
  }
}