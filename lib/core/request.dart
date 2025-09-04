import 'package:meta/meta.dart';

/// 爬虫请求类，封装HTTP请求的所有信息
@immutable
class Request {
  final String url;
  final String method;
  final Map<String, String> headers;
  final dynamic body;
  final Map<String, dynamic> meta;
  final String? callback;
  final int priority;
  final bool dontFilter;
  final String? encoding;
  final Map<String, dynamic>? cookies;

  const Request({
    required this.url,
    this.method = 'GET',
    this.headers = const {},
    this.body,
    this.meta = const {},
    this.callback,
    this.priority = 0,
    this.dontFilter = false,
    this.encoding,
    this.cookies,
  });

  /// 创建GET请求
  factory Request.get(String url, {
    Map<String, String> headers = const {},
    Map<String, dynamic> meta = const {},
    String? callback,
    int priority = 0,
    bool dontFilter = false,
  }) {
    return Request(
      url: url,
      method: 'GET',
      headers: headers,
      meta: meta,
      callback: callback,
      priority: priority,
      dontFilter: dontFilter,
    );
  }

  /// 创建POST请求
  factory Request.post(String url, {
    dynamic body,
    Map<String, String> headers = const {},
    Map<String, dynamic> meta = const {},
    String? callback,
    int priority = 0,
    bool dontFilter = false,
  }) {
    return Request(
      url: url,
      method: 'POST',
      body: body,
      headers: headers,
      meta: meta,
      callback: callback,
      priority: priority,
      dontFilter: dontFilter,
    );
  }

  /// 复制请求并修改属性
  Request copyWith({
    String? url,
    String? method,
    Map<String, String>? headers,
    dynamic body,
    Map<String, dynamic>? meta,
    String? callback,
    int? priority,
    bool? dontFilter,
    String? encoding,
    Map<String, dynamic>? cookies,
  }) {
    return Request(
      url: url ?? this.url,
      method: method ?? this.method,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      meta: meta ?? this.meta,
      callback: callback ?? this.callback,
      priority: priority ?? this.priority,
      dontFilter: dontFilter ?? this.dontFilter,
      encoding: encoding ?? this.encoding,
      cookies: cookies ?? this.cookies,
    );
  }

  @override
  String toString() {
    return 'Request{url: $url, method: $method, priority: $priority}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Request &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          method == other.method;

  @override
  int get hashCode => url.hashCode ^ method.hashCode;

  /// 将请求转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'method': method,
      'headers': headers,
      'body': body,
      'meta': meta,
      'callback': callback,
      'priority': priority,
      'dontFilter': dontFilter,
      'encoding': encoding,
      'cookies': cookies,
    };
  }

  /// 从JSON创建请求
  factory Request.fromJson(Map<String, dynamic> json) {
    return Request(
      url: json['url'] as String,
      method: json['method'] as String? ?? 'GET',
      headers: Map<String, String>.from(json['headers'] ?? {}),
      body: json['body'],
      meta: Map<String, dynamic>.from(json['meta'] ?? {}),
      callback: json['callback'] as String?,
      priority: json['priority'] as int? ?? 0,
      dontFilter: json['dontFilter'] as bool? ?? false,
      encoding: json['encoding'] as String?,
      cookies: json['cookies'] as Map<String, dynamic>?,
    );
  }
}