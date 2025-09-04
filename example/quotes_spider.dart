import 'dart:async';
import 'dart:io';
import 'package:dart_scrapy/darts_crapy.dart';

/// 示例：爬取名言的爬虫
class QuotesScrapy extends Scrapy {
  @override
  String get name => 'quotes';

  @override
  List<String> get startUrls => [
        'http://quotes.toscrape.com/page/1/',
      ];

  @override
  List<String> get allowedDomains => ['quotes.toscrape.com'];

  @override
  int get downloadDelay => 1000; // 1秒延迟

  @override
  int get concurrentRequests => 4; // 并发数限制

  // Redis去重配置
  @override
  bool get enableDeduplication => true; // 启用去重功能

  @override
  DuplicateFilterType get duplicateFilterType =>
      DuplicateFilterType.redis; // 使用混合去重模式

  @override
  RedisConfig get redisConfig => RedisConfig(
        host: '149.104.25.116',
        port: 16379,
        password: 'w19961101223',
        database: 1,
        maxConnections: 10,
        connectionTimeout: Duration(seconds: 5),
      );

  @override
  Map<String, dynamic> get duplicateConfig => {
        'maxMemorySize': 1000,
        'ttl': Duration(days: 7).inSeconds,
        'enableCompression': true,
      };

  @override
  Future<Iterable<dynamic>> handleResponse(Response response) async {
    final selector = ResponseSelector(response.text);
    final results = <dynamic>[];

    // 提取所有名言
    final quotes = selector.css('.quote');
    for (final quote in quotes) {
      final text = quote.cssOne('.text')?.text ?? '';
      final author = quote.cssOne('.author')?.text ?? '';
      final tags = quote.css('.tag').map((tag) => tag.text).toList();

      final item = QuoteItem(
        text: text,
        author: author,
        tags: tags,
        url: response.url,
      );

      results.add(item);
    }

    // 提取下一页链接
    final nextPage = selector.cssOne('.next a');
    if (nextPage != null) {
      final nextUrl = nextPage.getAttribute('href');
      if (nextUrl != null) {
        final absoluteUrl = Uri.parse(response.url).resolve(nextUrl).toString();
        results.add(Request.get(absoluteUrl));
      }
    }

    return results;
  }
}

/// 名言数据项
class QuoteItem extends Item {
  final String text;
  final String author;
  final List<String> tags;
  final String url;

  const QuoteItem({
    required this.text,
    required this.author,
    required this.tags,
    required this.url,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'author': author,
      'tags': tags,
      'url': url,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  factory QuoteItem.fromMap(Map<String, dynamic> map) {
    return QuoteItem(
      text: map['text'] as String,
      author: map['author'] as String,
      tags: List<String>.from(map['tags'] as List),
      url: map['url'] as String,
    );
  }
}

/// 主函数
void main() async {
  try {
    // 初始化日志
    DartScrapyLogger.initialize(LoggerConfig(
      level: LogLevel.error,
      consoleOutput: true,
      fileOutput: true,
      logFile: 'logs/quotes_spider.log',
    ));

    // 创建爬虫
    final scrapy = QuotesScrapy();

    // 创建管道
    final pipelineManager = PipelineManager();
    pipelineManager.addPipeline(ConsolePipeline());
    pipelineManager.addPipeline(CsvPipeline(
        'data/quotes.csv', ['text', 'author', 'tags', 'url', 'timestamp']));

    // 随机代理池和User-Agent列表
    final proxyList = [
      'http://127.0.0.1:7890',
      // 可添加更多代理
    ];
    final userAgentList = DefaultUserAgentPool.userAgents;

    // 创建中间件
    final middlewareManager = MiddlewareManager();
    middlewareManager.addDownloadMiddleware(RandomProxyMiddleware(proxyList));
    middlewareManager
        .addDownloadMiddleware(RandomUserAgentMiddleware(userAgentList));
    middlewareManager.addDownloadMiddleware(UserAgentMiddleware());
    middlewareManager.addDownloadMiddleware(RetryMiddleware(maxRetries: 3));

    // 创建引擎
    final engine = ScrapyEngine(
      scrapy: scrapy,
      // downloader: RandomRateDownloader(
      //     downloader: HttpDownloader(),
      //     minDelay: Duration(milliseconds: 500),
      //     maxDelay: Duration(milliseconds: 10000)),
      config: EngineConfig(
        obeyRobotsTxt: true,
        maxConcurrentRequests: 4,
        requestDelay: Duration(seconds: 1),
        enableRetry: true,
        maxRetries: 3,
        enableDeduplication: true, // 启用去重功能
        duplicateFilterType: DuplicateFilterType.redis, // 使用混合去重
        redisConfig: scrapy.redisConfig, // 使用Scrapy的Redis配置
      ),
      pipelineManager: pipelineManager,
      middlewareManager: middlewareManager,
    );

    // 监听数据流
    engine.itemStream.listen((item) {
      print('📦 爬取到数据: ${item.toMap()}');
    });

    // 监听统计信息
    engine.statsStream.listen((stats) {
      print('📊 统计信息: ${stats.toMap()}');
    });

    // 启动爬虫
    print('🚀 启动名言爬虫...');
    await engine.start();

    // 等待爬虫完成（带超时保护）
    try {
      await engine.waitForCompletion().timeout(Duration(minutes: 2));
    } on TimeoutException {
      print('⚠️ 爬虫超时，强制停止...');
    }

    // 打印最终统计
    final stats = engine.stats;
    final duplicateStats = scrapy.getDuplicateStats();

    print('\n✅ 爬虫完成！');
    print('📊 最终统计:');
    print('   - 总请求数: ${stats.totalRequests}');
    print('   - 成功请求: ${stats.successfulRequests}');
    print('   - 失败请求: ${stats.failedRequests}');
    print('   - 爬取数据: ${stats.totalItems}');
    print('   - 运行时间: ${stats.runtime.inSeconds}秒');
    print('   - 成功率: ${(stats.successRate * 100).toStringAsFixed(2)}%');

    if (duplicateStats != null) {
      print('\n🔄 去重统计:');
      print('   - 总检查数: ${duplicateStats.totalChecked}');
      print('   - 去重数量: ${duplicateStats.totalDuplicates}');
      print(
          '   - 去重率: ${(duplicateStats.duplicateRate * 100).toStringAsFixed(2)}%');
      print('   - 平均检查时间: ${duplicateStats.averageCheckTime.inMilliseconds}ms');
    }
  } catch (e, stackTrace) {
    DartScrapyLogger.error('爬虫执行失败', e, stackTrace);
  } finally {
    print('🏁 程序正常退出');
    exit(0); // 强制退出，解决卡住问题
  }

}
// Removed PubDevScrapy class as it's now in pub_dev_spider.dart
