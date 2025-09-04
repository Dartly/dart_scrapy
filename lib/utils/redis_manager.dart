import 'dart:async';
import 'package:redis/redis.dart';
import 'redis_config.dart';
import 'logger.dart';

/// Redis连接管理器
class RedisManager {
  static final RedisManager _instance = RedisManager._internal();
  factory RedisManager() => _instance;
  RedisManager._internal();

  RedisConfig? _config;
  Command? _command;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;

  /// 初始化Redis连接
  Future<void> init(RedisConfig config) async {
    _config = config;
    await _connect();
  }

  /// 获取Redis命令对象
  Future<Command?> getCommand() async {
    if (!_isConnected) {
      await _connect();
    }
    return _command;
  }

  /// 建立连接
  Future<void> _connect() async {
    if (_config == null) {
      throw Exception('RedisManager not initialized');
    }

    try {
      final conn = RedisConnection();
      final command = await conn.connect(
        _config!.host,
        _config!.port,
      );

      // 认证
      if (_config!.password != null) {
        await command.send_object(['AUTH', _config!.password]);
      }

      // 选择数据库
      if (_config!.database != 0) {
        await command.send_object(['SELECT', _config!.database]);
      }

      _command = command;
      _isConnected = true;
      _reconnectAttempts = 0;
      
      if (_reconnectTimer != null) {
        _reconnectTimer!.cancel();
        _reconnectTimer = null;
      }

      DartScrapyLogger.info('Redis connected successfully');
    } catch (e) {
      _isConnected = false;
      DartScrapyLogger.error('Failed to connect to Redis: $e');
      
      if (_config!.retryOnFailure && _reconnectAttempts < _maxReconnectAttempts) {
        _scheduleReconnect();
      }
      
      throw Exception('Failed to connect to Redis: $e');
    }
  }

  /// 重连机制
  void _scheduleReconnect() {
    if (_reconnectTimer != null) return;

    final delay = Duration(
      seconds: min(
        5 * (_reconnectAttempts + 1),
        30,
      ),
    );

    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      _reconnectAttempts++;
      
      try {
        await _connect();
        DartScrapyLogger.info('Redis reconnected successfully');
      } catch (e) {
        DartScrapyLogger.error('Redis reconnection failed: $e');
        if (_reconnectAttempts < _maxReconnectAttempts) {
          _scheduleReconnect();
        }
      }
    });
  }

  /// 检查连接状态
  bool get isConnected => _isConnected;

  /// 关闭连接
  Future<void> close() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    if (_command != null) {
      try {
        await _command!.get_connection().close();
        _command = null;
      } catch (e) {
        DartScrapyLogger.error('Error closing Redis connection: $e');
      }
    }
    
    _isConnected = false;
    DartScrapyLogger.info('Redis connection closed');
  }

  /// 健康检查
  Future<bool> healthCheck() async {
    if (!_isConnected) return false;
    
    try {
      final result = await _command?.send_object(['PING']);
      return result == 'PONG';
    } catch (e) {
      _isConnected = false;
      DartScrapyLogger.error('Redis health check failed: $e');
      return false;
    }
  }

  /// 获取连接信息
  String get connectionInfo {
    if (_config == null) return 'Not configured';
    return '${_config!.host}:${_config!.port}:${_config!.database}';
  }
}

/// 工具函数
int min(int a, int b) => a < b ? a : b;