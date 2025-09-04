/// Redis配置类
class RedisConfig {
  final String host;
  final int port;
  final String? password;
  final int database;
  final Duration connectionTimeout;
  final Duration operationTimeout;
  final int maxConnections;
  final bool ssl;
  final bool retryOnFailure;
  final int maxRetries;

  const RedisConfig({
    this.host = 'localhost',
    this.port = 6379,
    this.password,
    this.database = 0,
    this.connectionTimeout = const Duration(seconds: 5),
    this.operationTimeout = const Duration(seconds: 3),
    this.maxConnections = 10,
    this.ssl = false,
    this.retryOnFailure = true,
    this.maxRetries = 3,
  });

  /// 从Map创建配置
  factory RedisConfig.fromMap(Map<String, dynamic> map) {
    return RedisConfig(
      host: map['host'] ?? 'localhost',
      port: map['port'] ?? 6379,
      password: map['password'],
      database: map['database'] ?? 0,
      connectionTimeout: Duration(
        milliseconds: map['connectionTimeout'] ?? 5000,
      ),
      operationTimeout: Duration(
        milliseconds: map['operationTimeout'] ?? 3000,
      ),
      maxConnections: map['maxConnections'] ?? 10,
      ssl: map['ssl'] ?? false,
      retryOnFailure: map['retryOnFailure'] ?? true,
      maxRetries: map['maxRetries'] ?? 3,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'host': host,
      'port': port,
      'password': password,
      'database': database,
      'connectionTimeout': connectionTimeout.inMilliseconds,
      'operationTimeout': operationTimeout.inMilliseconds,
      'maxConnections': maxConnections,
      'ssl': ssl,
      'retryOnFailure': retryOnFailure,
      'maxRetries': maxRetries,
    };
  }

  /// 复制配置
  RedisConfig copyWith({
    String? host,
    int? port,
    String? password,
    int? database,
    Duration? connectionTimeout,
    Duration? operationTimeout,
    int? maxConnections,
    bool? ssl,
    bool? retryOnFailure,
    int? maxRetries,
  }) {
    return RedisConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      password: password ?? this.password,
      database: database ?? this.database,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      operationTimeout: operationTimeout ?? this.operationTimeout,
      maxConnections: maxConnections ?? this.maxConnections,
      ssl: ssl ?? this.ssl,
      retryOnFailure: retryOnFailure ?? this.retryOnFailure,
      maxRetries: maxRetries ?? this.maxRetries,
    );
  }

  @override
  String toString() {
    return 'RedisConfig(host: $host, port: $port, database: $database)';
  }
}