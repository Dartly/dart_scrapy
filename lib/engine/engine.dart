import 'dart:async';
import 'package:dart_scrapy/utils/duplicate_filter_factory.dart';
import 'package:dart_scrapy/utils/redis_manager.dart';
import 'package:pool/pool.dart';
import '../core/request.dart';
import '../core/item.dart';
import '../scrapy/scrapy.dart';
import 'scheduler.dart';
import 'downloader.dart';
import '../middleware/middleware.dart';
import '../pipeline/pipeline.dart';
import '../utils/logger.dart';
import '../utils/redis_config.dart';

/// 爬虫引擎状态
enum EngineState {
  idle,
  starting,
  running,
  paused,
  stopping,
  stopped,
  error,
}

/// 爬虫引擎配置
class EngineConfig {
  final int maxConcurrentRequests;
  final Duration requestDelay;
  final bool enableRetry;
  final int maxRetries;
  final Duration retryDelay;
  final bool enableCaching;
  final Duration cacheDuration;
  final bool enableLogging;
  final String? logFile;
  final bool obeyRobotsTxt;
  final String userAgent;
  final bool enableDeduplication;
  final DuplicateFilterType duplicateFilterType;
  final RedisConfig? redisConfig;
  final Map<String, dynamic>? duplicateConfig;

  const EngineConfig({
    this.maxConcurrentRequests = 16,
    this.requestDelay = Duration.zero,
    this.enableRetry = true,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.enableCaching = false,
    this.cacheDuration = const Duration(hours: 1),
    this.enableLogging = true,
    this.logFile,
    this.obeyRobotsTxt = true,
    this.userAgent = 'DartScrapy/0.1.0',
    this.enableDeduplication = false,
    this.duplicateFilterType = DuplicateFilterType.memory,
    this.redisConfig,
    this.duplicateConfig,
  });
}

/// 爬虫统计信息
class SpiderStats {
  int totalRequests = 0;
  int successfulRequests = 0;
  int failedRequests = 0;
  int totalItems = 0;
  int totalPages = 0;
  DateTime startTime = DateTime.now();
  DateTime? endTime;

  /// 获取运行时间
  Duration get runtime =>
      endTime?.difference(startTime) ?? DateTime.now().difference(startTime);

  /// 获取成功率
  double get successRate =>
      totalRequests > 0 ? successfulRequests / totalRequests : 0.0;

  /// 获取失败率
  double get failureRate =>
      totalRequests > 0 ? failedRequests / totalRequests : 0.0;

  /// 获取平均请求时间（毫秒）
  double get averageRequestTime =>
      totalRequests > 0 ? runtime.inMilliseconds / totalRequests : 0.0;

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'total_requests': totalRequests,
      'successful_requests': successfulRequests,
      'failed_requests': failedRequests,
      'total_items': totalItems,
      'total_pages': totalPages,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'runtime_ms': runtime.inMilliseconds,
      'success_rate': successRate,
      'failure_rate': failureRate,
      'average_request_time_ms': averageRequestTime,
    };
  }
}

/// 爬虫引擎
class ScrapyEngine {
  final Scrapy _scrapy;
  final EngineConfig _config;
  final Scheduler _scheduler;
  final Downloader _downloader;
  final MiddlewareManager _middlewareManager;
  final PipelineManager _pipelineManager;

  EngineState _state = EngineState.idle;
  final SpiderStats _stats = SpiderStats();
  final Pool _requestPool;
  final StreamController<Item> _itemController =
      StreamController<Item>.broadcast();
  final StreamController<SpiderStats> _statsController =
      StreamController<SpiderStats>.broadcast();

  Stream<Item> get itemStream => _itemController.stream;
  Stream<SpiderStats> get statsStream => _statsController.stream;
  SpiderStats get stats => _stats;
  EngineState get state => _state;

  ScrapyEngine({
    required Scrapy scrapy,
    EngineConfig? config,
    Scheduler? scheduler,
    Downloader? downloader,
    MiddlewareManager? middlewareManager,
    PipelineManager? pipelineManager,
  })  : _scrapy = scrapy,
        _config = config ?? const EngineConfig(),
        _scheduler = scheduler ?? MemoryScheduler(),
        _downloader = downloader ?? HttpDownloader(),
        _middlewareManager = middlewareManager ?? MiddlewareManager(),
        _pipelineManager = pipelineManager ?? PipelineManager(),
        _requestPool = Pool(config?.maxConcurrentRequests ?? 16);

  /// 启动爬虫
  Future<void> start() async {
    if (_state != EngineState.idle && _state != EngineState.stopped) {
      throw StateError('Engine is already running or paused');
    }

    _state = EngineState.starting;
    _stats.startTime = DateTime.now();
    _stats.endTime = null;

    try {
      DartScrapyLogger.info('🚀 Engine: 开始启动爬虫...');
      // 初始化组件
      await _scrapy.init({});
      DartScrapyLogger.info('🚀 Engine: 爬虫初始化完成');

      DartScrapyLogger.info('🚀 Engine: 正在打开管道管理器...');
      await _pipelineManager.open();
      DartScrapyLogger.info('🚀 Engine: 管道管理器已打开');

      // 添加起始请求
      final startRequests = _scrapy.startRequests();

      // 检查重复的起始请求
      final uniqueStartRequests = <Request>[];
      if (_scrapy.enableDeduplication) {
        final duplicates = await _scrapy.areDuplicates(startRequests);
        for (var i = 0; i < startRequests.length; i++) {
          if (!duplicates[i]) {
            uniqueStartRequests.add(startRequests[i]);
          } else {
            DartScrapyLogger.info('🔄 起始请求已存在: ${startRequests[i].url}');
          }
        }
      } else {
        uniqueStartRequests.addAll(startRequests);
      }

      // 检查robots.txt规则
      for (final request in uniqueStartRequests) {
        final isAllowed = _config.obeyRobotsTxt
            ? await _scrapy.isUrlCompliant(request.url,
                userAgent: _config.userAgent)
            : _scrapy.isUrlAllowed(request.url);
        if (isAllowed) {
          await _scheduler.enqueue(request);
          if (_scrapy.enableDeduplication) {
            await _scrapy.markAsProcessed(request);
          }
        } else {
          DartScrapyLogger.info('🚫 起始请求被robots.txt禁止: ${request.url}');
        }
      }

      _state = EngineState.running;
      DartScrapyLogger.info('Spider engine started for ${_scrapy.name}');

      try {
        // 开始处理请求
        await _processRequests();
      } finally {
        // 确保引擎最终停止，即使发生异常
        if (_state == EngineState.running || _state == EngineState.error) {
          await stop();
        }
      }
    } catch (e, stackTrace) {
      _state = EngineState.error;
      DartScrapyLogger.error('Engine failed to start', e, stackTrace);
      await _cleanup(); // 清理资源
      rethrow;
    }
  }

  /// 暂停爬虫
  Future<void> pause() async {
    if (_state == EngineState.running) {
      _state = EngineState.paused;
      await _scrapy.pause();
      DartScrapyLogger.info('Spider engine paused');
    }
  }

  /// 恢复爬虫
  Future<void> resume() async {
    if (_state == EngineState.paused) {
      _state = EngineState.running;
      await _scrapy.resume();
      DartScrapyLogger.info('Spider engine resumed');
      await _processRequests();
    }
  }

  /// 停止爬虫
  Future<void> stop() async {
    if (_state == EngineState.running ||
        _state == EngineState.paused ||
        _state == EngineState.starting) {
      _state = EngineState.stopping;
      await _scrapy.stop();
      DartScrapyLogger.info('Spider engine stopping...');

      // 等待当前请求完成
      await Future.delayed(Duration.zero);

      _state = EngineState.stopped;
      _stats.endTime = DateTime.now();

      // 清理资源
      await _cleanup();

      DartScrapyLogger.info('Spider engine stopped');
      if (!_statsController.isClosed) {
        _statsController.add(_stats);
      }
    } else {
      DartScrapyLogger.debug(
          'Spider engine stop() called but state is $_state, doing nothing');
    }
  }

  /// 处理请求队列
  Future<void> _processRequests() async {
    final futures = <Future>{};
    int idleCount = 0;
    const maxIdleCount = 50; // 5秒无活动视为完成

    while (_state == EngineState.running) {
      if (await _scheduler.isEmpty) {
        idleCount++;
        if (idleCount >= maxIdleCount && futures.isEmpty) {
          // 长时间空闲且没有待处理请求，认为爬虫完成
          break;
        }
        await Future.delayed(Duration(milliseconds: 100));
        continue;
      }

      idleCount = 0; // 重置空闲计数
      final request = await _scheduler.dequeue();
      if (request == null) continue;

      final future = _requestPool.withResource(() => _processRequest(request));
      futures.add(future);

      // 移除已完成的future
      future.whenComplete(() => futures.remove(future));

      // 限制并发数
      if (futures.length >= _config.maxConcurrentRequests) {
        await Future.any(futures);
      }

      // 添加请求延迟
      if (_config.requestDelay > Duration.zero) {
        await Future.delayed(_config.requestDelay);
      }
    }

    // 等待所有剩余请求完成
    if (futures.isNotEmpty) {
      await Future.wait(futures.toList(), eagerError: true);
      futures.clear();
    }

    // 确保引擎状态正确并清理资源
    if (_state == EngineState.running) {
      _state = EngineState.stopped;
      // 确保调用stop()来清理资源
      await stop();
    }
  }

  /// 处理单个请求
  Future<void> _processRequest(Request request) async {
    _stats.totalRequests++;

    try {
      // 应用中间件处理请求
      final processedRequest = await _middlewareManager.processRequest(request);

      // 下载响应
      final response = await _downloader.download(processedRequest);

      // 应用中间件处理响应
      final processedResponse =
          await _middlewareManager.processResponse(response);

      // 解析响应
      final results = await _scrapy.parse(processedResponse);

      // 处理结果
      final newRequests = <Request>[];
      final items = <Item>[];

      for (final result in results) {
        if (result is Item) {
          items.add(result);
        } else if (result is Request) {
          newRequests.add(result);
        }
      }

      // 处理数据项
      for (final item in items) {
        await _processItem(item);
      }

      // 处理新请求（去重检查）
      if (newRequests.isNotEmpty) {
        List<Request> uniqueRequests = newRequests;

        if (_scrapy.enableDeduplication) {
          final duplicates = await _scrapy.areDuplicates(newRequests);
          uniqueRequests = [];
          for (var i = 0; i < newRequests.length; i++) {
            if (!duplicates[i]) {
              uniqueRequests.add(newRequests[i]);
            } else {
              DartScrapyLogger.info('🔄 发现的新请求已存在: ${newRequests[i].url}');
            }
          }
        }

        // 检查robots.txt规则并加入调度器
        for (final request in uniqueRequests) {
          final isAllowed = _config.obeyRobotsTxt
              ? await _scrapy.isUrlCompliant(request.url,
                  userAgent: _config.userAgent)
              : _scrapy.isUrlAllowed(request.url);
          if (isAllowed) {
            await _scheduler.enqueue(request);
            if (_scrapy.enableDeduplication) {
              await _scrapy.markAsProcessed(request);
            }
          } else {
            DartScrapyLogger.info('🚫 发现的新请求被robots.txt禁止: ${request.url}');
          }
        }
      }

      _stats.successfulRequests++;
      _stats.totalPages++;
    } catch (e, stackTrace) {
      _stats.failedRequests++;
      DartScrapyLogger.error('Request failed: ${request.url}', e, stackTrace);

      // 重试逻辑
      if (_config.enableRetry &&
          request.meta['retry_count'] < _config.maxRetries) {
        final retryRequest = request.copyWith(
          meta: Map<String, dynamic>.from(request.meta)
            ..['retry_count'] = (request.meta['retry_count'] ?? 0) + 1,
        );

        final delay =
            _config.retryDelay * (1 << (request.meta['retry_count'] ?? 0));
        await Future.delayed(delay);
        await _scheduler.enqueue(retryRequest);
      }
    }

    _statsController.add(_stats);
  }

  /// 处理数据项
  Future<void> _processItem(Item item) async {
    try {
      DartScrapyLogger.info('📦 Engine: 开始处理数据项: ${item.toMap()}');
      await _pipelineManager.processItem(item);
      _stats.totalItems++;
      _itemController.add(item);
      DartScrapyLogger.info('✅ Engine: 数据项处理完成');
    } catch (e, stackTrace) {
      DartScrapyLogger.error('❌ Engine: 处理数据项失败: $e', e, stackTrace);
    }
  }

  /// 清理资源
  Future<void> _cleanup() async {
    try {
      DartScrapyLogger.info('🧹 _cleanup: 开始清理资源...');
      await _scheduler.close();
      DartScrapyLogger.info('🧹 _cleanup: 调度器已关闭');
      await _downloader.close();
      DartScrapyLogger.info('🧹 _cleanup: 下载器已关闭');
      await _middlewareManager.close();
      DartScrapyLogger.info('🧹 _cleanup: 中间件已关闭');
      await _pipelineManager.close();
      DartScrapyLogger.info('🧹 _cleanup: 管道已关闭');
      if (!_itemController.isClosed) {
        await _itemController.close();
      }
      if (!_statsController.isClosed) {
        await _statsController.close();
      }
      await _scrapy.close();

      // 关闭Redis连接
      await RedisManager().close();
      DartScrapyLogger.info('🧹 _cleanup: Redis连接已关闭');

      DartScrapyLogger.info('🧹 _cleanup: 所有资源已清理完成');
    } catch (e) {
      DartScrapyLogger.error('❌ _cleanup: 清理资源时出错 - $e', e);
    }
  }

  /// 获取统计信息
  Map<String, dynamic> getStatistics() {
    return _stats.toMap();
  }

  /// 等待爬虫完成
  Future<void> waitForCompletion() async {
    const maxWaitTime = Duration(minutes: 5);
    final startTime = DateTime.now();

    DartScrapyLogger.info('🕒 waitForCompletion: 开始等待爬虫完成...');

    // 等待爬虫完成，最多等待5分钟
    while (_state == EngineState.running || _state == EngineState.starting) {
      if (DateTime.now().difference(startTime) > maxWaitTime) {
        DartScrapyLogger.warning('⏰ 等待超时，强制停止爬虫');
        break;
      }

      // 检查是否所有请求都已完成
      final isEmpty = await _scheduler.isEmpty;
      DartScrapyLogger.debug('🔄 检查状态: 引擎状态=$_state, 调度器空=$isEmpty');

      if (isEmpty &&
          (_state == EngineState.running || _state == EngineState.starting)) {
        DartScrapyLogger.info('✅ 检测到所有请求已完成，准备停止');
        break;
      }

      await Future.delayed(Duration(seconds: 1));
    }

    // 确保引擎最终停止 - 无论当前状态如何都调用stop
    DartScrapyLogger.info('🛑 waitForCompletion: 调用stop()进行清理');
    await stop();

    DartScrapyLogger.info('✅ waitForCompletion: 爬虫完成并清理完毕');
  }
}
