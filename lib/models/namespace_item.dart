/// 资源管理器命名空间条目模型。
///
/// 字段与 Tauri/Rust 版 `src-tauri/src/registry.rs` 中的 `NamespaceItem`
/// 逐一对应，JSON 键名同样使用驼峰命名（camelCase），便于两版之间对照。
class NamespaceItem {
  const NamespaceItem({
    required this.name,
    this.desc = '',
    this.tip = '',
    this.exePath = '',
    this.iconPath = '',
    required this.root,
    required this.clsidRoot,
    this.enabled = true,
    required this.clsid,
    required this.itemType,
  });

  /// 显示名称（`CLSID` 下的默认值）。
  final String name;

  /// 作者 / 描述，对应注册表值 `System.ItemAuthors`。
  final String desc;

  /// 悬停提示，对应注册表值 `InfoTip`。
  final String tip;

  /// 打开命令，对应 `Shell\Open\Command` 的默认值。
  final String exePath;

  /// 图标路径，不含末尾的 `,索引`（展示时去掉，保存时补回 `,0`）。
  final String iconPath;

  /// 命名空间链接所在根：`HKCU` / `HKLM`。
  final String root;

  /// CLSID 定义所在根：`HKCU` / `HKLM`。
  final String clsidRoot;

  /// 是否启用；`false` 时位于 `NameSpaceDisabled`。
  final bool enabled;

  /// CLSID，含花括号。
  final String clsid;

  /// 类型：`MyComputer`（此电脑） / `Desktop`（桌面侧边栏）。
  final String itemType;

  /// 列表内的唯一标识。
  ///
  /// 同一个 CLSID 完全可以同时挂在不同的根与类型下，因此四元组才是唯一键。
  String get uid => '$root|$clsidRoot|$itemType|$clsid';

  factory NamespaceItem.fromJson(Map<String, Object?> json) => NamespaceItem(
    name: json['name'] as String? ?? '',
    desc: json['desc'] as String? ?? '',
    tip: json['tip'] as String? ?? '',
    exePath: json['exePath'] as String? ?? '',
    iconPath: json['iconPath'] as String? ?? '',
    root: json['root'] as String? ?? 'HKCU',
    clsidRoot: json['clsidRoot'] as String? ?? 'HKCU',
    enabled: json['enabled'] as bool? ?? true,
    clsid: json['clsid'] as String? ?? '',
    itemType: json['itemType'] as String? ?? 'MyComputer',
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'desc': desc,
    'tip': tip,
    'exePath': exePath,
    'iconPath': iconPath,
    'root': root,
    'clsidRoot': clsidRoot,
    'enabled': enabled,
    'clsid': clsid,
    'itemType': itemType,
  };

  NamespaceItem copyWith({
    String? name,
    String? desc,
    String? tip,
    String? exePath,
    String? iconPath,
    String? root,
    String? clsidRoot,
    bool? enabled,
    String? clsid,
    String? itemType,
  }) => NamespaceItem(
    name: name ?? this.name,
    desc: desc ?? this.desc,
    tip: tip ?? this.tip,
    exePath: exePath ?? this.exePath,
    iconPath: iconPath ?? this.iconPath,
    root: root ?? this.root,
    clsidRoot: clsidRoot ?? this.clsidRoot,
    enabled: enabled ?? this.enabled,
    clsid: clsid ?? this.clsid,
    itemType: itemType ?? this.itemType,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NamespaceItem &&
          other.name == name &&
          other.desc == desc &&
          other.tip == tip &&
          other.exePath == exePath &&
          other.iconPath == iconPath &&
          other.root == root &&
          other.clsidRoot == clsidRoot &&
          other.enabled == enabled &&
          other.clsid == clsid &&
          other.itemType == itemType;

  @override
  int get hashCode => Object.hash(
    name,
    desc,
    tip,
    exePath,
    iconPath,
    root,
    clsidRoot,
    enabled,
    clsid,
    itemType,
  );

  @override
  String toString() => 'NamespaceItem($name, $clsid, $itemType, $root)';
}
