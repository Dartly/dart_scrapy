import 'dart:async';
import '../core/request.dart';
import '../core/response.dart';

/// 中间件接口
abstract class Middleware {
  /// 中间件名称
  String get name;

  /// 中间件优先级（数值越小优先级越高）
  int get priority => 100;

  /// 关闭中间件
  Future<void> close() async {}
}

/// 下载中间件接口
abstract class DownloadMiddleware extends Middleware {
  /// 处理请求
  Future<Request> processRequest(Request request);

  /// 处理响应
  Future<Response> processResponse(Response response);

  /// 处理异常
  Future<dynamic> processException(dynamic exception, Request request);
}

/// 爬虫中间件接口
abstract class SpiderMiddleware extends Middleware {
  /// 处理输入（请求或响应）
  Future<dynamic> processInput(dynamic input);

  /// 处理输出（Item或Request）
  Future<dynamic> processOutput(dynamic output);
}

/// 用户代理中间件
class UserAgentMiddleware extends DownloadMiddleware {
  final String _userAgent;

  UserAgentMiddleware({String? userAgent})
      : _userAgent = userAgent ?? 'DartScrapy/0.1.0 (+https://github.com/dartscrapy/dartscrapy)';

  @override
  String get name => 'UserAgentMiddleware';

  @override
  int get priority => 10;

  @override
  Future<Request> processRequest(Request request) async {
    final headers = Map<String, String>.from(request.headers);
    if (!headers.containsKey('User-Agent')) {
      headers['User-Agent'] = _userAgent;
    }
    return request.copyWith(headers: headers);
  }

  @override
  Future<Response> processResponse(Response response) async {
    return response;
  }

  @override
  Future<dynamic> processException(dynamic exception, Request request) async {
    throw exception;
  }
}

/// 重试中间件
class RetryMiddleware extends DownloadMiddleware {
  final int _maxRetries;
  final List<int> _retryHttpCodes;
  final Duration _retryDelay;

  RetryMiddleware({
    int maxRetries = 3,
    List<int>? retryHttpCodes,
    Duration? retryDelay,
  }) : _maxRetries = maxRetries,
       _retryHttpCodes = retryHttpCodes ?? [500, 502, 503, 504, 408, 429],
       _retryDelay = retryDelay ?? const Duration(seconds: 1);

  @override
  String get name => 'RetryMiddleware';

  @override
  int get priority => 20;

  @override
  Future<Request> processRequest(Request request) async {
    return request;
  }

  @override
  Future<Response> processResponse(Response response) async {
    if (_retryHttpCodes.contains(response.statusCode)) {
      final retryCount = (response.request.meta['retry_count'] ?? 0) as int;
      if (retryCount < _maxRetries) {
        final newRequest = response.request.copyWith(
          meta: Map<String, dynamic>.from(response.request.meta)
            ..['retry_count'] = retryCount + 1,
        );
        
        // 指数退避
        final delay = _retryDelay * (1 << retryCount);
        await Future.delayed(delay);
        
        throw RetryException(newRequest, 'HTTP ${response.statusCode}');
      }
    }
    return response;
  }

  @override
  Future<dynamic> processException(dynamic exception, Request request) async {
    if (exception is! RetryException) {
      final retryCount = (request.meta['retry_count'] ?? 0) as int;
      if (retryCount < _maxRetries) {
        final newRequest = request.copyWith(
          meta: Map<String, dynamic>.from(request.meta)
            ..['retry_count'] = retryCount + 1,
        );
        
        final delay = _retryDelay * (1 << retryCount);
        await Future.delayed(delay);
        
        throw RetryException(newRequest, exception.toString());
      }
    }
    throw exception;
  }
}

/// 重试异常类
class RetryException implements Exception {
  final Request request;
  final String reason;

  RetryException(this.request, this.reason);

  @override
  String toString() => 'RetryException: $reason';
}

/// 中间件管理器
class MiddlewareManager {
  final List<DownloadMiddleware> _downloadMiddlewares = [];
  final List<SpiderMiddleware> _spiderMiddlewares = [];

  /// 添加下载中间件
  void addDownloadMiddleware(DownloadMiddleware middleware) {
    _downloadMiddlewares.add(middleware);
    _downloadMiddlewares.sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// 添加爬虫中间件
  void addSpiderMiddleware(SpiderMiddleware middleware) {
    _spiderMiddlewares.add(middleware);
    _spiderMiddlewares.sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// 处理请求（下载中间件）
  Future<Request> processRequest(Request request) async {
    var currentRequest = request;
    for (final middleware in _downloadMiddlewares) {
      try {
        currentRequest = await middleware.processRequest(currentRequest);
      } catch (e) {
        await middleware.processException(e, currentRequest);
        rethrow;
      }
    }
    return currentRequest;
  }

  /// 处理响应（下载中间件）
  Future<Response> processResponse(Response response) async {
    var currentResponse = response;
    for (final middleware in _downloadMiddlewares) {
      try {
        currentResponse = await middleware.processResponse(currentResponse);
      } catch (e) {
        final newException = await middleware.processException(e, currentResponse.request);
        if (newException is RetryException) {
          throw newException;
        }
        rethrow;
      }
    }
    return currentResponse;
  }

  /// 处理输入（爬虫中间件）
  Future<dynamic> processInput(dynamic input) async {
    var currentInput = input;
    for (final middleware in _spiderMiddlewares) {
      currentInput = await middleware.processInput(currentInput);
    }
    return currentInput;
  }

  /// 处理输出（爬虫中间件）
  Future<dynamic> processOutput(dynamic output) async {
    var currentOutput = output;
    for (final middleware in _spiderMiddlewares) {
      currentOutput = await middleware.processOutput(currentOutput);
    }
    return currentOutput;
  }

  /// 关闭所有中间件
  Future<void> close() async {
    for (final middleware in _downloadMiddlewares) {
      await middleware.close();
    }
    for (final middleware in _spiderMiddlewares) {
      await middleware.close();
    }
  }
}