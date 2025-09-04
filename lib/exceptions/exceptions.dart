/// DartScrapy框架的所有异常类

/// 基础异常类
abstract class DartScrapyException implements Exception {
  final String message;
  final dynamic cause;

  const DartScrapyException(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType: $message${cause != null ? '\nCaused by: $cause' : ''}';
}

/// 配置异常
class ConfigurationException extends DartScrapyException {
  ConfigurationException(String message, [dynamic cause]) : super(message, cause);
}

/// 爬虫异常
class SpiderException extends DartScrapyException {
  SpiderException(String message, [dynamic cause]) : super(message, cause);
}

/// 调度器异常
class SchedulerException extends DartScrapyException {
  SchedulerException(String message, [dynamic cause]) : super(message, cause);
}

/// 下载器异常
class DownloaderException extends DartScrapyException {
  DownloaderException(String message, [dynamic cause]) : super(message, cause);
}

/// 选择器异常
class SelectorException extends DartScrapyException {
  SelectorException(String message, [dynamic cause]) : super(message, cause);
}

/// 管道异常
class PipelineException extends DartScrapyException {
  PipelineException(String message, [dynamic cause]) : super(message, cause);
}

/// 中间件异常
class MiddlewareException extends DartScrapyException {
  MiddlewareException(String message, [dynamic cause]) : super(message, cause);
}

/// 验证异常
class ValidationException extends DartScrapyException {
  ValidationException(String message, [dynamic cause]) : super(message, cause);
}

/// 网络异常
class NetworkException extends DartScrapyException {
  NetworkException(String message, [dynamic cause]) : super(message, cause);
}

/// 超时异常
class TimeoutException extends DartScrapyException {
  TimeoutException(String message, [dynamic cause]) : super(message, cause);
}

/// 解析异常
class ParseException extends DartScrapyException {
  ParseException(String message, [dynamic cause]) : super(message, cause);
}

/// 存储异常
class StorageException extends DartScrapyException {
  StorageException(String message, [dynamic cause]) : super(message, cause);
}

/// 缓存异常
class CacheException extends DartScrapyException {
  CacheException(String message, [dynamic cause]) : super(message, cause);
}

/// 重试异常
class RetryExhaustedException extends DartScrapyException {
  final int maxRetries;
  final int actualRetries;

  RetryExhaustedException(
    String message, 
    this.maxRetries, 
    this.actualRetries, 
    [dynamic cause]
  ) : super(message, cause);

  @override
  String toString() => 
      '$runtimeType: $message\nMax retries: $maxRetries, Actual retries: $actualRetries${cause != null ? '\nCaused by: $cause' : ''}';
}

/// 限流异常
class RateLimitException extends DartScrapyException {
  final Duration retryAfter;

  RateLimitException(String message, this.retryAfter, [dynamic cause]) 
      : super(message, cause);

  @override
  String toString() => 
      '$runtimeType: $message\nRetry after: ${retryAfter.inSeconds}s${cause != null ? '\nCaused by: $cause' : ''}';
}

/// 资源不足异常
class ResourceException extends DartScrapyException {
  ResourceException(String message, [dynamic cause]) : super(message, cause);
}

/// 权限异常
class PermissionException extends DartScrapyException {
  PermissionException(String message, [dynamic cause]) : super(message, cause);
}

/// 数据异常
class DataException extends DartScrapyException {
  DataException(String message, [dynamic cause]) : super(message, cause);
}

/// 序列化异常
class SerializationException extends DartScrapyException {
  SerializationException(String message, [dynamic cause]) : super(message, cause);
}

/// 反序列化异常
class DeserializationException extends DartScrapyException {
  DeserializationException(String message, [dynamic cause]) : super(message, cause);
}

/// 并发异常
class ConcurrencyException extends DartScrapyException {
  ConcurrencyException(String message, [dynamic cause]) : super(message, cause);
}

/// 内存异常
class MemoryException extends DartScrapyException {
  MemoryException(String message, [dynamic cause]) : super(message, cause);
}

/// 文件异常
class FileException extends DartScrapyException {
  FileException(String message, [dynamic cause]) : super(message, cause);
}

/// 目录异常
class DirectoryException extends DartScrapyException {
  DirectoryException(String message, [dynamic cause]) : super(message, cause);
}

/// URL异常
class UrlException extends DartScrapyException {
  UrlException(String message, [dynamic cause]) : super(message, cause);
}

/// 编码异常
class EncodingException extends DartScrapyException {
  EncodingException(String message, [dynamic cause]) : super(message, cause);
}

/// 模板异常
class TemplateException extends DartScrapyException {
  TemplateException(String message, [dynamic cause]) : super(message, cause);
}

/// 扩展异常信息
extension ExceptionExtension on Exception {
  /// 获取异常的根本原因
  dynamic get rootCause {
    dynamic cause = this;
    while (cause is DartScrapyException && cause.cause != null) {
      cause = cause.cause;
    }
    return cause;
  }

  /// 检查是否为特定类型的异常
  bool isOfType<T extends DartScrapyException>() => this is T;

  /// 获取完整的异常链
  List<Exception> get exceptionChain {
    final chain = <Exception>[this];
    dynamic cause = this;
    while (cause is DartScrapyException && cause.cause != null) {
      if (cause.cause is Exception) {
        chain.add(cause.cause as Exception);
        cause = cause.cause;
      } else {
        break;
      }
    }
    return chain;
  }
}

/// 异常处理工具类
class ExceptionUtils {
  /// 包装异常为特定类型
  static T wrapException<T extends DartScrapyException>(
    dynamic exception, 
    String message, 
    T Function(String, dynamic) factory
  ) {
    return factory(message, exception);
  }

  /// 检查异常是否为网络相关
  static bool isNetworkException(dynamic exception) {
    return exception is NetworkException ||
           exception is TimeoutException ||
           exception is DownloaderException;
  }

  /// 检查异常是否为解析相关
  static bool isParseException(dynamic exception) {
    return exception is ParseException ||
           exception is SelectorException ||
           exception is DataException;
  }

  /// 检查异常是否为存储相关
  static bool isStorageException(dynamic exception) {
    return exception is StorageException ||
           exception is PipelineException ||
           exception is FileException;
  }

  /// 获取异常的错误码
  static String getErrorCode(dynamic exception) {
    if (exception is DartScrapyException) {
      return exception.runtimeType.toString();
    }
    return 'UNKNOWN_ERROR';
  }

  /// 获取异常的HTTP状态码
  static int? getHttpStatusCode(dynamic exception) {
    if (exception is DownloaderException) {
      // 这里应该从异常中提取HTTP状态码
      // 简化实现，返回null
    }
    return null;
  }

  /// 判断异常是否应该重试
  static bool shouldRetry(dynamic exception, {int? maxRetries}) {
    if (exception is RetryExhaustedException) {
      return false;
    }
    
    if (exception is RateLimitException) {
      return true;
    }
    
    if (isNetworkException(exception)) {
      return true;
    }
    
    final statusCode = getHttpStatusCode(exception);
    if (statusCode != null) {
      return statusCode >= 500 || statusCode == 429 || statusCode == 408;
    }
    
    return false;
  }
}