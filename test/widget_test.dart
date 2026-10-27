import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/main.dart';
import 'package:yuan_community/settings.dart';
import 'package:yuan_community/pages/thread.dart';

class PreviewSite extends Site {
  PreviewSite(super.prefs);
  int topicRequests = 0;
  @override
  Future<void> syncSession() async {}
  @override
  Future<List<Map<String, dynamic>>> forums() async => [
    {
      'fid': '2',
      'name': '书源发布',
      'threads': '3800',
      'posts': '350000',
      'todayposts': '42',
    },
  ];
  @override
  Future<TopicBatch> topics({
    String? fid,
    String view = 'portal',
    int page = 1,
    String? type,
  }) async {
    topicRequests++;
    return TopicBatch(const [
      Topic(
        id: '1',
        title: '分享与阅读，发现更多好内容',
        author: '源社区',
        forum: '书源发布',
        time: '刚刚',
        replies: '12',
        views: '268',
      ),
      Topic(
        id: '2',
        title: '源社区权限组晋升体系说明',
        author: 'admin',
        forum: '站务公告',
        time: '1 小时前',
        replies: '38',
        views: '1024',
        pinned: true,
      ),
    ], false);
  }
}

class ComposeSite extends Site {
  ComposeSite(super.prefs) {
    uid = '1';
  }
  bool fail = true;
  @override
  Future<Map<String, dynamic>> api(
    String module, {
    Map<String, dynamic> query = const {},
    Map<String, dynamic>? data,
  }) async {
    if (module == 'checkpost') return {};
    if (fail) throw SiteException('服务器拒绝发布');
    return {'tid': '1', 'pid': '2'};
  }
}

void main() {
  testWidgets(
    'M3 home, navigation, persistent settings and cache-first restoration',
    (tester) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final font = FontLoader('Roboto')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/msyh.ttc').readAsBytesSync(),
              ),
            ),
          );
        await font.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final site = PreviewSite(prefs);
      final settings = Settings(prefs);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: YuanApp(settings: settings, site: site),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('分享与阅读，发现更多好内容'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        Theme.of(tester.element(find.text('源社区').first)).useMaterial3,
        true,
      );
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/previews').createSync(recursive: true);
        File('build/previews/home.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.text('社区').last);
      await tester.pumpAndSettle();
      expect(find.text('书源发布'), findsWidgets);
      await tester.tap(find.text('我的').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('设置').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('个性化').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('使用悬浮底栏'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('使用悬浮底栏'));
      await tester.pumpAndSettle();
      expect(settings.floating, false);
      expect(prefs.getBool('floating'), false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final restored = PreviewSite(prefs);
      await tester.pumpWidget(YuanApp(settings: settings, site: restored));
      await tester.pumpAndSettle();
      expect(restored.topicRequests, 0);
      expect(find.text('分享与阅读，发现更多好内容'), findsOneWidget);
    },
  );
  testWidgets(
    'failed publish preserves input and confirmed publish removes draft',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final site = ComposeSite(prefs);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ComposePage(site, fid: '2'),
                  ),
                ),
                child: const Text('打开发帖'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开发帖'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '测试标题');
      await tester.enterText(find.byType(TextField).last, '测试正文');
      await tester.tap(find.text('发布'));
      await tester.pumpAndSettle();
      expect(find.textContaining('服务器拒绝发布'), findsOneWidget);
      expect(prefs.getString('draft.1.2.message'), '测试正文');
      site.fail = false;
      await tester.tap(find.text('发布'));
      await tester.pumpAndSettle();
      expect(find.text('打开发帖'), findsOneWidget);
      expect(prefs.getString('draft.1.2.message'), isNull);
      expect(prefs.getString('draft.1.2.subject'), isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
