import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/pages/common.dart';
import 'package:yuan_community/pages/thread.dart';

class DeferredThreadSite extends Site {
  DeferredThreadSite(super.prefs);
  final supplement = Completer<Response<dynamic>>();

  @override
  Future<Map<String, dynamic>> api(
    String module, {
    Map<String, dynamic> query = const {},
    Map<String, dynamic>? data,
  }) async => {
    'thread': {'subject': '公告标题', 'views': '40', 'replies': '0'},
    'forum_threadpay': '0',
    'fid': '42',
    'ppp': '10',
    'postlist': [
      {
        'pid': '77',
        'first': '1',
        'author': 'admin',
        'authorid': '1',
        'dateline': '现在',
        'number': '1',
        'message': '完整正文',
      },
    ],
  };

  @override
  Future<Response<dynamic>> request(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
    int redirects = 0,
  }) => supplement.future;
}

void main() {
  for (final state in ['ready', 'late', 'sessionChanged']) {
    testWidgets('thread commits once with supplemental state=$state', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final site = DeferredThreadSite(prefs);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        Site.cookies,
        (_) async => '',
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          Site.cookies,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ThreadPage(site, const Topic(id: '42', title: '公告标题')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('完整正文'), findsNothing);
      if (state == 'late') {
        await tester.pump(const Duration(milliseconds: 801));
        await tester.pumpAndSettle();
        expect(find.text('完整正文'), findsOneWidget);
      } else if (state == 'sessionChanged') {
        site.sessionEpoch++;
      }
      site.supplement.complete(
        Response<dynamic>(
          requestOptions: RequestOptions(path: '/forum.php'),
          data: '<div id="pid77"><div class="top_lev">Lv.16</div><div class="comiis_messages">完整正文</div></div>',
        ),
      );
      await tester.pumpAndSettle();
      if (state == 'sessionChanged') {
        expect(find.text('完整正文'), findsNothing);
        expect(find.textContaining('登录状态已变化'), findsOneWidget);
      } else {
        expect(find.text('完整正文'), findsOneWidget);
        expect(
          find.textContaining('Lv.16'),
          state == 'late' ? findsNothing : findsOneWidget,
        );
        expect(find.text('公告标题'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  test('mobile body restores frames only for matching authorized content', () {
    const source =
        '<div id="pid1"><div class="comiis_messages"><div class="showhide">正文<a href="https://example.com/a.json">链接</a></div></div></div>';
    final posts = <Map>[
      {'pid': '1', 'message': '正文<a href="https://example.com/a.json">链接</a>'},
    ];
    enrichThreadPosts(posts, source);
    expect(posts.single['displayMessage'], isNull);
    enrichThreadPosts(posts, source, allowBody: true);
    expect(forumPostHtml(posts.single), contains('showhide'));
    final locked = <Map>[
      {'pid': '1', 'message': '付费主题'},
    ];
    enrichThreadPosts(locked, source, allowBody: true);
    expect(locked.single['displayMessage'], isNull);
  });
  test('mobile metadata matches PID and never replaces permitted API body', () {
    final posts = <Map>[
      {'pid': '2962874', 'first': '1', 'message': 'API已授权正文'},
      {'pid': '2962889', 'first': '0', 'message': '回复'},
      {'pid': '0', 'first': '1', 'message': '其他帖子'},
    ];
    enrichThreadPosts(
      posts,
      File('test/fixtures/thread-154095.html').readAsStringSync(),
    );
    expect(posts[0]['message'], 'API已授权正文');
    expect(posts[0]['displayLevel'], 'Lv.2 秀才');
    expect(posts[0]['displayCategory'], '#视频');
    expect(posts[0]['displayCopyright'], contains('版权声明'));
    expect(posts[1]['displayCopyright'], isNull);
    expect(posts[2]['displayLevel'], isNull);
  });
  testWidgets(
    'hidden content and copyright retain distinct native frames and links',
    (tester) async {
      String? link;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlContent(
              '<p>正文</p><div class="showhide"><h3>本帖隐藏的内容：</h3><a href="https://example.com/source.json">链接</a><blockquote>引用</blockquote></div><div id="copyright"><h3>版权声明</h3><p>声明正文</p></div>',
              onLink: (value) => link = value,
            ),
          ),
        ),
      );
      final frames = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration is BoxDecoration);
      expect(frames, hasLength(3));
      final text = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((t) => t.textSpan!.toPlainText())
          .join();
      expect(text, contains('本帖隐藏的内容：'));
      expect(text, contains('版权声明'));
      await tester.tap(find.text('链接', findRichText: true));
      expect(link, 'https://example.com/source.json');
    },
  );
  testWidgets('external JSON first asks and copy preserves the complete URL', (
    tester,
  ) async {
    const url = 'https://example.com/source.json?key=a%2Fb';
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = call.arguments['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openWeb(context, url),
              child: const Text('外链'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('外链'));
    await tester.pumpAndSettle();
    expect(find.text('即将离开源社区'), findsOneWidget);
    expect(find.text('继续访问'), findsOneWidget);
    expect(find.text('浏览器打开'), findsOneWidget);
    expect(find.byType(BrowserPage), findsNothing);
    await tester.tap(find.text('复制链接'));
    await tester.pumpAndSettle();
    expect(copied, url);
    expect(find.byType(BrowserPage), findsNothing);
    await tester.tap(find.text('外链'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('即将离开源社区'))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(BrowserPage), findsNothing);
  });
}
