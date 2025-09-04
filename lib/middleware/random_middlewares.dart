import 'dart:math';
import '../core/request.dart';
import '../core/response.dart';
import 'package:dart_scrapy/utils/logger.dart';
import 'middleware.dart';

/// 随机代理池中间件
class RandomProxyMiddleware extends DownloadMiddleware {
  final List<String> proxyList;
  final Random _random = Random();

  RandomProxyMiddleware(this.proxyList);

  @override
  Future<Request> processRequest(Request request) async {
    if (proxyList.isNotEmpty) {
      final proxy = proxyList[_random.nextInt(proxyList.length)];
      request = request.copyWith(meta: {...request.meta, 'proxy': proxy});
      DartScrapyLogger.debug('使用代理: $proxy');
    }
    return request;
  }

  @override
  String get name => 'RandomProxyMiddleware';
  @override
  int get priority => 5;
  @override
  Future<Response> processResponse(Response response) async => response;
  @override
  Future<dynamic> processException(dynamic exception, Request request) async =>
      throw exception;
}

/// 随机User-Agent中间件
class RandomUserAgentMiddleware extends DownloadMiddleware {
  final List<String> userAgentList;
  final Random _random = Random();

  RandomUserAgentMiddleware(this.userAgentList);

  @override
  String get name => 'RandomUserAgentMiddleware';
  @override
  int get priority => 8;
  @override
  Future<Request> processRequest(Request request) async {
    if (userAgentList.isNotEmpty) {
      final ua = userAgentList[_random.nextInt(userAgentList.length)];
      final headers = {...request.headers, 'User-Agent': ua};
      request = request.copyWith(headers: headers);
      DartScrapyLogger.debug('使用User-Agent: $ua');
    }
    return request;
  }

  @override
  Future<Response> processResponse(Response response) async => response;
  @override
  Future<dynamic> processException(dynamic exception, Request request) async =>
      throw exception;
}
