import 'dart:convert';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'request.dart';

/// 爬虫响应类，封装HTTP响应的所有信息
@immutable
class Response {
  final Request request;
  final int statusCode;
  final String? reasonPhrase;
  final Map<String, String> headers;
  final Uint8List body;
  final String? encoding;
  final String url;
  final Map<String, dynamic> meta;

  const Response({
    required this.request,
    required this.statusCode,
    this.reasonPhrase,
    this.headers = const {},
    required this.body,
    this.encoding,
    required this.url,
    this.meta = const {},
  });

  /// 获取响应文本内容
  String get text {
    try {
      // 尝试使用指定的编码
      if (encoding != null) {
        return utf8.decode(body, allowMalformed: true);
      }
      
      // 默认使用UTF-8解码
      return utf8.decode(body, allowMalformed: true);
    } catch (e) {
      // 如果UTF-8解码失败，尝试Latin-1作为后备
      try {
        return latin1.decode(body, allowInvalid: true);
      } catch (_) {
        // 最后使用原始字节解码
        return String.fromCharCodes(body);
      }
    }
  }

  /// 获取响应字节数据
  Uint8List get bytes => body;

  /// 复制响应并修改属性
  Response copyWith({
    Request? request,
    int? statusCode,
    String? reasonPhrase,
    Map<String, String>? headers,
    Uint8List? body,
    String? encoding,
    String? url,
    Map<String, dynamic>? meta,
  }) {
    return Response(
      request: request ?? this.request,
      statusCode: statusCode ?? this.statusCode,
      reasonPhrase: reasonPhrase ?? this.reasonPhrase,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      encoding: encoding ?? this.encoding,
      url: url ?? this.url,
      meta: meta ?? this.meta,
    );
  }

  @override
  String toString() {
    return 'Response{url: $url, statusCode: $statusCode}';
  }

  /// 将响应转换为JSON（不包含二进制数据）
  Map<String, dynamic> toJson() {
    return {
      'request': request.toJson(),
      'statusCode': statusCode,
      'reasonPhrase': reasonPhrase,
      'headers': headers,
      'encoding': encoding,
      'url': url,
      'meta': meta,
      'bodyLength': body.length,
    };
  }
}