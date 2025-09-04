import 'dart:async';
import '../core/request.dart';
import '../core/response.dart';
import '../core/item.dart';
import '../utils/robots_txt.dart';
import '../utils/duplicate_filter.dart';
import '../utils/duplicate_filter_factory.dart';
import '../utils/redis_config.dart';
import '../utils/redis_manager.dart';
import '../utils/logger.dart';

/// Scrapy状态枚举
enum ScrapyState {
  idle,
  running,
  paused,
  stopped,
  error,
}

/// Scrapy基类，所有具体的爬虫都应该继承此类
abstract class Scrapy {
  String get name;
  List<String> get startUrls;
  List<String> get allowedDomains;
  int get downloadDelay => 0;
  int get concurrentRequests => 16;
  bool get randomizeDownloadDelay => true;
  bool get obeyRobotsTxt => true;
  bool get enableDeduplication => true;
  DuplicateFilterType get duplicateFilterType => DuplicateFilterType.hybrid;
  RedisConfig? get redisConfig => null;
  Map<String, dynamic> get duplicateConfig => {};
  DuplicateFilter? _duplicateFilter;
  ScrapyState _state = ScrapyState.idle;
  ScrapyState get state => _state;
  final Map<String, dynamic> settings = {};

  Future<void> init(Map<String, dynamic> settings) async {
    this.settings.addAll(settings);
    await _initDuplicateFilter();
    await onInit();
  }

  Future<void> _initDuplicateFilter() async {
    if (!enableDeduplication) return;
    try {
      if (redisConfig != null &&
          (duplicateFilterType == DuplicateFilterType.redis ||
              duplicateFilterType == DuplicateFilterType.hybrid)) {
        await RedisManager().init(redisConfig!);
      }
      _duplicateFilter = DuplicateFilterFactory.create(
        spiderName: name,
        config: DuplicateFilterConfig.fromMap(duplicateConfig),
        redisConfig: redisConfig,
      );
    } catch (e) {
      DartScrapyLogger.warning(
          'Failed to initialize Redis duplicate filter: $e, falling back to memory filter');
      _duplicateFilter = DuplicateFilterFactory.create(
        spiderName: name,
        config: DuplicateFilterConfig.fromMap(duplicateConfig),
      );
    }
  }

  Future<void> onInit() async {}
  Future<void> start() async {
    if (_state != ScrapyState.idle && _state != ScrapyState.stopped) {
      throw StateError('Scrapy is already running or paused');
    }
    _state = ScrapyState.running;
    await onStart();
  }

  Future<void> onStart() async {}
  Future<void> pause() async {
    if (_state == ScrapyState.running) {
      _state = ScrapyState.paused;
      await onPause();
    }
  }

  Future<void> onPause() async {}
  Future<void> resume() async {
    if (_state == ScrapyState.paused) {
      _state = ScrapyState.running;
      await onResume();
    }
  }

  Future<void> onResume() async {}
  Future<void> stop() async {
    _state = ScrapyState.stopped;
    await onStop();
  }

  Future<void> onStop() async {}
  Future<Iterable<dynamic>> parse(Response response) async {
    try {
      final results = await handleResponse(response);
      return results;
    } catch (e) {
      _state = ScrapyState.error;
      await onError(e, response);
      rethrow;
    }
  }

  Future<Iterable<dynamic>> handleResponse(Response response);
  List<Request> startRequests() {
    return startUrls.map((url) => Request.get(url)).toList();
  }

  bool isUrlAllowed(String url) {
    if (allowedDomains.isEmpty) return true;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host;
    return allowedDomains
        .any((domain) => host == domain || host.endsWith('.$domain'));
  }

  Future<void> onError(dynamic error, Response? response) async {}
  Future<bool> isUrlAllowedByRobots(String url,
      {String userAgent = '*'}) async {
    if (!obeyRobotsTxt) return true;
    return await RobotsTxtChecker.isAllowed(url, userAgent: userAgent);
  }

  Future<bool> isUrlCompliant(String url, {String userAgent = '*'}) async {
    if (!isUrlAllowed(url)) return false;
    return await isUrlAllowedByRobots(url, userAgent: userAgent);
  }

  Future<void> close() async {
    await RobotsTxtChecker.close();
    if (_duplicateFilter != null) {
      await _duplicateFilter!.close();
    }
    await RedisManager().close();
    await onClose();
  }

  Future<void> onClose() async {}
  Future<void> processItem(Item item) async {
    await onItemProcessed(item);
  }

  Future<void> onItemProcessed(Item item) async {}
  Future<bool> isDuplicate(Request request) async {
    if (!enableDeduplication || _duplicateFilter == null) return false;
    return await _duplicateFilter!.isDuplicate(request);
  }

  Future<List<bool>> areDuplicates(List<Request> requests) async {
    if (!enableDeduplication || _duplicateFilter == null) {
      return List<bool>.filled(requests.length, false);
    }
    return await _duplicateFilter!.areDuplicates(requests);
  }

  Future<void> markAsProcessed(Request request) async {
    if (!enableDeduplication || _duplicateFilter == null) return;
    await _duplicateFilter!.markAsProcessed(request);
  }

  Future<void> markBatchAsProcessed(List<Request> requests) async {
    if (!enableDeduplication || _duplicateFilter == null) return;
    await _duplicateFilter!.markBatchAsProcessed(requests);
  }

  DuplicateFilterStats? getDuplicateStats() {
    if (!enableDeduplication || _duplicateFilter == null) return null;
    return _duplicateFilter!.getStats();
  }

  Future<void> clearDuplicates() async {
    if (!enableDeduplication || _duplicateFilter == null) return;
    await _duplicateFilter!.clear();
  }

  Future<Request> processRequest(Request request) async {
    return await onRequestProcessed(request);
  }

  Future<Request> onRequestProcessed(Request request) async => request;
}
