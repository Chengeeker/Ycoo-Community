import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/site.dart';
import '../core/design_system/components/review_frosted_app_bar.dart';
import 'common.dart';
import 'login.dart';
import 'thread.dart';

class NativeCloudPage extends StatefulWidget {
  const NativeCloudPage(this.site, {super.key});
  final Site site;
  @override
  State<NativeCloudPage> createState() => _NativeCloudPageState();
}

class _NativeCloudPageState extends State<NativeCloudPage> {
  String hash = '', cid = '0', parent = '0', search = '';
  int page = 1, maxPage = 1;
  bool busy = false;
  Object? error;
  Map config = {}, user = {};
  List<Map> folders = [], files = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<Map> call(Map<String, dynamic> values) async {
    if (!widget.site.loggedIn) throw SiteException('请先登录');
    final response = await widget.site.request(
      '/plugin.php',
      query: {'id': 'bphp_clouds:api', 'mobile': 2},
      data: {...values, 'formhash': hash},
    );
    final decoded = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (decoded is! Map || '${decoded['sta']}' != '1') {
      throw SiteException(
        decoded is Map ? '${decoded['msg'] ?? '云盘操作未确认'}' : '云盘返回内容无法识别',
      );
    }
    return decoded;
  }

  Future<void> load({bool reset = false}) async {
    if (busy) return;
    if (reset) page = 1;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!widget.site.loggedIn) throw SiteException('请先登录');
      if (hash.isEmpty) {
        final source = await widget.site.request(
          '/plugin.php',
          query: {
            'id': 'bphp_clouds:index',
            'mobile': 2,
            '_session': DateTime.now().microsecondsSinceEpoch,
          },
        );
        hash =
            RegExp(r'''['"]formhash['"]\s*:\s*['"]([a-zA-Z0-9]{8})['"]''')
                .firstMatch('${source.data}')
                ?.group(1) ??
            widget.site.formhash;
        if (!RegExp(r'^[a-zA-Z0-9]{8}$').hasMatch(hash)) {
          throw SiteException('无法确认云盘凭据，请重新登录');
        }
        final initial = await Future.wait([
          call({'ac': 'config'}),
          call({'ac': 'getUserInfo'}),
        ]);
        config = initial[0]['data'] is Map ? initial[0]['data'] as Map : {};
        user = initial[1]['data'] is Map ? initial[1]['data'] as Map : {};
      }
      final result = await call({
        'ac': 'fileDisplay',
        'cid': cid,
        'type': 'all',
        'page': page,
        'searchKey': search,
      });
      if (!mounted) return;
      setState(() {
        folders = (result['cList'] as List? ?? []).whereType<Map>().toList();
        files = (result['fList'] as List? ?? []).whereType<Map>().toList();
        parent = '${result['pid'] ?? 0}';
        maxPage = number(result['maxPage']);
        busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          busy = false;
        });
      }
    }
  }

  Future<String?> input(String title, {String initial = ''}) =>
      showDialog<String>(
        context: context,
        builder: (_) => _CloudInputDialog(title, initial),
      );
  Future<void> perform(Map<String, dynamic> values) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await call(values);
      if (mounted) feedback(context, '${result['msg'] ?? '操作已完成'}');
    } catch (e) {
      if (mounted) feedback(context, e);
    }
    if (mounted) {
      setState(() => busy = false);
      load();
    }
  }

  Future<void> upload() async {
    try {
      if (config['storageType'] != 'local') {
        feedback(context, '该云盘使用第三方存储，当前原生上传仅支持本地存储');
        return;
      }
      final file = await chooseUploadFile();
      if (file == null || !mounted) return;
      await perform({
        'ac': 'upload',
        'cid': cid,
        'flag': 2,
        'file': file,
        'rePath': '',
      });
    } catch (e) {
      if (mounted) feedback(context, e);
    }
  }

  Future<void> action(String action, Map item, bool folder) async {
    final name = '${folder ? item['c_name'] : item['name']}';
    if (action == 'rename') {
      final value = await input('重命名', initial: name);
      if (value != null && value.isNotEmpty && value != name) {
        await perform({
          'ac': 'reName',
          'name': value,
          'sid': folder ? item['cid'] : item['id'],
          'pid': folder ? item['pid'] : item['cid'],
          'type': folder ? 'classify' : 'file',
        });
      }
    } else if (action == 'delete') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除云盘内容？'),
          content: Text(name),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (yes == true) {
        await perform({
          'ac': 'del',
          if (folder) 'cid[]': [item['cid']] else 'fid[]': [item['id']],
        });
      }
    } else if (action == 'download') {
      final uri = Uri.tryParse('${item['link'] ?? ''}');
      if (uri != null &&
          ['https', 'http'].contains(uri.scheme) &&
          uri.userInfo.isEmpty &&
          mounted) {
        await showDownloadDialog(context, uri.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ReviewFrostedAppBar(
      title: const Text('云盘'),
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: widget.site.loggedIn
        ? FloatingActionButton(
            onPressed: busy ? null : upload,
            tooltip: '上传文件',
            child: const Icon(Icons.upload_file),
          )
        : null,
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (busy) const LinearProgressIndicator(),
        if (!widget.site.loggedIn)
          FilledButton.icon(
            onPressed: () async {
              await push(context, LoginPage(widget.site));
              if (mounted && widget.site.loggedIn) load();
            },
            icon: const Icon(Icons.login),
            label: const Text('登录云盘'),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('$error'),
          ),
        if (widget.site.loggedIn) ...[
          TextField(
            decoration: const InputDecoration(
              labelText: '搜索文件',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (value) {
              search = value;
              load(reset: true);
            },
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: busy || cid == '0'
                    ? null
                    : () {
                        cid = parent;
                        load(reset: true);
                      },
                icon: const Icon(Icons.arrow_upward),
                label: const Text('上一级'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        cid = '0';
                        load(reset: true);
                      },
                child: const Text('根目录'),
              ),
              const Spacer(),
              IconButton(
                tooltip: '新建文件夹',
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: busy
                    ? null
                    : () async {
                        final name = await input('新建文件夹');
                        if (name?.isNotEmpty == true) {
                          perform({
                            'ac': 'addClassName',
                            'addClassName': name,
                            'cid': cid,
                          });
                        }
                      },
              ),
            ],
          ),
          if (user.isNotEmpty)
            Text(
              '已用 ${user['capacity'] ?? '-'} / ${user['spaceSize'] ?? '-'} 字节',
            ),
          for (final folder in folders)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text('${folder['c_name'] ?? ''}'),
              onTap: busy
                  ? null
                  : () {
                      cid = '${folder['cid']}';
                      load(reset: true);
                    },
              trailing: menu(folder, true),
            ),
          for (final file in files)
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text('${file['name'] ?? ''}'),
              subtitle: Text('${file['sizeText'] ?? file['size'] ?? ''}'),
              onTap: () =>
                  routeLink(context, widget.site, '${file['link'] ?? ''}'),
              trailing: menu(file, false),
            ),
          if (!busy && error == null && folders.isEmpty && files.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Text('暂无文件')),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: busy || page <= 1
                    ? null
                    : () {
                        page--;
                        load();
                      },
                child: const Text('上一页'),
              ),
              Text('$page / ${maxPage < 1 ? 1 : maxPage}'),
              TextButton(
                onPressed: busy || page >= maxPage
                    ? null
                    : () {
                        page++;
                        load();
                      },
                child: const Text('下一页'),
              ),
            ],
          ),
        ],
      ],
    ),
  );
  Widget menu(Map item, bool folder) => PopupMenuButton<String>(
    enabled: !busy,
    onSelected: (value) => action(value, item, folder),
    itemBuilder: (_) => [
      if (!folder) const PopupMenuItem(value: 'download', child: Text('下载')),
      const PopupMenuItem(value: 'rename', child: Text('重命名')),
      const PopupMenuItem(value: 'delete', child: Text('删除')),
    ],
  );
}

class _CloudInputDialog extends StatefulWidget {
  const _CloudInputDialog(this.title, this.initial);
  final String title, initial;
  @override
  State<_CloudInputDialog> createState() => _CloudInputDialogState();
}

class _CloudInputDialogState extends State<_CloudInputDialog> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(controller: controller, autofocus: true),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          FocusScope.of(context).unfocus();
          Navigator.pop(context, controller.text.trim());
        },
        child: const Text('确认'),
      ),
    ],
  );
}
