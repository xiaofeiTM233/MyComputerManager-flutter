import 'package:flutter/material.dart';

import '../models/namespace_item.dart';

/// 单个命名空间条目卡片。
///
/// 纯展示组件：所有交互通过回调上抛，由页面统一处理注册表读写与提示。
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onOpenRegedit,
    required this.onExport,
    required this.onDelete,
  });

  final NamespaceItem item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onOpenRegedit;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            _Avatar(name: item.name),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (!item.enabled) ...[
                        const SizedBox(width: 8),
                        const _Badge(text: '已禁用'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.desc.isEmpty ? '（无描述）' : item.desc,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'CLSID: ${item.clsid}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: item.enabled ? '点击禁用' : '点击启用',
              child: Switch(
                value: item.enabled,
                onChanged: onToggle,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '编辑',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.manage_search_outlined),
              tooltip: '在注册表编辑器中打开',
              onPressed: onOpenRegedit,
            ),
            IconButton(
              icon: const Icon(Icons.ios_share_outlined),
              tooltip: '导出 .reg',
              onPressed: onExport,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除',
              color: theme.colorScheme.error,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

/// 由名称派生的色块头像，让列表更易扫读。
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim()[0].toUpperCase();

    return CircleAvatar(
      backgroundColor: _colorFor(name),
      foregroundColor: Colors.white,
      child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  /// 与原版前端 `colorFor` 相同的哈希配色，保证两版观感一致。
  static Color _colorFor(String text) {
    var hash = 0;
    for (final unit in text.codeUnits) {
      hash = (hash * 31 + unit) % 360;
    }
    return HSLColor.fromAHSL(1, hash.toDouble(), 0.55, 0.5).toColor();
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
