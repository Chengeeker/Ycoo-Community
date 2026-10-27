import 'package:flutter/material.dart';

import '../core/design_system/components/review_frosted_app_bar.dart';
import '../core/design_system/components/review_switch_tile.dart';
import '../data/site.dart';
import '../settings.dart';
import 'common.dart';
import 'login.dart';

class ReadingSettingsPage extends StatelessWidget {
  const ReadingSettingsPage(this.site, this.settings, {super.key});
  final Site site;
  final Settings settings;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ReviewFrostedAppBar(title: Text('阅读与社区功能')),
    body: ListenableBuilder(
      listenable: settings,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          ReviewSwitchTile(
            title: '自动签到',
            summary: '登录后每次打开应用时尝试签到，每天成功后不再重复',
            value: settings.prefs.getBool('autoSignIn') ?? false,
            onChanged: (value) async {
              if (value && !site.loggedIn) await push(context, LoginPage(site));
              if (value && !site.loggedIn) return;
              await settings.set('autoSignIn', value);
            },
          ),
          ReviewSwitchTile(
            title: '自动加载回复',
            summary: '接近帖子末尾时加载下一页回复',
            value: settings.prefs.getBool('autoReplies') ?? true,
            onChanged: (value) => settings.set('autoReplies', value),
          ),
          ReviewSwitchTile(
            title: 'URL 自动链接',
            summary: '将正文中的 HTTP 和 HTTPS 纯文本网址变为可点击链接',
            value: settings.prefs.getBool('linkify') ?? true,
            onChanged: (value) => settings.set('linkify', value),
          ),
          ReviewSwitchTile(
            title: '显示 FPS',
            summary: '在应用左上角显示当前界面帧率',
            value: settings.prefs.getBool('showFps') ?? false,
            onChanged: (value) => settings.set('showFps', value),
          ),
        ],
      ),
    ),
  );
}
