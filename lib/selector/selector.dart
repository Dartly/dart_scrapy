import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;

/// 选择器接口
abstract class Selector {
  /// 选择器类型
  String get type;

  /// 选择元素
  List<Element> select(String html, String selector);

  /// 选择单个元素
  Element? selectOne(String html, String selector);

  /// 提取文本
  List<String> extractText(String html, String selector);

  /// 提取属性
  List<String> extractAttribute(String html, String selector, String attribute);
}

/// HTML元素包装类
class Element {
  final html_dom.Element _element;

  Element(this._element);

  /// 获取文本内容
  String get text => _element.text.trim();

  /// 获取HTML内容
  String get html => _element.outerHtml;

  /// 获取属性值
  String? getAttribute(String name) => _element.attributes[name];

  /// 获取所有属性
  Map<String, String> get attributes => Map.from(_element.attributes);

  /// 获取标签名
  String get tagName => _element.localName?.toLowerCase() ?? '';

  @override
  String toString() => text;

  /// CSS选择器 - 选择所有匹配元素
  List<Element> css(String selector) {
    final elements = _element.querySelectorAll(selector);
    return elements.map((e) => Element(e)).toList();
  }

  /// CSS选择器 - 选择第一个匹配元素
  Element? cssOne(String selector) {
    final element = _element.querySelector(selector);
    return element != null ? Element(element) : null;
  }
}

/// CSS选择器实现
class CssSelector implements Selector {
  @override
  String get type => 'css';

  @override
    List<Element> select(String html, String selector) {
    // 使用UTF-8编码解析HTML
    final document = html_parser.parse(html, encoding: 'utf-8');
    final elements = document.querySelectorAll(selector);
    return elements.map((e) => Element(e)).toList();
  }

  @override
  Element? selectOne(String html, String selector) {
    final document = html_parser.parse(html);
    final element = document.querySelector(selector);
    return element != null ? Element(element) : null;
  }

  @override
  List<String> extractText(String html, String selector) {
    return select(html, selector).map((e) => e.text).toList();
  }

  @override
  List<String> extractAttribute(String html, String selector, String attribute) {
    return select(html, selector)
        .map((e) => e.getAttribute(attribute) ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
  }
}

/// 选择器工厂
class SelectorFactory {
  static Selector create(String type) {
    switch (type.toLowerCase()) {
      case 'css':
        return CssSelector();
      default:
        throw ArgumentError('Unsupported selector type: $type');
    }
  }
}

/// 响应选择器包装类
class ResponseSelector {
  final String _html;
  final Selector _cssSelector = CssSelector();

  ResponseSelector(String html) : _html = html;

  /// CSS选择器
  List<Element> css(String selector) => _cssSelector.select(_html, selector);

  /// CSS选择单个元素
  Element? cssOne(String selector) => _cssSelector.selectOne(_html, selector);

  /// 提取CSS文本
  List<String> cssText(String selector) => _cssSelector.extractText(_html, selector);

  /// 提取CSS属性
  List<String> cssAttr(String selector, String attribute) => 
      _cssSelector.extractAttribute(_html, selector, attribute);

  /// 获取第一个匹配的文本
  String? firstText(String selector) => cssOne(selector)?.text;

  /// 获取第一个匹配的属性
  String? firstAttr(String selector, String attribute) => 
      cssOne(selector)?.getAttribute(attribute);

  /// 获取所有匹配的文本
  List<String> allText(String selector) => cssText(selector);

  /// 获取所有匹配的属性
  List<String> allAttr(String selector, String attribute) => 
      cssAttr(selector, attribute);

  /// 正则表达式提取
  List<String> re(String pattern) {
    final regex = RegExp(pattern);
    return regex.allMatches(_html).map((m) => m.group(0) ?? '').toList();
  }

  /// 正则表达式提取第一个匹配
  String? reFirst(String pattern) {
    final regex = RegExp(pattern);
    final match = regex.firstMatch(_html);
    return match?.group(0);
  }
}

/// 选择器工具类
class SelectorUtils {
  /// 清理文本（去除多余空格和换行）
  static String cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 提取数字
  static double? extractNumber(String text) {
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(text);
    return match != null ? double.tryParse(match.group(0)!) : null;
  }

  /// 提取整数
  static int? extractInteger(String text) {
    final match = RegExp(r'-?\d+').firstMatch(text);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  /// 提取URL
  static String? extractUrl(String text) {
    final match = RegExp(
      r'https?://[^\s<>"{}|\\^`\[\]]+',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(0);
  }

  /// 提取电子邮件
  static String? extractEmail(String text) {
    final match = RegExp(
      r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
    ).firstMatch(text);
    return match?.group(0);
  }

  /// 提取日期
  static DateTime? extractDate(String text) {
    final patterns = [
      r'\d{4}-\d{2}-\d{2}',
      r'\d{2}/\d{2}/\d{4}',
      r'\d{2}-\d{2}-\d{4}',
    ];

    for (final pattern in patterns) {
      final match = RegExp(pattern).firstMatch(text);
      if (match != null) {
        return DateTime.tryParse(match.group(0)!);
      }
    }
    return null;
  }
}