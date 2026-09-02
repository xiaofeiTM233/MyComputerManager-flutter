import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:win32/win32.dart' show WindowsException;

import 'dialogs/item_editor_dialog.dart';
import 'models/namespace_item.dart';
import 'services/reg_exporter.dart';
import 'services/registry_service.dart';
import 'widgets/item_tile.dart';

void main() => runApp(const MyComputerManagerApp());

class MyComputerManagerApp extends StatelessWidget {
  const MyComputerManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyComputerManager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();

  List<NamespaceItem> _items = const <NamespaceItem>[];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 注册表读取量很小（几十个键），直接在 UI 线程执行即可。
      final items = RegistryService.getItems();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _describe(error);
        _loading = false;
      });
    }
  }

  Future<void> _toggle(NamespaceItem item, bool enabled) async {
    try {
      RegistryService.setEnabled(item, enabled);
      await _reload();
    } catch (error) {
      await _showMessage(_describe(error), isError: true);
    }
  }

  Future<void> _openEditor(NamespaceItem? item) async {
    final result = await showItemEditor(context, item: item);
    if (result == null || !mounted) return;
    try {
      RegistryService.updateItem(result);
      await _reload();
    } catch (error) {
      await _showMessage(_describe(error), isError: true);
    }
  }

  Future<void> _delete(NamespaceItem item) async {
    final confirmed = await _confirm('确认删除「${item.name}」吗？此操作不可恢复。');
    if (!confirmed || !mounted) return;
    try {
      RegistryService.deleteItem(item);
      await _reload();
    } catch (error) {
      await _showMessage(_describe(error), isError: true);
    }
  }

  Future<void> _openInRegedit(NamespaceItem item) async {
    try {
      await RegistryService.openInRegedit(item.clsid, item.clsidRoot);
    } catch (error) {
      await _showMessage(_describe(error), isError: true);
    }
  }

  Future<void> _export(NamespaceItem item) async {
    final bytes = encodeRegFile(buildRegContent(item));
    final uri = await FilePicker.saveFile(
      dialogTitle: '导出注册表文件',
      fileName: '${_safeFileName(item.name)}.reg',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: const ['reg'],
    );
    if (uri == null || !mounted) return;
    await _showMessage('已导出到 ${uri.toFilePath()}');
  }

  /// 按「类型|根」分组，并应用搜索过滤。
  Map<String, List<NamespaceItem>> _groupedItems() {
    final query = _searchController.text.trim().toLowerCase();
    final groups = <String, List<NamespaceItem>>{};
    for (final item in _items) {
      if (query.isNotEmpty &&
          !item.name.toLowerCase().contains(query) &&
          !item.desc.toLowerCase().contains(query) &&
          !item.clsid.toLowerCase().contains(query)) {
        continue;
      }
      groups
          .putIfAbsent('${item.itemType}|${item.root}', () => <NamespaceItem>[])
          .add(item);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyComputerManager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _reload,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _openEditor(null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新增'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(controller: _searchController),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error case final error?) {
      return _ErrorView(message: error, onRetry: _reload);
    }

    final groups = _groupedItems();
    if (groups.isEmpty) {
      return const _EmptyView();
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final entry in groups.entries) ...[
          _GroupHeader(
            label: _groupLabel(entry.value.first),
            count: entry.value.length,
          ),
          for (final item in entry.value)
            ItemTile(
              key: ValueKey<String>(item.uid),
              item: item,
              onToggle: (value) => _toggle(item, value),
              onEdit: () => _openEditor(item),
              onOpenRegedit: () => _openInRegedit(item),
              onExport: () => _export(item),
              onDelete: () => _delete(item),
            ),
        ],
      ],
    );
  }

  String _groupLabel(NamespaceItem sample) {
    final type = sample.itemType == 'MyComputer' ? '此电脑' : '桌面侧边栏';
    final root = sample.root.toUpperCase() == 'HKLM' ? '全部用户' : '当前用户';
    return '$type · $root';
  }

  Future<void> _showMessage(String text, {bool isError = false}) {
    if (!mounted) return Future<void>.value();
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isError ? '错误' : '提示'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(String text) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('警告'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// 把异常翻译成用户能看懂的文案。
///
/// [WindowsException.message] 会返回系统提供的错误描述（如「拒绝访问」），
/// 比直接打印 HRESULT 有用得多。
String _describe(Object error) {
  if (error is WindowsException) {
    final message = error.message;
    return message.isEmpty ? error.toString() : message;
  }
  return error.toString();
}

/// 去掉 Windows 文件名不允许的字符。
String _safeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return cleaned.isEmpty ? 'export' : cleaned;
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: '搜索名称 / 描述 / CLSID',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          border: const OutlineInputBorder(),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: '清空',
                    onPressed: () => controller.clear(),
                  ),
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text('$count', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            '没有找到条目。点击右上角「新增」添加自己的快捷方式，或「刷新」重新读取。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text('读取注册表失败', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
