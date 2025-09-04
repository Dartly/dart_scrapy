/// 默认的User-Agent池，供所有爬虫和中间件统一调用
class DefaultUserAgentPool {
  static const List<String> userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/15.1 Safari/605.1.15',
    'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:40.0) Gecko/20100101 Firefox/40.1',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 Version/14.0 Mobile/15A372 Safari/604.1',
    'Mozilla/5.0 (Linux; U; Android 4.2.2; en-us; GT-I9505 Build/JDQ39) AppleWebKit/534.30 Chrome/30.0.0.0 Mobile Safari/534.30',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 Chrome/76.0.3809.132 Safari/537.36',
    'Mozilla/5.0 (Linux; Android 9; SM-G960F) AppleWebKit/537.36 Chrome/74.0.3729.157 Mobile Safari/537.36',
    'Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 Chrome/41.0.2228.0 Safari/537.36',
  ];
}
