import 'package:meta/meta.dart';

/// 数据项基类，所有爬取的数据都应该继承此类
@immutable
abstract class Item {
  const Item();

  /// 将数据项转换为Map
  Map<String, dynamic> toMap();

  /// 从Map创建数据项
  factory Item.fromMap(Map<String, dynamic> map) {
    throw UnimplementedError('Subclasses must implement fromMap');
  }

  /// 将数据项转换为JSON字符串
  String toJson() => toMap().toString();

  @override
  String toString() => toMap().toString();
}

/// 通用数据项类，用于简单的键值对数据
class GenericItem extends Item {
  final Map<String, dynamic> _data;

  const GenericItem(this._data);

  @override
  Map<String, dynamic> toMap() => Map.from(_data);

  factory GenericItem.fromMap(Map<String, dynamic> map) {
    return GenericItem(Map.from(map));
  }

  /// 获取字段值
  dynamic operator [](String key) => _data[key];

  /// 设置字段值（修改原实例）
  void operator []=(String key, dynamic value) {
    _data[key] = value;
  }

  /// 包含指定字段
  bool containsKey(String key) => _data.containsKey(key);

  /// 获取所有字段名
  Iterable<String> get keys => _data.keys;

  /// 获取所有值
  Iterable<dynamic> get values => _data.values;
}

/// 字段定义类，用于验证数据项的结构
class Field {
  final String name;
  final Type type;
  final bool required;
  final dynamic defaultValue;
  final List<dynamic>? choices;

  const Field({
    required this.name,
    required this.type,
    this.required = false,
    this.defaultValue,
    this.choices,
  });

  /// 验证字段值
  bool validate(dynamic value) {
    if (required && value == null) return false;
    if (value != null && value.runtimeType != type) return false;
    if (choices != null && !choices!.contains(value)) return false;
    return true;
  }
}

/// 数据项元数据类，用于定义数据项的结构
class ItemMeta {
  final String name;
  final List<Field> fields;

  const ItemMeta({
    required this.name,
    required this.fields,
  });

  /// 验证数据项是否符合定义
  bool validate(Item item) {
    final data = item.toMap();
    for (final field in fields) {
      if (!field.validate(data[field.name])) {
        return false;
      }
    }
    return true;
  }
}