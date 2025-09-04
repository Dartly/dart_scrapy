import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';

/// 日志级别枚举
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// 日志记录器配置
class LoggerConfig {
  final LogLevel level;
  final String? logFile;
  final bool consoleOutput;
  final bool fileOutput;
  final int maxFileSizeMB;
  final int maxFiles;

  const LoggerConfig({
    this.level = LogLevel.info,
    this.logFile,
    this.consoleOutput = true,
    this.fileOutput = false,
    this.maxFileSizeMB = 10,
    this.maxFiles = 5,
  });
}

/// 自定义日志记录器
class DartScrapyLogger {
  static DartScrapyLogger? _instance;
  late final Logger _logger;
  late final LoggerConfig _config;
  File? _logFile;

  DartScrapyLogger._(LoggerConfig config) {
    _config = config;
    _logger = Logger('DartScrapy');
    
    // 配置日志级别
    Logger.root.level = _convertLogLevel(config.level);
    
    // 只为根logger添加一个监听器，避免重复
    if (config.consoleOutput || (config.fileOutput && config.logFile != null)) {
      Logger.root.onRecord.listen((record) {
        if (config.consoleOutput) {
          _printToConsole(record);
        }
        if (config.fileOutput && config.logFile != null) {
          _writeToFile(record);
        }
      });
    }
    
    // 初始化文件日志
    if (config.fileOutput && config.logFile != null) {
      _setupFileLogging();
    }
  }

  /// 初始化日志记录器
  static void initialize(LoggerConfig config) {
    _instance = DartScrapyLogger._(config);
  }

  /// 获取日志记录器实例
  static DartScrapyLogger get instance {
    if (_instance == null) {
      initialize(const LoggerConfig());
    }
    return _instance!;
  }

  /// 记录调试信息
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    instance._logger.fine(message, error, stackTrace);
  }

  /// 记录一般信息
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    instance._logger.info(message, error, stackTrace);
  }

  /// 记录警告信息
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    instance._logger.warning(message, error, stackTrace);
  }

  /// 记录错误信息
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    instance._logger.severe(message, error, stackTrace);
  }

  /// 记录关键错误信息
  static void critical(String message, [Object? error, StackTrace? stackTrace]) {
    instance._logger.shout(message, error, stackTrace);
  }

  /// 转换日志级别
  Level _convertLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Level.FINE;
      case LogLevel.info:
        return Level.INFO;
      case LogLevel.warning:
        return Level.WARNING;
      case LogLevel.error:
        return Level.SEVERE;
      case LogLevel.critical:
        return Level.SHOUT;
    }
  }

  /// 设置文件日志记录
  Future<void> _setupFileLogging() async {
    try {
      _logFile = File(_config.logFile!);
      final directory = _logFile!.parent;
      
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      await _rotateLogs();
    } catch (e) {
      print('Failed to setup file logging: $e');
    }
  }

  /// 日志轮转
  Future<void> _rotateLogs() async {
    if (_logFile == null) return;
    
    try {
      final file = _logFile!;
      if (await file.exists()) {
        final stat = await file.stat();
        final fileSizeMB = stat.size / (1024 * 1024);
        
        if (fileSizeMB >= _config.maxFileSizeMB) {
          // 重命名当前日志文件
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final backupFile = File('${file.path}.$timestamp');
          await file.rename(backupFile.path);
          
          // 清理旧日志文件
          await _cleanupOldLogs();
        }
      }
    } catch (e, stackTrace) {
      DartScrapyLogger.error('Failed to rotate logs', e, stackTrace);
    }
  }

  /// 清理旧日志文件
  Future<void> _cleanupOldLogs() async {
    if (_logFile == null) return;
    
    try {
      final directory = _logFile!.parent;
      final files = await directory.list().where((entity) {
        return entity is File && entity.path.startsWith(_logFile!.path);
      }).toList();
      
      if (files.length > _config.maxFiles) {
        files.sort((a, b) => a.path.compareTo(b.path));
        final filesToDelete = files.take(files.length - _config.maxFiles);
        
        for (final file in filesToDelete) {
          await file.delete();
        }
      }
    } catch (e, stackTrace) {
      DartScrapyLogger.error('Failed to cleanup old logs', e, stackTrace);
    }
  }

  /// 打印到控制台
  void _printToConsole(LogRecord record) {
    final level = record.level.name.padRight(7);
    final time = record.time.toString().substring(0, 19);
    final message = record.message;
    
    String colorCode;
    switch (record.level) {
      case Level.FINE:
      case Level.FINER:
      case Level.FINEST:
        colorCode = '\x1B[36m'; // Cyan
        break;
      case Level.INFO:
        colorCode = '\x1B[32m'; // Green
        break;
      case Level.WARNING:
        colorCode = '\x1B[33m'; // Yellow
        break;
      case Level.SEVERE:
        colorCode = '\x1B[31m'; // Red
        break;
      case Level.SHOUT:
        colorCode = '\x1B[35m'; // Magenta
        break;
      default:
        colorCode = '\x1B[0m'; // Reset
    }
    
    final resetCode = '\x1B[0m';
    
    if (record.error != null) {
      print('$colorCode[$time] $level $message$resetCode');
      print('$colorCode  Error: ${record.error}$resetCode');
      if (record.stackTrace != null) {
        print('$colorCode  StackTrace: ${record.stackTrace}$resetCode');
      }
    } else {
      print('$colorCode[$time] $level $message$resetCode');
    }
  }

  /// 写入文件
  void _writeToFile(LogRecord record) {
    if (_logFile == null) return;
    
    final level = record.level.name.padRight(7);
    final time = record.time.toString().substring(0, 19);
    final message = record.message;
    
    final buffer = StringBuffer();
    buffer.writeln('[$time] $level $message');
    
    if (record.error != null) {
      buffer.writeln('  Error: ${record.error}');
    }
    
    if (record.stackTrace != null) {
      buffer.writeln('  StackTrace: ${record.stackTrace}');
    }
    
    // 使用append模式写入文件，避免StreamSink冲突
    _logFile!.writeAsString(buffer.toString(), mode: FileMode.append);
  }

  /// 关闭日志记录器
  static Future<void> close() async {
    // 不再需要关闭fileSink，因为我们使用writeAsString
  }
}

/// 性能监控器
class PerformanceMonitor {
  static final Map<String, Stopwatch> _timers = {};
  static final Map<String, int> _counters = {};

  /// 开始计时
  static void startTimer(String name) {
    _timers[name] = Stopwatch()..start();
  }

  /// 停止计时并记录
  static void stopTimer(String name) {
    final timer = _timers[name];
    if (timer != null) {
      timer.stop();
      DartScrapyLogger.info('Timer $name: ${timer.elapsedMilliseconds}ms');
      _timers.remove(name);
    }
  }

  /// 增加计数器
  static void incrementCounter(String name, [int value = 1]) {
    _counters[name] = (_counters[name] ?? 0) + value;
  }

  /// 获取计数器值
  static int getCounter(String name) => _counters[name] ?? 0;

  /// 重置计数器
  static void resetCounter(String name) {
    _counters.remove(name);
  }

  /// 获取所有性能数据
  static Map<String, dynamic> getPerformanceData() {
    return {
      'counters': Map.from(_counters),
      'active_timers': _timers.keys.toList(),
    };
  }
}

/// 异常处理工具类
class ExceptionHandler {
  /// 处理异常并记录日志
  static void handleException(
    dynamic exception,
    StackTrace stackTrace, {
    String? context,
    bool rethrowException = false,
  }) {
    final message = context != null ? '$context: $exception' : exception.toString();
    
    if (exception is TimeoutException) {
      DartScrapyLogger.warning(message, exception, stackTrace);
    } else if (exception is IOException) {
      DartScrapyLogger.error(message, exception, stackTrace);
    } else {
      DartScrapyLogger.error(message, exception, stackTrace);
    }
    
    if (rethrowException) {
      throw exception;
    }
  }

  /// 包装异步函数，添加异常处理
  static Future<T> safeExecute<T>(
    Future<T> Function() operation, {
    String? context,
    T? defaultValue,
    bool logException = true,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      if (logException) {
        handleException(e, stackTrace, context: context);
      }
      
      if (defaultValue != null) {
        return defaultValue;
      }
      rethrow;
    }
  }
}