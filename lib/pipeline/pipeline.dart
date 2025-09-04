import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/item.dart';
import '../utils/logger.dart';


/// 管道接口
abstract class Pipeline {
  /// 管道名称
  String get name;

  /// 打开管道
  Future<void> open() async {}

  /// 处理数据项
  Future<void> processItem(Item item);

  /// 关闭管道
  Future<void> close() async {}

  /// 管道优先级
  int get priority => 100;
}

/// 控制台输出管道
class ConsolePipeline implements Pipeline {
  @override
  String get name => 'ConsolePipeline';

  @override
  int get priority => 10;

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> processItem(Item item) async {
    DartScrapyLogger.info('[ConsolePipeline] Item: ${item.toMap()}');
  }
}

/// CSV输出管道
class CsvPipeline implements Pipeline {
  final String _filePath;
  final List<String> _headers;
  bool _headersWritten = false;
  late final File _file;
  late final IOSink _sink;
  bool _isOpen = false;

  CsvPipeline(this._filePath, this._headers);

  @override
  String get name => 'CsvPipeline';

  @override
  int get priority => 100;

  @override
  Future<void> open() async {
    if (_isOpen) return;
    
    // 确保目录存在
    final directory = File(_filePath).parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    _file = File(_filePath);
    _sink = _file.openWrite(encoding: utf8);
    _isOpen = true;
  }

  @override
  Future<void> processItem(Item item) async {
    if (!_isOpen) await open();
    
    final data = item.toMap();
    
    if (!_headersWritten) {
      _sink.writeln(_headers.join(','));
      _headersWritten = true;
    }
    
    final values = _headers.map((header) {
      final value = data[header]?.toString() ?? '';
      return '"${value.replaceAll('"', '""')}"';
    }).join(',');
    
    _sink.writeln(values);
  }

  @override
  Future<void> close() async {
    if (_isOpen) {
      DartScrapyLogger.info('📁 CsvPipeline: 开始关闭文件 $_filePath');
      await _sink.close();
      final file = File(_filePath);
      if (await file.exists()) {
        final size = await file.length();
        DartScrapyLogger.info('✅ CsvPipeline: 写入文件成功 - ${file.absolute.path} (大小: $size 字节)');
      } else {
        DartScrapyLogger.warning('⚠️ CsvPipeline: 文件不存在 $_filePath');
      }
      _isOpen = false;
    }
  }
}

/// 数据验证管道
class ValidationPipeline implements Pipeline {
  final List<String> _requiredFields;

  ValidationPipeline(this._requiredFields);

  @override
  String get name => 'ValidationPipeline';

  @override
  int get priority => 200;

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}


  @override
  Future<void> processItem(Item item) async {
    final data = item.toMap();
    
    for (final field in _requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        throw ValidationException('Required field "$field" is missing or null');
      }
    }
  }
}

/// 数据清洗管道
class CleaningPipeline implements Pipeline {
  // ignore: unused_field
  final Map<String, Function> _cleaners;

  CleaningPipeline(this._cleaners);

  @override
  String get name => 'CleaningPipeline';

  @override
  int get priority => 300;

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> processItem(Item item) async {
    // CleaningPipeline当前实现有问题，暂时跳过数据清洗
    // 后续需要实现正确的数据传递机制
  }
}

/// 管道管理器
class PipelineManager {
  final List<Pipeline> _pipelines = [];
  bool _isOpen = false;

  /// 添加管道
  void addPipeline(Pipeline pipeline) {
    _pipelines.add(pipeline);
    _pipelines.sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// 打开所有管道
  Future<void> open() async {
    DartScrapyLogger.info('🧪 PipelineManager: 开始打开所有管道... 管道数量: ${_pipelines.length}');
    if (_isOpen) {
      DartScrapyLogger.info('🧪 PipelineManager: 管道已处于打开状态');
      return;
    }
    
    for (final pipeline in _pipelines) {
      DartScrapyLogger.info('🧪 PipelineManager: 正在打开管道 ${pipeline.name}');
      try {
        await pipeline.open();
        DartScrapyLogger.info('✅ PipelineManager: 管道 ${pipeline.name} 已打开');
      } catch (e) {
        DartScrapyLogger.error('❌ PipelineManager: 打开管道 ${pipeline.name} 失败: $e', e);
        rethrow;
      }
    }
    _isOpen = true;
    DartScrapyLogger.info('🧪 PipelineManager: 所有管道已打开');
  }

  /// 处理数据项
  Future<void> processItem(Item item) async {
    if (!_isOpen) await open();
    
    for (final pipeline in _pipelines) {
      try {
        await pipeline.processItem(item);
      } catch (e) {
        throw PipelineException('Pipeline ${pipeline.name} failed: $e');
      }
    }
  }

  /// 关闭所有管道
  Future<void> close() async {
    DartScrapyLogger.info('🧪 PipelineManager: 开始关闭所有管道... 当前管道数量: ${_pipelines.length}');
    if (_isOpen) {
      for (final pipeline in _pipelines) {
        DartScrapyLogger.info('🧪 PipelineManager: 正在关闭管道 ${pipeline.name}');
        try {
          await pipeline.close();
          DartScrapyLogger.info('✅ PipelineManager: 管道 ${pipeline.name} 已关闭');
        } catch (e) {
          DartScrapyLogger.error('❌ PipelineManager: 关闭管道 ${pipeline.name} 失败: $e', e);
        }
      }
      _isOpen = false;
      DartScrapyLogger.info('🧪 PipelineManager: 所有管道已关闭');
    } else {
      DartScrapyLogger.info('🧪 PipelineManager: 管道已处于关闭状态');
    }
  }
}

/// 验证异常类
class ValidationException implements Exception {
  final String message;

  ValidationException(this.message);

  @override
  String toString() => 'ValidationException: $message';
}

/// 管道异常类
class PipelineException implements Exception {
  final String message;

  PipelineException(this.message);

  @override
  String toString() => 'PipelineException: $message';
}