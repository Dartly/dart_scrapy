import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../core/request.dart';
import '../core/response.dart';

/// 下载器接口
abstract class Downloader {
  /// 下载请求
  Future<Response> download(Request request);

  /// 关闭下载器
  Future<void> close();
}

/// HTTP下载器实现
class HttpDownloader implements Downloader {
  final http.Client _client;
  final Duration _timeout;
  final Map<String, String> _defaultHeaders;

  HttpDownloader({
    http.Client? client,
    Duration? timeout,
    Map<String, String>? defaultHeaders,
  }) : _client = client ?? http.Client(),
       _timeout = timeout ?? const Duration(seconds: 30),
       _defaultHeaders = defaultHeaders ?? {};

  @override
  Future<Response> download(Request request) async {
    try {
      final uri = Uri.parse(request.url);
      final headers = Map<String, String>.from(_defaultHeaders)
        ..addAll(request.headers);

      // 设置User-Agent
      if (!headers.containsKey('User-Agent')) {
        headers['User-Agent'] = 'DartScrapy/0.1.0 (+https://github.com/dartscrapy/dartscrapy)';
      }

      // 设置cookies
      if (request.cookies != null && request.cookies!.isNotEmpty) {
        final cookieString = request.cookies!.entries
            .map((e) => '${e.key}=${e.value}')
            .join('; ');
        headers['Cookie'] = cookieString;
      }

      late http.Response httpResponse;

      switch (request.method.toUpperCase()) {
        case 'GET':
          httpResponse = await _client
              .get(uri, headers: headers)
              .timeout(_timeout);
          break;
        case 'POST':
          final body = _prepareRequestBody(request);
          if (body != null) {
            headers['Content-Type'] = 'application/x-www-form-urlencoded';
          }
          httpResponse = await _client
              .post(uri, headers: headers, body: body)
              .timeout(_timeout);
          break;
        case 'PUT':
          final body = _prepareRequestBody(request);
          httpResponse = await _client
              .put(uri, headers: headers, body: body)
              .timeout(_timeout);
          break;
        case 'DELETE':
          httpResponse = await _client
              .delete(uri, headers: headers)
              .timeout(_timeout);
          break;
        case 'HEAD':
          httpResponse = await _client
              .head(uri, headers: headers)
              .timeout(_timeout);
          break;
        default:
          throw UnsupportedError('HTTP method ${request.method} not supported');
      }

      // 检测内容编码
      String? encoding;
      final contentType = httpResponse.headers['content-type'];
      if (contentType != null) {
        final charsetMatch = RegExp(r'charset=([^;]+)').firstMatch(contentType.toLowerCase());
        if (charsetMatch != null) {
          encoding = charsetMatch.group(1);
        }
      }
      
      return Response(
        request: request,
        statusCode: httpResponse.statusCode,
        reasonPhrase: httpResponse.reasonPhrase,
        headers: httpResponse.headers,
        body: httpResponse.bodyBytes,
        encoding: encoding ?? 'utf-8',
        url: httpResponse.request?.url.toString() ?? request.url,
        meta: request.meta,
      );
    } on TimeoutException catch (e) {
      throw DownloadException('Request timeout: ${request.url}', e);
    } on http.ClientException catch (e) {
      throw DownloadException('HTTP client error: ${e.message}', e);
    } catch (e) {
      throw DownloadException('Download failed: ${request.url}', e);
    }
  }

  @override
  Future<void> close() async {
    _client.close();
  }

  /// 准备请求体
  String? _prepareRequestBody(Request request) {
    if (request.body == null) return null;
    
    if (request.body is String) {
      return request.body as String;
    } else if (request.body is Map) {
      return (request.body as Map).entries
          .map((e) => '${Uri.encodeComponent(e.key.toString())}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
    } else {
      return json.encode(request.body);
    }
  }
}

/// 下载异常类
class DownloadException implements Exception {
  final String message;
  final dynamic cause;

  DownloadException(this.message, [this.cause]);

  @override
  String toString() => 'DownloadException: $message${cause != null ? '\nCaused by: $cause' : ''}';
}

/// 重试下载器装饰器
class RetryDownloader implements Downloader {
  final Downloader _downloader;
  final int _maxRetries;
  final Duration _retryDelay;

  RetryDownloader({
    required Downloader downloader,
    int maxRetries = 3,
    Duration? retryDelay,
  }) : _downloader = downloader,
       _maxRetries = maxRetries,
       _retryDelay = retryDelay ?? const Duration(seconds: 1);

  @override
  Future<Response> download(Request request) async {
    int attempts = 0;
    
    while (attempts <= _maxRetries) {
      try {
        return await _downloader.download(request);
      } catch (e) {
        attempts++;
        if (attempts > _maxRetries) {
          rethrow;
        }
        
        // 指数退避
        final delay = _retryDelay * (1 << (attempts - 1));
        await Future.delayed(delay);
      }
    }
    
    throw StateError('Retry loop completed unexpectedly');
  }

  @override
  Future<void> close() async {
    await _downloader.close();
  }
}

/// 限速下载器装饰器
class RateLimitedDownloader implements Downloader {
  final Downloader _downloader;
  final Duration _minInterval;
  DateTime? _lastRequestTime;

  RateLimitedDownloader({
    required Downloader downloader,
    required Duration minInterval,
  }) : _downloader = downloader,
       _minInterval = minInterval;

  @override
  Future<Response> download(Request request) async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minInterval) {
        final delay = _minInterval - elapsed;
        await Future.delayed(delay);
      }
    }

    _lastRequestTime = DateTime.now();
    return await _downloader.download(request);
  }

  @override
  Future<void> close() async {
    await _downloader.close();
  }
}

/// 随机速率下载器装饰器
class RandomRateDownloader implements Downloader {
  final Downloader _downloader;
  final Duration _minDelay;
  final Duration _maxDelay;
  DateTime? _lastRequestTime;

  RandomRateDownloader({
    required Downloader downloader,
    required Duration minDelay,
    required Duration maxDelay,
  }) : _downloader = downloader,
       _minDelay = minDelay,
       _maxDelay = maxDelay {
    if (minDelay > maxDelay) {
      throw ArgumentError('minDelay must be less than or equal to maxDelay');
    }
  }

  @override
  Future<Response> download(Request request) async {
    final now = DateTime.now();
    
    if (_lastRequestTime != null) {
      // 生成随机延迟时间
      final minMs = _minDelay.inMilliseconds;
      final maxMs = _maxDelay.inMilliseconds;
      final randomDelayMs = minMs + (maxMs - minMs) * _random.nextDouble();
      final randomDelay = Duration(milliseconds: randomDelayMs.round());
      
      final timeSinceLastRequest = now.difference(_lastRequestTime!);
      if (timeSinceLastRequest < randomDelay) {
        final delay = randomDelay - timeSinceLastRequest;
        await Future.delayed(delay);
      }
    }
    
    _lastRequestTime = DateTime.now();
    return await _downloader.download(request);
  }

  @override
  Future<void> close() async {
    await _downloader.close();
  }

  // 随机数生成器
  static final _random = Random();
}