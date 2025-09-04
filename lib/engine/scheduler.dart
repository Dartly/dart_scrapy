import 'dart:async';
import 'dart:collection';
import '../core/request.dart';

/// 请求调度器接口
abstract class Scheduler {
  /// 添加请求到调度器
  Future<void> enqueue(Request request);

  /// 从调度器获取下一个请求
  Future<Request?> dequeue();

  /// 检查调度器是否为空
  Future<bool> get isEmpty;

  /// 获取调度器中请求的数量
  Future<int> get length;

  /// 清空调度器
  Future<void> clear();

  /// 检查请求是否已存在（用于去重）
  Future<bool> hasSeen(Request request);

  /// 关闭调度器
  Future<void> close();
}

/// 内存请求调度器实现
class MemoryScheduler implements Scheduler {
  final Queue<Request> _queue = Queue<Request>();
  final Set<String> _seenRequests = <String>{};
  final Map<int, Queue<Request>> _priorityQueues = {};
  int _totalCount = 0;

  @override
  Future<void> enqueue(Request request) async {
    if (request.dontFilter || !await hasSeen(request)) {
      if (!request.dontFilter) {
        _seenRequests.add(_getRequestFingerprint(request));
      }
      
      final priority = request.priority;
      if (!_priorityQueues.containsKey(priority)) {
        _priorityQueues[priority] = Queue<Request>();
      }
      _priorityQueues[priority]!.add(request);
      _totalCount++;
    }
  }

  @override
  Future<Request?> dequeue() async {
    if (_totalCount == 0) return null;

    // 按优先级从高到低获取请求
    final priorities = _priorityQueues.keys.toList()..sort((a, b) => b.compareTo(a));
    
    for (final priority in priorities) {
      final queue = _priorityQueues[priority];
      if (queue != null && queue.isNotEmpty) {
        final request = queue.removeFirst();
        _totalCount--;
        return request;
      }
    }
    
    return null;
  }

  @override
  Future<bool> get isEmpty async => _totalCount == 0;

  @override
  Future<int> get length async => _totalCount;

  @override
  Future<void> clear() async {
    _queue.clear();
    _seenRequests.clear();
    _priorityQueues.clear();
    _totalCount = 0;
  }

  @override
  Future<bool> hasSeen(Request request) async {
    final fingerprint = _getRequestFingerprint(request);
    return _seenRequests.contains(fingerprint);
  }

  @override
  Future<void> close() async {
    await clear();
  }

  /// 生成请求的唯一指纹
  String _getRequestFingerprint(Request request) {
    return '${request.method}:${request.url}';
  }
}

// /// 持久化请求调度器（基于文件）
// class FileScheduler implements Scheduler {
//   final String _filePath;
//   final MemoryScheduler _memoryScheduler = MemoryScheduler();
//   bool _isInitialized = false;

//   FileScheduler(this._filePath);

//   @override
//   Future<void> enqueue(Request request) async {
//     await _ensureInitialized();
//     await _memoryScheduler.enqueue(request);
//     await _saveToFile();
//   }

//   @override
//   Future<Request?> dequeue() async {
//     await _ensureInitialized();
//     final request = await _memoryScheduler.dequeue();
//     if (request != null) {
//       await _saveToFile();
//     }
//     return request;
//   }

//   @override
//   Future<bool> get isEmpty async {
//     await _ensureInitialized();
//     return _memoryScheduler.isEmpty;
//   }

//   @override
//   Future<int> get length async {
//     await _ensureInitialized();
//     return _memoryScheduler.length;
//   }

//   @override
//   Future<void> clear() async {
//     await _ensureInitialized();
//     await _memoryScheduler.clear();
//     await _saveToFile();
//   }

//   @override
//   Future<bool> hasSeen(Request request) async {
//     await _ensureInitialized();
//     return _memoryScheduler.hasSeen(request);
//   }

//   @override
//   Future<void> close() async {
//     await _memoryScheduler.close();
//   }

//   /// 确保调度器已初始化
//   Future<void> _ensureInitialized() async {
//     if (!_isInitialized) {
//       await _loadFromFile();
//       _isInitialized = true;
//     }
//   }

//   /// 从文件加载请求队列
//   Future<void> _loadFromFile() async {
//     // TODO: 实现文件持久化
//     // 这里简化实现，实际应该使用文件I/O
//   }

//   /// 保存请求队列到文件
//   Future<void> _saveToFile() async {
//     // TODO: 实现文件持久化
//     // 这里简化实现，实际应该使用文件I/O
//   }
// }

/// 优先级请求调度器
class PriorityScheduler implements Scheduler {
  final MemoryScheduler _scheduler = MemoryScheduler();

  @override
  Future<void> enqueue(Request request) => _scheduler.enqueue(request);

  @override
  Future<Request?> dequeue() => _scheduler.dequeue();

  @override
  Future<bool> get isEmpty => _scheduler.isEmpty;

  @override
  Future<int> get length => _scheduler.length;

  @override
  Future<void> clear() => _scheduler.clear();

  @override
  Future<bool> hasSeen(Request request) => _scheduler.hasSeen(request);

  @override
  Future<void> close() => _scheduler.close();
}