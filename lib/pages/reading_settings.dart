import 'package:flutter/material.dart';

import '../core/design_system/components/review_frosted_app_bar.dart';
import '../core/design_system/components/review_switch_tile.dart';
import '../core/widgets/app_section_card.dart';
import '../data/site.dart';
import '../settings.dart';

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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AppSectionCard(
            child: Column(
              children: [
                ReviewSwitchTile(
                  title: '自动加载回复',
                  leading: const Icon(Icons.forum_outlined),
                  summary: '接近帖子末尾时加载下一页回复',
                  value: settings.prefs.getBool('autoReplies') ?? true,
                  onChanged: (value) => settings.set('autoReplies', value),
                ),
                ReviewSwitchTile(
                  title: 'URL 自动链接',
                  leading: const Icon(Icons.link_rounded),
                  summary: '将正文中的 HTTP 和 HTTPS 纯文本网址变为可点击链接',
                  value: settings.prefs.getBool('linkify') ?? true,
                  onChanged: (value) => settings.set('linkify', value),
                ),
                ReviewSwitchTile(
                  title: '显示 FPS',
                  leading: const Icon(Icons.speed_rounded),
                  summary: '在应用左上角显示当前界面帧率',
                  value: settings.prefs.getBool('showFps') ?? false,
                  onChanged: (value) => settings.set('showFps', value),
                ),
                ReviewSwitchTile(
                  title: '自动签到',
                  summary: '登录后启动应用时在后台检查并签到，不打断当前页面',
                  leading: const Icon(Icons.event_available_outlined),
                  value: settings.prefs.getBool('autoSignIn') ?? false,
                  onChanged: (value) => settings.set('autoSignIn', value),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
