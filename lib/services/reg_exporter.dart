import 'dart:typed_data';

import '../models/namespace_item.dart';

/// 生成 `.reg` 导出文本（CLSID 定义 + 命名空间链接）。
///
/// 这是纯字符串逻辑，不触碰注册表，因此可以直接单元测试。
String buildRegContent(NamespaceItem item) {
  final clsidHive = _hiveName(item.clsidRoot);
  final nsHive = _hiveName(item.root);
  final nsSuffix = item.enabled ? 'NameSpace' : 'NameSpaceDisabled';
  final clsidKey = '$clsidHive\\SOFTWARE\\Classes\\CLSID\\${item.clsid}';

  final buffer = StringBuffer();
  // .reg 文件要求 CRLF 换行，不能依赖平台相关的 writeln。
  void line([String text = '']) => buffer.write('$text\r\n');

  line('Windows Registry Editor Version 5.00');
  line();
  line('[$clsidKey]');
  line('@="${_escape(item.name)}"');
  line('"LocalizedString"="${_escape(item.name)}"');

  if (item.desc.isNotEmpty) {
    line('"System.ItemAuthors"="${_escape(item.desc)}"');
  }
  line('"TileInfo"="prop:System.ItemAuthors"');

  if (item.tip.isNotEmpty) {
    line('"InfoTip"="${_escape(item.tip)}"');
  }

  if (item.iconPath.isNotEmpty) {
    line();
    line('[$clsidKey\\DefaultIcon]');
    line('@="${_escape('${item.iconPath},0')}"');
  }

  if (item.exePath.isNotEmpty) {
    line();
    line('[$clsidKey\\Shell\\Open\\Command]');
    line('@="${_escape(item.exePath)}"');
  }

  line();
  line(
    '[$nsHive\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer'
    '\\${item.itemType}\\$nsSuffix\\${item.clsid}]',
  );
  line('@="${_escape(item.name)}"');

  return buffer.toString();
}

/// 把 `.reg` 文本编码为 regedit 可识别的字节流。
///
/// regedit 导出的文件在包含非 ASCII 字符时使用 **UTF-16LE + BOM**；
/// 若以 UTF-8 写出，中文名称在注册表编辑器中会显示为乱码。
Uint8List encodeRegFile(String content) {
  final units = content.codeUnits; // Dart 字符串内部即 UTF-16 码元
  final bytes = Uint8List(2 + units.length * 2);
  bytes[0] = 0xFF; // BOM（小端）
  bytes[1] = 0xFE;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    bytes[2 + i * 2] = unit & 0xFF;
    bytes[3 + i * 2] = (unit >> 8) & 0xFF;
  }
  return bytes;
}

String _hiveName(String root) =>
    root.toUpperCase() == 'HKLM' ? 'HKEY_LOCAL_MACHINE' : 'HKEY_CURRENT_USER';

/// `.reg` 文本转义：反斜杠、双引号，以及会破坏单行结构的换行符。
///
/// 相比原版增加了换行转义 —— 未转义的换行会写出无法导入的 `.reg` 文件。
String _escape(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')
    .replaceAll('\r\n', '\\n')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\n');
