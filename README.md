# DartScrapy 🕷️

一个用Dart语言开发的高性能、模块化爬虫框架，灵感来源于Python的Scrapy框架。

## ✨ 特性

- **🚀 高性能异步处理**：基于Dart的async/await和Isolate实现并发
- **🧩 模块化架构**：各组件独立，易于扩展和维护
- **🎯 强大的选择器**：支持XPath和CSS选择器
- **⚙️ 可扩展中间件**：下载中间件和爬虫中间件
- **📊 数据处理管道**：支持多种数据输出格式
- **📝 完善的日志系统**：可配置的多级别日志
- **⏯️ 任务控制**：支持启动、暂停、恢复爬虫
- **🔍 智能重试**：内置重试机制和限流控制
- **📈 实时监控**：实时统计和性能监控

## 📦 安装

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  dartscrapy:
    path: ../darts_crapy
```



## 🚀 快速开始

### 1. 创建爬虫

```dart
import 'package:dartscrapy/darts_crapy.dart';

class MySpider extends Spider {
  @override
  String get name => 'my_spider';

  @override
  List<String> get startUrls => [
    'https://example.com',
  ];

  @override
  Future<Iterable<dynamic>> handleResponse(Response response) async {
    final selector = ResponseSelector(response.text);
    
    // 提取数据
    final title = selector.cssOne('title')?.text;
    final links = selector.css('a').map((a) => a.getAttribute('href')).whereType<String>();
    
    return [
      MyItem(title: title),
      ...links.map((url) => Request.get(url)),
    ];
  }
}

class MyItem extends Item {
  final String title;
  
  MyItem({required this.title});
  
  @override
  Map<String, dynamic> toMap() => {'title': title};
}
```

### 2. 运行爬虫

```dart
void main() async {
  final spider = MySpider();
  final engine = SpiderEngine(spider: spider);
  
  await engine.start();
  await engine.waitForCompletion();
}
```

## 🏗️ 架构概览

```
┌─────────────────┐
│   SpiderEngine  │ 核心引擎
├─────────────────┤
│    Scheduler    │ 请求调度器
├─────────────────┤
│   Downloader    │ 下载器
├─────────────────┤
│  MiddlewareMgr  │ 中间件管理
├─────────────────┤
│  PipelineMgr    │ 管道管理
├─────────────────┤
│     Spider      │ 爬虫
└─────────────────┘
```

## 🎯 核心组件

### 1. 请求调度器 (Scheduler)

- **MemoryScheduler**: 内存队列调度
- **PriorityScheduler**: 优先级队列调度
- **FileScheduler**: 文件持久化调度

### 2. 下载器 (Downloader)

- **HttpDownloader**: HTTP/HTTPS下载
- **RetryDownloader**: 重试装饰器
- **RateLimitedDownloader**: 限流装饰器

### 3. 中间件 (Middleware)

#### 下载中间件
- **UserAgentMiddleware**: 设置User-Agent
- **RetryMiddleware**: 自动重试
- **ProxyMiddleware**: 代理支持

#### 爬虫中间件
- **ValidationMiddleware**: 数据验证
- **CleaningMiddleware**: 数据清洗

### 4. 管道 (Pipeline)

- **ConsolePipeline**: 控制台输出
- **FilePipeline**: 文件存储
- **JsonPipeline**: JSON格式存储
- **CsvPipeline**: CSV格式存储
- **DatabasePipeline**: 数据库存储

### 5. 选择器 (Selector)

- **CssSelector**: CSS选择器
- **XPathSelector**: XPath选择器
- **ResponseSelector**: 响应选择器

## ⚙️ 配置选项

### 引擎配置

```dart
final engine = SpiderEngine(
  spider: mySpider,
  config: EngineConfig(
    maxConcurrentRequests: 8,
    requestDelay: Duration(milliseconds: 500),
    maxRetries: 3,
    retryDelay: Duration(seconds: 1),
    timeout: Duration(seconds: 30),
    enableRetry: true,
    enableRateLimit: true,
    obeyRobotsTxt: true, // 启用robots.txt检查
    userAgent: 'MySpider/1.0', // 自定义User-Agent
  ),
);
```

### 日志配置

```dart
DartScrapyLogger.initialize(LoggerConfig(
  level: LogLevel.info,
  consoleOutput: true,
  fileOutput: true,
  logFile: 'logs/spider.log',
  maxFileSize: 10 * 1024 * 1024, // 10MB
  maxFiles: 5,
));

### 🔄 智能去重系统

DartScrapy内置了强大的去重系统，支持内存、Redis和混合模式，确保不会重复处理相同的URL，提高爬取效率。

#### 启用去重功能

```dart
final engine = SpiderEngine(
  spider: mySpider,
  config: EngineConfig(
    enableDeduplication: true, // 启用去重功能
    duplicateFilterType: 'hybrid', // 选择去重模式：memory、redis、hybrid
    redisConfig: RedisConfig(
      host: 'localhost',
      port: 6379,
      password: 'yourpassword',
      database: 0,
    ),
  ),
);
```

#### 去重模式说明

- **memory模式**：使用内存存储URL指纹，速度快但重启后失效
- **redis模式**：使用Redis存储URL指纹，支持分布式和持久化
- **hybrid模式**：内存+Redis混合模式，兼顾性能和持久化

#### 在Spider中使用去重

```dart
class MySpider extends Spider {
  @override
  String get name => 'my_spider';
  
  @override
  List<String> get startUrls => ['https://example.com'];
  
  @override
  bool get enableDeduplication => true; // 启用去重
  
  @override
  String get duplicateFilterType => 'redis'; // 选择去重模式
  
  @override
  RedisConfig get redisConfig => RedisConfig(
    host: 'localhost',
    port: 6379,
  );
  
  @override
  Future<Iterable<dynamic>> handleResponse(Response response) async {
    // 手动检查URL是否已处理
    final isDuplicate = await isDuplicateRequest('https://example.com/page');
    if (isDuplicate) {
      print('该URL已处理过，跳过');
      return [];
    }
    
    // 正常处理响应
    return parsePage(response);
  }
}
```

#### 自定义去重配置

```dart
// 自定义Redis配置
final redisConfig = RedisConfig(
  host: 'redis.example.com',
  port: 6380,
  password: 'secure_password',
  database: 1,
  maxConnections: 20,
  connectionTimeout: Duration(seconds: 5),
  idleTimeout: Duration(minutes: 5),
);

// 在Spider中使用
class MySpider extends Spider {
  @override
  RedisConfig get redisConfig => redisConfig;
  
  @override
  DuplicateFilterConfig get duplicateConfig => DuplicateFilterConfig(
    maxMemorySize: 10000, // 内存最大存储数量
    ttl: Duration(days: 7), // URL指纹过期时间
    enableCompression: true, // 启用压缩
    bloomFilterCapacity: 1000000, // Bloom过滤器容量
  );
}
```

#### 获取去重统计

```dart
// 在Spider中获取去重统计
class MySpider extends Spider {
  @override
  Future<void> onClose() async {
    final stats = await getDuplicateStats();
    print('总请求数: ${stats.totalRequests}');
    print('去重数量: ${stats.duplicateCount}');
    print('内存使用: ${stats.memoryUsage}');
    print('Redis使用: ${stats.redisUsage}');
  }
}
```

### 🤖 robots.txt支持

DartScrapy内置了对robots.txt的支持，可以自动检查目标网站的robots.txt规则，确保爬虫行为符合网站的爬取策略。

#### 启用robots.txt检查

```dart
final engine = SpiderEngine(
  spider: mySpider,
  config: EngineConfig(
    obeyRobotsTxt: true, // 启用robots.txt检查
    userAgent: 'MySpider/1.0', // 设置User-Agent用于robots.txt检查
  ),
);
```

#### 在Spider中控制robots.txt行为

```dart
class MySpider extends Spider {
  @override
  String get name => 'my_spider';
  
  @override
  List<String> get startUrls => ['https://example.com'];
  
  @override
  List<String> get allowedDomains => ['example.com'];
  
  @override
  bool get obeyRobotsTxt => true; // 在Spider级别控制是否检查robots.txt
  
  @override
  Future<Iterable<dynamic>> handleResponse(Response response) async {
    // 手动检查特定URL的robots.txt规则
    final isAllowed = await isUrlAllowedByRobots('https://example.com/some-page');
    if (!isAllowed) {
      print('该URL被robots.txt禁止访问');
      return [];
    }
    
    // 正常处理响应
    return parsePage(response);
  }
}
```

#### robots.txt缓存机制

robots.txt文件会被自动缓存24小时，避免重复下载。可以通过以下方式清理缓存：

```dart
import 'package:dart_scrapy/utils/robots_txt.dart';

// 清理robots.txt缓存
RobotsTxtChecker.clearCache();
```
```

## 📊 监控和统计

### 实时统计

```dart
engine.statsStream.listen((stats) {
  print('Requests: ${stats.totalRequests}');
  print('Items: ${stats.totalItems}');
  print('Success Rate: ${stats.successRate}');
});
```

### 性能监控

```dart
final monitor = PerformanceMonitor();
monitor.startTimer('request_time');
// ... 执行请求
monitor.stopTimer('request_time');
print('Request took: ${monitor.getElapsedTime('request_time')}');
```

## 🧪 测试

### 单元测试

```bash
dart test test/unit/
```

### 集成测试

```bash
dart test test/integration/
```

### 示例测试

```bash
dart run example/quotes_spider.dart
```

## 🔧 高级用法

### 自定义中间件

```dart
class CustomMiddleware implements DownloadMiddleware {
  @override
  Future<Request> processRequest(Request request) async {
    // 处理请求
    return request.copyWith(
      headers: {...request.headers, 'X-Custom': 'value'},
    );
  }

  @override
  Future<Response> processResponse(Response response) async {
    // 处理响应
    return response;
  }
}
```

### 自定义管道

```dart
class CustomPipeline implements Pipeline {
  @override
  Future<void> open() async {
    // 初始化
  }

  @override
  Future<void> processItem(Item item) async {
    // 处理数据项
    print('Processing: ${item.toMap()}');
  }

  @override
  Future<void> close() async {
    // 清理资源
  }
}
```



### 错误处理

```dart
try {
  await engine.start();
} on DartScrapyException catch (e) {
  print('Spider error: ${e.message}');
  if (e.cause != null) {
    print('Caused by: ${e.cause}');
  }
}
```

## 📋 最佳实践

1. **合理设置并发数**：避免过高并发导致被封IP
2. **尊重robots.txt**：始终启用robots.txt检查，遵守网站的爬取规则
3. **使用延迟策略**：合理配置请求延迟，避免对目标网站造成过大压力
4. **错误重试机制**：合理配置重试次数和间隔
5. **数据验证**：使用ValidationPipeline验证数据完整性
6. **日志监控**：实时监控爬虫运行状态
7. **资源清理**：及时释放不再使用的资源
8. **User-Agent设置**：使用合适的User-Agent标识爬虫身份

## 🤝 贡献

欢迎提交Issue和Pull Request！

### 开发环境

```bash
git clone https://github.com/yourname/darts_crapy.git
cd dartscrapy
dart pub get
dart test
## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🙏 致谢

- 灵感来源于 [Scrapy](https://scrapy.org/)
- 感谢Dart社区的支持

---

**注意：** 本项目中的部分代码（特别是示例代码和配置片段）由AI辅助生成。
```
