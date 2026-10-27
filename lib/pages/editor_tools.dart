import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/design_system/components/review_frosted_app_bar.dart';
import '../core/utils/haptic_feedback_util.dart';
import 'common.dart';

class ReplyTool {
  const ReplyTool(
    this.title,
    this.before,
    this.after,
    this.placeholder, {
    this.custom = false,
  });
  final String title, before, after, placeholder;
  final bool custom;
  factory ReplyTool.fromJson(Map data) => ReplyTool(
    data['title'] as String,
    data['before'] as String? ?? '',
    data['after'] as String? ?? '',
    data['placeholder'] as String? ?? '',
    custom: data['custom'] == true,
  );
  Map<String, dynamic> toJson() => {
    'title': title,
    'before': before,
    'after': after,
    'placeholder': placeholder,
    'custom': custom,
  };
}

const defaultReplyTools = [
  ReplyTool('加粗', '[b]', '[/b]', '文字'),
  ReplyTool('斜体', '[i]', '[/i]', '文字'),
  ReplyTool('下划线', '[u]', '[/u]', '文字'),
  ReplyTool('删除线', '[s]', '[/s]', '文字'),
  ReplyTool('字号文字', '[size=4]', '[/size]', '文字'),
  ReplyTool('颜色文字', '[color=#ff0000]', '[/color]', '文字'),
  ReplyTool('彩色文字', '[color=#00a080]', '[/color]', '文字'),
  ReplyTool('URL 超链接', '[url]', '[/url]', 'https://'),
  ReplyTool('Email 超链接', '[email]', '[/email]', 'name@example.com'),
  ReplyTool('网络图片', '[img]', '[/img]', 'https://'),
  ReplyTool('水平线', '[hr]', '', ''),
  ReplyTool('对齐文本', '[align=center]', '[/align]', '文字'),
  ReplyTool('代码文本', '[code]', '[/code]', '代码'),
  ReplyTool('引用文本', '[quote]', '[/quote]', '引用'),
  ReplyTool('隐藏文本', '[hide]', '[/hide]', '隐藏内容'),
  ReplyTool('网络视频', '[media=mp4,500,375]', '[/media]', 'https://'),
  ReplyTool('表格', '[table][tr][td]', '[/td][/tr][/table]', '内容'),
  ReplyTool('列表', '[list][*]', '[/list]', '内容'),
  ReplyTool('联系QQ', '[qq]', '[/qq]', 'QQ号码'),
];

List<ReplyTool> loadReplyTools(SharedPreferences prefs) {
  try {
    final raw = prefs.getString('replyTools');
    if (raw != null) {
      final result = (jsonDecode(raw) as List)
          .whereType<Map>()
          .map(ReplyTool.fromJson)
          .toList();
      if (result.isNotEmpty) return result;
    }
  } catch (_) {}
  return List.of(defaultReplyTools);
}

void applyReplyTool(TextEditingController controller, ReplyTool tool) {
  final selection = controller.selection;
  final start = selection.isValid ? selection.start : controller.text.length;
  final end = selection.isValid ? selection.end : controller.text.length;
  final content = tool.custom
      ? tool.placeholder
      : start == end
      ? tool.placeholder
      : controller.text.substring(start, end);
  final inserted = tool.before + content + tool.after;
  controller.value = TextEditingValue(
    text: controller.text.replaceRange(start, end, inserted),
    selection: tool.custom || content.isEmpty
        ? TextSelection.collapsed(offset: start + inserted.length)
        : TextSelection(
            baseOffset: start + tool.before.length,
            extentOffset: start + tool.before.length + content.length,
          ),
  );
}

class ComposerTools extends StatefulWidget {
  const ComposerTools({
    required this.prefs,
    required this.controller,
    required this.onApplied,
    super.key,
  });
  final SharedPreferences prefs;
  final TextEditingController controller;
  final VoidCallback onApplied;
  @override
  State<ComposerTools> createState() => _ComposerToolsState();
}

class _ComposerToolsState extends State<ComposerTools> {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 8,
            children: [
              for (final tool in loadReplyTools(widget.prefs))
                ActionChip(
                  label: Text(tool.title),
                  onPressed: () {
                    applyReplyTool(widget.controller, tool);
                    widget.onApplied();
                  },
                ),
            ],
          ),
        ),
      ),
      IconButton(
        tooltip: '编辑回复菜单',
        icon: const Icon(Icons.tune),
        onPressed: () async {
          await push(context, ReplyToolsPage(widget.prefs));
          if (mounted) setState(() {});
        },
      ),
    ],
  );
}

class ReplyToolsPage extends StatefulWidget {
  const ReplyToolsPage(this.prefs, {super.key});
  final SharedPreferences prefs;
  @override
  State<ReplyToolsPage> createState() => _ReplyToolsPageState();
}

class _ReplyToolsPageState extends State<ReplyToolsPage> {
  late final tools = loadReplyTools(widget.prefs);
  Future<void> save() async {
    await widget.prefs.setString(
      'replyTools',
      jsonEncode(tools.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> add() async {
    final title = TextEditingController(), content = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加快捷回复'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              maxLength: 20,
              decoration: const InputDecoration(labelText: '菜单名称'),
            ),
            TextField(
              controller: content,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '回复内容'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isNotEmpty && content.text.isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      setState(
        () => tools.add(
          ReplyTool(title.text.trim(), '', '', content.text, custom: true),
        ),
      );
      await save();
    }
    title.dispose();
    content.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ReviewFrostedAppBar(
      title: const Text('编辑回复菜单'),
      actions: [
        IconButton(
          tooltip: '添加快捷回复',
          onPressed: add,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: tools.length,
      onReorderStart: (_) => HapticFeedbackUtil.medium(),
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          tools.insert(newIndex, tools.removeAt(oldIndex));
        });
        save();
      },
      itemBuilder: (context, index) {
        final tool = tools[index];
        return ListTile(
          key: ObjectKey(tool),
          leading: const Icon(Icons.drag_handle),
          title: Text(tool.title),
          subtitle: tool.custom
              ? Text(
                  tool.placeholder,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: tool.custom
              ? IconButton(
                  tooltip: '删除快捷回复',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() => tools.removeAt(index));
                    save();
                  },
                )
              : null,
        );
      },
    ),
  );
}
