import 'dart:io';

import 'package:uuid/uuid.dart';
import 'package:win32/win32.dart' show WindowsException;
import 'package:win32_registry/win32_registry.dart';

import '../models/namespace_item.dart';

/// Explorer 命名空间根路径（位于 HKCU / HKLM 之下）。
const String _explorerNs =
    r'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer';

/// 打开配置常量。
///
/// 关键点：删除子键需要 `DELETE` 权限，而 `RegistryAccess.readWrite`
/// （`KEY_READ | KEY_WRITE = 0x2001F`）**不含** `DELETE`，
/// 因此凡涉及删除的场景都必须用 `RegistryAccess.all`（`KEY_ALL_ACCESS`）。
const _createAll = RegistryOpenConfig(access: RegistryAccess.all, create: true);
const _openRead = RegistryOpenConfig(access: RegistryAccess.read);
const _openAll = RegistryOpenConfig(access: RegistryAccess.all);

/// CLSID 定义的查询结果。
typedef _ClsidInfo =
    ({
      String clsidRoot,
      String name,
      String desc,
      String tip,
      String exePath,
      String iconPath,
    });

/// 命名空间条目读写。
///
/// 全部为静态方法：注册表操作本身是同步的，且本应用不需要多实例。
/// 失败时抛出 [WindowsException]，由 UI 层统一翻译成提示文案。
class RegistryService {
  const RegistryService._();

  /// 读取全部条目。
  ///
  /// 忠实于原版：此电脑扫描 HKCU + HKLM，桌面侧边栏仅扫描 HKCU。
  static List<NamespaceItem> getItems() {
    final items = <NamespaceItem>[];
    for (final root in const ['HKCU', 'HKLM']) {
      for (final disabled in const [false, true]) {
        items.addAll(_getItemsInternal(root, disabled, 'MyComputer'));
      }
    }
    for (final disabled in const [false, true]) {
      items.addAll(_getItemsInternal('HKCU', disabled, 'Desktop'));
    }
    return items;
  }

  /// 新增或更新一个条目（对应原版 `UpdateItem`）。
  static void updateItem(NamespaceItem item) {
    // 原版在写完键之后才校验名称，这里前置以避免留下空壳键。
    if (item.name.trim().isEmpty) {
      throw ArgumentError.value(item.name, 'name', '名称不能为空');
    }

    // 1) 命名空间链接
    final nsPath =
        '$_explorerNs\\${item.itemType}\\'
        '${item.enabled ? 'NameSpace' : 'NameSpaceDisabled'}\\${item.clsid}';
    final nsKey = _hiveOf(item.root).create(nsPath, config: _createAll);
    try {
      nsKey.setValue('', RegistryValue.string(item.name));
    } finally {
      nsKey.close();
    }

    // 2) CLSID 定义
    final sub = _hiveOf(item.clsidRoot).create(
      'SOFTWARE\\Classes\\CLSID\\${item.clsid}',
      config: _createAll,
    );
    try {
      sub.setValue('', RegistryValue.string(item.name));
      sub.setValue('LocalizedString', RegistryValue.string(item.name));

      if (item.desc.isEmpty) {
        _deleteValueIfExists(sub, 'System.ItemAuthors');
      } else {
        sub.setValue('System.ItemAuthors', RegistryValue.string(item.desc));
      }
      sub.setValue('TileInfo', RegistryValue.string('prop:System.ItemAuthors'));

      if (item.tip.isEmpty) {
        _deleteValueIfExists(sub, 'InfoTip');
      } else {
        sub.setValue('InfoTip', RegistryValue.string(item.tip));
      }

      if (item.iconPath.isNotEmpty) {
        final iconKey = sub.create('DefaultIcon', config: _createAll);
        try {
          // DefaultIcon 必须是 REG_EXPAND_SZ，否则 %SystemRoot% 之类的
          // 环境变量不会被展开。原版为此手工拼 UTF-16 字节，这里直接有现成类型。
          iconKey.setValue(
            '',
            RegistryValue.unexpandedString('${item.iconPath},0'),
          );
        } finally {
          iconKey.close();
        }
      }

      if (item.exePath.isEmpty) {
        _deleteSubkeyIfExists(sub, r'Shell\Open');
      } else {
        final exeKey = sub.create(r'Shell\Open\Command', config: _createAll);
        try {
          exeKey.setValue('', RegistryValue.string(item.exePath));
        } finally {
          exeKey.close();
        }
      }
    } finally {
      sub.close();
    }
  }

  /// 启用 / 禁用条目（在 NameSpace 与 NameSpaceDisabled 之间移动）。
  static void setEnabled(NamespaceItem item, bool enabled) {
    final base = '$_explorerNs\\${item.itemType}';
    final hive = _hiveOf(item.root);
    final srcKey = hive.create(
      '$base\\${enabled ? 'NameSpaceDisabled' : 'NameSpace'}',
      config: _createAll,
    );
    final dstKey = hive.create(
      '$base\\${enabled ? 'NameSpace' : 'NameSpaceDisabled'}',
      config: _createAll,
    );
    try {
      final newKey = dstKey.create(item.clsid, config: _createAll);
      try {
        newKey.setValue('', RegistryValue.string(item.name));
      } finally {
        newKey.close();
      }
      _deleteSubkeyIfExists(srcKey, item.clsid);
    } finally {
      dstKey.close();
      srcKey.close();
    }
  }

  /// 删除条目（命名空间链接 + CLSID 定义）。
  static void deleteItem(NamespaceItem item) {
    final nsSuffix = item.enabled ? 'NameSpace' : 'NameSpaceDisabled';
    final nsKey = _tryOpen(
      _hiveOf(item.root),
      '$_explorerNs\\${item.itemType}\\$nsSuffix',
      _openAll,
    );
    if (nsKey != null) {
      try {
        _deleteSubkeyIfExists(nsKey, item.clsid);
      } finally {
        nsKey.close();
      }
    }

    final clsidKey = _tryOpen(
      _hiveOf(item.clsidRoot),
      r'SOFTWARE\Classes\CLSID',
      _openAll,
    );
    if (clsidKey != null) {
      try {
        _deleteSubkeyIfExists(clsidKey, item.clsid);
      } finally {
        clsidKey.close();
      }
    }
  }

  /// 在注册表编辑器中跳转到该条目的 CLSID 定义。
  static Future<void> openInRegedit(String clsid, String clsidRoot) async {
    // regedit 仅在启动时读取 Lastkey，所以必须先关掉已运行的实例。
    await Process.run('taskkill', ['/im', 'regedit.exe', '/f']);

    final full =
        'Computer\\${_hiveName(clsidRoot)}\\SOFTWARE\\Classes\\CLSID\\$clsid';
    const lastkeyPath =
        r'Software\Microsoft\Windows\CurrentVersion\Applets\Regedit';
    final key = CURRENT_USER.create(lastkeyPath, config: _createAll);
    try {
      key.setValue('Lastkey', RegistryValue.string(full));
    } finally {
      key.close();
    }

    await Process.start('regedit.exe', []);
  }

  /// 生成一个新的 CLSID（带花括号，大写）。
  static String generateClsid() => '{${const Uuid().v4().toUpperCase()}}';
}

// ---------------------------------------------------------------------------
// 内部实现
// ---------------------------------------------------------------------------

PredefinedRegistryKey _hiveOf(String root) =>
    root.toUpperCase() == 'HKLM' ? LOCAL_MACHINE : CURRENT_USER;

String _hiveName(String root) =>
    root.toUpperCase() == 'HKLM' ? 'HKEY_LOCAL_MACHINE' : 'HKEY_CURRENT_USER';

/// 尝试打开子键，不存在时返回 `null`。
RegistryKey? _tryOpen(
  PredefinedRegistryKey hive,
  String path,
  RegistryOpenConfig config,
) {
  try {
    return hive.open(path, config: config);
  } on WindowsException {
    return null;
  }
}

/// 读取字符串值，缺失或类型不符时返回空串。
String _readString(BaseRegistryKey key, String name, {String path = ''}) {
  try {
    return key.getString(name, path: path) ?? '';
  } on WindowsException {
    return '';
  }
}

/// 去掉图标路径末尾的 `,索引`（展示用；保存时会重新拼上 `,0`）。
String _stripIconIndex(String path) {
  final index = path.lastIndexOf(',');
  return index == -1 ? path : path.substring(0, index);
}

/// 在 HKCU / HKLM 的默认视图与 WOW6432Node（32 位）视图中查找 CLSID 定义。
_ClsidInfo? _findClsid(String clsid) {
  // 注意：CURRENT_USER / LOCAL_MACHINE 是 `final` 顶层变量而非常量，
  // 不能放进 const 列表。
  final hives = <(String, PredefinedRegistryKey)>[
    ('HKCU', CURRENT_USER),
    ('HKLM', LOCAL_MACHINE),
  ];
  const classesPaths = <String>[
    r'SOFTWARE\Classes\CLSID',
    r'SOFTWARE\Classes\WOW6432Node\CLSID',
  ];

  for (final (root, hive) in hives) {
    for (final classesPath in classesPaths) {
      final key = _tryOpen(hive, '$classesPath\\$clsid', _openRead);
      if (key == null) continue;
      try {
        final name = _readString(key, '');
        if (name.isEmpty) continue;
        return (
          clsidRoot: root,
          name: name,
          desc: _readString(key, 'System.ItemAuthors'),
          tip: _readString(key, 'InfoTip'),
          exePath: _readString(key, '', path: r'Shell\Open\Command'),
          iconPath: _readString(key, '', path: 'DefaultIcon'),
        );
      } finally {
        key.close();
      }
    }
  }
  return null;
}

/// 组装单个条目；CLSID 定义缺失或名称为空时返回 `null`。
NamespaceItem? _buildItem(
  BaseRegistryKey nsKey,
  String clsid,
  String root,
  bool disabled,
  String itemType,
) {
  final nsName = _readString(nsKey, clsid);
  final info = _findClsid(clsid);
  if (info == null) return null;

  final name = info.name.isEmpty ? nsName : info.name;
  if (name.isEmpty) return null;

  return NamespaceItem(
    name: name,
    desc: info.desc,
    tip: info.tip,
    exePath: info.exePath,
    iconPath: _stripIconIndex(info.iconPath),
    root: root,
    clsidRoot: info.clsidRoot,
    enabled: !disabled,
    clsid: clsid,
    itemType: itemType,
  );
}

/// 读取某一根键 / 启用状态 / 类型下的所有条目。
List<NamespaceItem> _getItemsInternal(
  String root,
  bool disabled,
  String itemType,
) {
  final nsSuffix = disabled ? 'NameSpaceDisabled' : 'NameSpace';
  final key = _tryOpen(
    _hiveOf(root),
    '$_explorerNs\\$itemType\\$nsSuffix',
    _openRead,
  );
  if (key == null) return const <NamespaceItem>[];

  try {
    final items = <NamespaceItem>[];
    for (final clsid in key.keys) {
      final item = _buildItem(key, clsid, root, disabled, itemType);
      if (item != null) items.add(item);
    }
    return items;
  } finally {
    key.close();
  }
}

void _deleteValueIfExists(BaseRegistryKey key, String name) {
  try {
    key.removeValue(name);
  } on WindowsException {
    // 值不存在，等同于原版 `let _ = delete_value(..)` 的忽略语义。
  }
}

void _deleteSubkeyIfExists(BaseRegistryKey key, String name) {
  try {
    key.removeSubkey(name);
  } on WindowsException {
    // 子键不存在，忽略。
  }
}
