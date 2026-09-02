import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/namespace_item.dart';
import '../services/registry_service.dart';

/// 打开新增 / 编辑对话框，返回保存后的条目；取消时返回 `null`。
Future<NamespaceItem?> showItemEditor(
  BuildContext context, {
  NamespaceItem? item,
}) {
  return showDialog<NamespaceItem?>(
    context: context,
    // 表单内容较多，避免误点遮罩丢失输入。
    barrierDismissible: false,
    builder: (context) => ItemEditorDialog(item: item),
  );
}

/// 条目编辑表单。
class ItemEditorDialog extends StatefulWidget {
  const ItemEditorDialog({super.key, this.item});

  /// 传入则为编辑，否则为新增。
  final NamespaceItem? item;

  @override
  State<ItemEditorDialog> createState() => _ItemEditorDialogState();
}

class _ItemEditorDialogState extends State<ItemEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _tipController;
  late final TextEditingController _iconController;
  late final TextEditingController _exeController;

  late String _itemType;
  late String _root;
  late String _clsidRoot;
  late bool _enabled;

  /// 新增时立即生成，便于在保存前查看 / 复制。
  late final String _clsid;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descController = TextEditingController(text: item?.desc ?? '');
    _tipController = TextEditingController(text: item?.tip ?? '');
    _iconController = TextEditingController(text: item?.iconPath ?? '');
    _exeController = TextEditingController(text: item?.exePath ?? '');
    _itemType = item?.itemType ?? 'MyComputer';
    _root = item?.root ?? 'HKCU';
    _clsidRoot = item?.clsidRoot ?? 'HKCU';
    _enabled = item?.enabled ?? true;
    _clsid = item?.clsid ?? RegistryService.generateClsid();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _tipController.dispose();
    _iconController.dispose();
    _exeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      NamespaceItem(
        name: _nameController.text.trim(),
        desc: _descController.text.trim(),
        tip: _tipController.text.trim(),
        exePath: _exeController.text.trim(),
        iconPath: _iconController.text.trim(),
        root: _root,
        clsidRoot: _clsidRoot,
        enabled: _enabled,
        clsid: _clsid,
        itemType: _itemType,
      ),
    );
  }

  Future<void> _pickFile({
    required TextEditingController controller,
    required String dialogTitle,
    required List<String> extensions,
  }) async {
    final file = await FilePicker.pickFile(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    final path = file?.path;
    if (path == null) return;
    if (!mounted) return;
    setState(() => controller.text = path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.item != null;
    final needsAdmin = _root == 'HKLM' || _clsidRoot == 'HKLM';

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 660),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_outlined : Icons.add_circle_outline,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? '编辑条目' : '新增条目',
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '名称 *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        autofocus: true,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? '名称不能为空'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: '描述',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _tipController,
                        decoration: const InputDecoration(
                          labelText: '悬停提示 (InfoTip)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PathField(
                        controller: _iconController,
                        labelText: '图标路径 (.exe/.ico/.dll)',
                        onBrowse: () => _pickFile(
                          controller: _iconController,
                          dialogTitle: '选择图标文件',
                          extensions: const ['exe', 'ico', 'dll'],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PathField(
                        controller: _exeController,
                        labelText: '打开命令 (exe 路径，可空)',
                        onBrowse: () => _pickFile(
                          controller: _exeController,
                          dialogTitle: '选择可执行文件',
                          extensions: const ['exe', 'bat', 'cmd', 'lnk'],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<String>(
                              value: _itemType,
                              decoration: const InputDecoration(
                                labelText: '位置',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'MyComputer',
                                  child: Text('此电脑'),
                                ),
                                DropdownMenuItem(
                                  value: 'Desktop',
                                  child: Text('桌面侧边栏'),
                                ),
                              ],
                              onChanged: (value) => setState(
                                () => _itemType = value ?? _itemType,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<String>(
                              value: _root,
                              decoration: const InputDecoration(
                                labelText: '命名空间根',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'HKCU',
                                  child: Text('当前用户 (HKCU)'),
                                ),
                                DropdownMenuItem(
                                  value: 'HKLM',
                                  child: Text('全部用户 (HKLM)'),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _root = value ?? _root),
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<String>(
                              value: _clsidRoot,
                              decoration: const InputDecoration(
                                labelText: 'CLSID 根',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'HKCU',
                                  child: Text('当前用户 (HKCU)'),
                                ),
                                DropdownMenuItem(
                                  value: 'HKLM',
                                  child: Text('全部用户 (HKLM)'),
                                ),
                              ],
                              onChanged: (value) => setState(
                                () => _clsidRoot = value ?? _clsidRoot,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: _enabled,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('启用'),
                        onChanged: (value) =>
                            setState(() => _enabled = value),
                      ),
                      Text(
                        'CLSID: $_clsid',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      if (needsAdmin) ...[
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '选择 HKLM 需要以管理员身份运行本程序，否则保存会失败（拒绝访问）。',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.tertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 带「浏览」按钮的路径输入框。
class _PathField extends StatelessWidget {
  const _PathField({
    required this.controller,
    required this.labelText,
    required this.onBrowse,
  });

  final TextEditingController controller;
  final String labelText;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: labelText,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: OutlinedButton(onPressed: onBrowse, child: const Text('浏览')),
        ),
      ],
    );
  }
}
