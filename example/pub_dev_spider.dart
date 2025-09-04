import 'dart:io';

import 'package:dart_scrapy/darts_crapy.dart';

class PubDevScrapy extends Scrapy {
  @override
  String get name => 'pub_dev';

  @override
  List<String> get startUrls => [
        'https://pub.dev/packages?page=1',
      ];

  @override
  List<String> get allowedDomains => ['pub.dev'];

  int get maxPages => 20; // 增加最大页数限制
  @override
  DuplicateFilterType get duplicateFilterType =>
      DuplicateFilterType.redis; // 使用混合去重模式

  // @override
  // RedisConfig get redisConfig => RedisConfig(
  //       host: '',
  //       port: 16379,
  //       password: '',
  //       database: 1,
  //       maxConnections: 10,
  //       connectionTimeout: Duration(seconds: 5),
  //     );

  // @override
  // Map<String, dynamic> get duplicateConfig => {
  //       'maxMemorySize': 1000,
  //       'ttl': Duration(days: 7).inSeconds,
  //       'enableCompression': true,
  //     };
  @override
  Future<Iterable<dynamic>> handleResponse(Response response) async {
    final selector = ResponseSelector(response.text);
    final results = <dynamic>[];

    // 提取所有包信息
    final packages = selector.css('.packages-item');
    for (final package in packages) {
      final name = package.cssOne('.packages-title')?.text ?? '';
      final description = package.cssOne('.packages-description')?.text ?? '';
      final likes = package.cssOne('.packages-score-like')?.text ?? '';
      final points = package.cssOne('.packages-score-health')?.text ?? '';
      final popularity =
          package.cssOne('.packages-score-popularity')?.text ?? '';

      final detailUrl = package.cssOne('h3.packages-title > a')?.getAttribute('href') ?? '';
      if (detailUrl.isNotEmpty) {
        final absoluteUrl = Uri.parse(response.url).resolve(detailUrl).toString();
        final item = PubDevItem(
          name: name,
          description: description,
          likes: likes,
          points: points,
          popularity: popularity,
          url: absoluteUrl,
        );
        results.add(item);
      }
    }

    // 提取下一页链接
    final currentPage = int.tryParse(
            RegExp(r'page=(\d+)').firstMatch(response.url)?.group(1) ?? '1') ??
        1;

        print('--------------------当前页码:${currentPage}');
    if (currentPage < maxPages) {
      final nextPage = selector.cssOne('a[rel="next nofollow"]');

      print('--------------------下一页:${nextPage}');
      if (nextPage != null) {
        final nextUrl = nextPage.getAttribute('href');
        if (nextUrl != null) {
          final absoluteUrl =
              Uri.parse(response.url).resolve(nextUrl).toString();
          results.add(Request.get(absoluteUrl));
        }
      }
    }

    return results;
  }


}

/// pub.dev package data item
class PubDevItem extends Item {
  final String name;
  final String description;
  final String likes;
  final String points;
  final String popularity;
  final String url;

  const PubDevItem({
    required this.name,
    required this.description,
    required this.likes,
    required this.points,
    required this.popularity,
    required this.url,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'likes': likes,
      'points': points,
      'popularity': popularity,
      'url': url,
    };
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
      logFile: 'logs/pub_dev_spider.log',
    ));

    // 创建爬虫
    final scrapy = PubDevScrapy();

    // 创建管道
    final pipelineManager = PipelineManager();
    pipelineManager.addPipeline(ConsolePipeline());
    pipelineManager.addPipeline(CsvPipeline('data/pub_dev.csv',
        ['name', 'description', 'likes', 'points', 'popularity', 'url']));

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
      downloader: RandomRateDownloader(
          downloader: HttpDownloader(),
          minDelay: Duration(milliseconds: 1000),
          maxDelay: Duration(milliseconds: 5000)),
      config: EngineConfig(
        obeyRobotsTxt: true,
        maxConcurrentRequests: 4,
        requestDelay: Duration(seconds: 1),
        enableRetry: true,
        maxRetries: 3,
        enableDeduplication: false, // 启用去重功能
        // duplicateFilterType: DuplicateFilterType.redis, // 使用混合去重
        // redisConfig: scrapy.redisConfig, // 使用Scrapy的Redis配置
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
