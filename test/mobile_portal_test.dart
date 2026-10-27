import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/data/portal.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/pages/home.dart';

class ForumTopicSite extends Site {
  ForumTopicSite(super.prefs);
  final batch = Completer<TopicBatch>();

  @override
  Future<TopicBatch> topics({
    String? fid,
    String view = 'newthread',
    int page = 1,
    String? type,
  }) => batch.future;
}

class PagedLevelSite extends Site {
  PagedLevelSite(super.prefs);
  final calls = <int>[];
  @override
  Future<TopicBatch> topics({
    String? fid,
    String view = 'newthread',
    int page = 1,
    String? type,
  }) async {
    calls.add(page);
    return TopicBatch([
      Topic(
        id: '$page',
        title: '新标题',
        uid: '$page',
        level: 'Lv.7',
        levelColor: page == 1 ? '#333333' : '#4B3E2A',
      ),
    ], page == 1);
  }
}

TopicBatch enrichedForumBatch() => TopicBatch([
  const Topic(
    id: '98450',
    title: '两件事',
    pinned: true,
    author: 'admin',
    uid: '1',
    time: '2026-6-19',
    preview: '公告正文摘要',
  ),
], false);

void main() {
  test('forum compact pinned section precedes the full mobile feed', () {
    final batch = Site.parseMobileTopics(
      File('test/fixtures/mobile-forum.html').readAsStringSync(),
    );
    expect(batch.topics.take(4).map((e) => e.id), [
      '149059',
      '98450',
      '26477',
      '1419',
    ]);
    expect(batch.topics.take(4).every((e) => e.pinned), isTrue);
    expect(batch.topics.any((e) => e.images.isNotEmpty), isTrue);
    final sevenColors = batch.topics
        .where((e) => e.level == 'Lv.7')
        .map((e) => e.levelColor)
        .toSet();
    expect(sevenColors, containsAll(['#333333', '#4B3E2A']));
    expect(batch.topics.map((e) => e.id).toSet().length, batch.topics.length);
  });
  test('pinned forum topics are enriched from the matching API summary', () {
    final api = Topic.fromJson({
      'tid': '98450',
      'subject': '两件事',
      'author': 'admin',
      'authorid': '1',
      'dateline': '2026-6-19',
      'displayorder': '3',
      'message': '请勿发限时收费帖',
      'replies': '24',
      'views': '6566',
    });
    final mobile = const Topic(id: '98450', title: '两件事', pinned: true);
    final merged = mergeForumSummaries([mobile], [api]).single;
    expect(merged.pinned, isTrue);
    expect(merged.author, 'admin');
    expect(merged.uid, '1');
    expect(merged.preview, '请勿发限时收费帖');
    expect(merged.replies, '24');
    expect(merged.views, '6566');
  });
  testWidgets('stale title-only pin cache waits for the enriched forum row', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'cache.v2.0.42.all': '{"items":[{"tid":"98450","subject":"两件事","displayorder":1}],"page":1,"more":true}',
    });
    final prefs = await SharedPreferences.getInstance();
    final site = ForumTopicSite(prefs);
    await tester.pumpWidget(
      MaterialApp(
        home: TopicsPage(site, fid: '42', title: '站务公告'),
      ),
    );
    await tester.pump();
    expect(find.text('置顶 · 两件事'), findsNothing);
    site.batch.complete(enrichedForumBatch());
    await tester.pumpAndSettle();
    expect(find.text('admin'), findsOneWidget);
    expect(find.text('公告正文摘要'), findsOneWidget);
    expect(find.textContaining('UID'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test(
    'mobile client homepage keeps every configured module and its order',
    () {
      final data = PortalData.parse(
        File('test/fixtures/mobile-home.xml').readAsStringSync(),
      );
      expect(data.banners, hasLength(10));
      expect(data.services.map((e) => e.title), [
        '每日签到',
        '开心农场',
        '心情墙',
        '云盘',
        '淘专辑',
      ]);
      expect(data.forums, hasLength(8));
      expect(data.forums.map((e) => e.title), [
        '书源发布',
        '精品软件',
        '订阅源区',
        '休闲专区',
        '游戏专区',
        '主题专区',
        '开源阅读',
        '语音净化',
      ]);
      expect(data.rankings, hasLength(15));
      expect(data.pinned, hasLength(8));
      final restored = PortalData.fromJson(data.toJson());
      expect(restored.pinned.first.title, data.pinned.first.title);
      expect(restored.banners.first.image, startsWith('https://ycoo.net/'));
      expect(
        restored.banners.any((e) => e.avatar.endsWith('noavatar.svg')),
        isTrue,
      );
    },
  );

  test(
    'mobile feed preserves pinned rows, actual avatars, images and cache data',
    () {
      final batch = Site.parseMobileTopics(
        File('test/fixtures/mobile-feed.xml').readAsStringSync(),
      );
      expect(batch.topics.first.id, '149059');
      expect(batch.topics.first.pinned, isTrue);
      expect(batch.topics.first.title, '关于规范发帖、维护版面秩序的通知');
      expect(batch.topics.first.level, 'Lv.16');
      expect(batch.topics.first.levelColor, '#FF0000');
      final unknownColor = File('test/fixtures/mobile-feed.xml')
          .readAsStringSync()
          .replaceFirst(
            '<span class="top_lev bg_a f_f" style="background:#FF0000 !important">',
            '<span class="top_lev f_f">',
          );
      expect(
        Site.parseMobileTopics(unknownColor).topics.first.levelColor,
        isEmpty,
      );
      expect(batch.topics.first.gender, 'male');
      expect(batch.topics.first.verificationLabel, '官方人员');
      expect(
        batch.topics.firstWhere((topic) => topic.level == 'Lv.4').levelColor,
        '#FF9900',
      );
      expect(
        batch.topics.first.verificationIcon,
        contains('common_3_verify_icon.png'),
      );
      expect(batch.hasMore, isTrue);
      expect(
        batch.topics.any((e) => e.avatar.endsWith('noavatar.svg')),
        isTrue,
      );
      final illustrated = batch.topics.firstWhere((e) => e.images.length > 1);
      final restored = Topic.fromJson(illustrated.toJson());
      expect(restored.images, illustrated.images);
      expect(restored.preview, illustrated.preview);
      final restoredFirst = Topic.fromJson(batch.topics.first.toJson());
      expect(restoredFirst.pinned, isTrue);
      expect(restoredFirst.levelColor, '#FF0000');
      expect(restoredFirst.gender, 'male');
      expect(
        restoredFirst.verificationIcon,
        batch.topics.first.verificationIcon,
      );
      final externalIcon = File('test/fixtures/mobile-feed.xml')
          .readAsStringSync()
          .replaceFirst(
            'data/attachment/common/ec/common_3_verify_icon.png',
            'https://example.com/icon.png',
          );
      expect(
        Site.parseMobileTopics(externalIcon).topics.first.verificationIcon,
        isEmpty,
      );
      expect(batch.topics.map((e) => e.id).toSet().length, batch.topics.length);
    },
  );

  for (final stale in [false, true]) {
    testWidgets(
      'cached level colors refresh without replacing posts, stale=$stale',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'cache.v2.0.42.all': '{"items":[{"tid":"98450","subject":"缓存标题","author":"admin","authorid":"1","level":"Lv.16","message":"缓存摘要"}],"page":1,"more":false}',
        });
        final prefs = await SharedPreferences.getInstance();
        final site = ForumTopicSite(prefs);
        await tester.pumpWidget(
          MaterialApp(
            home: TopicsPage(site, fid: '42', title: '站务公告'),
          ),
        );
        await tester.pump();
        expect(find.text('缓存摘要'), findsOneWidget);
        final initialBadge = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Lv.16'),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          (initialBadge.decoration! as BoxDecoration).color,
          const Color(0xffff9900),
        );
        if (stale) site.sessionEpoch++;
        site.batch.complete(
          TopicBatch(const [
            Topic(
              id: '98450',
              title: '服务器新标题',
              author: 'admin',
              uid: '1',
              level: 'Lv.16',
              levelColor: '#FF0000',
            ),
          ], false),
        );
        await tester.pumpAndSettle();
        expect(find.text('缓存标题'), findsOneWidget);
        expect(find.text('缓存摘要'), findsOneWidget);
        expect(find.text('服务器新标题'), findsNothing);
        final badge = tester.widget<Container>(
          find
              .ancestor(
                of: find.text('Lv.16'),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          (badge.decoration! as BoxDecoration).color,
          stale ? isNot(const Color(0xffff0000)) : const Color(0xffff0000),
        );
        if (!stale)
          expect(prefs.getString('cache.v2.0.42.all'), contains('#FF0000'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('restored cached pages recover their own group colors', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'cache.v2.0.42.all': '{"items":[{"tid":"1","subject":"旧标题一","authorid":"1","level":"Lv.7"},{"tid":"2","subject":"旧标题二","authorid":"2","level":"Lv.7"}],"page":2,"more":false}',
    });
    final prefs = await SharedPreferences.getInstance();
    final site = PagedLevelSite(prefs);
    await tester.pumpWidget(
      MaterialApp(
        home: TopicsPage(site, fid: '42', title: '版块'),
      ),
    );
    await tester.pumpAndSettle();
    expect(site.calls, [1, 2]);
    final cache = prefs.getString('cache.v2.0.42.all')!;
    expect(cache, contains('#333333'));
    expect(cache, contains('#4B3E2A'));
    expect(find.text('旧标题一'), findsOneWidget);
    expect(find.text('新标题'), findsNothing);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('topic card keeps metadata and fits at text scale $scale', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final site = ForumTopicSite(await SharedPreferences.getInstance());
      await tester.binding.setSurfaceSize(const Size(360, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: scale == 1 ? Brightness.dark : Brightness.light,
            useMaterial3: true,
          ),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 1000),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: TopicTile(
                  site,
                  const Topic(
                    id: '1',
                    title: '帖子标题',
                    author: 'admin',
                    uid: '1',
                    level: 'Lv.16',
                    levelColor: '#FF0000',
                    gender: 'male',
                    pinned: true,
                    preview: '正文摘要',
                    forum: '站务公告',
                    likes: '23',
                    replies: '44',
                    views: '6479',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('置顶'), findsOneWidget);
      expect(find.text('Lv.16'), findsOneWidget);
      expect(find.text('# 站务公告'), findsOneWidget);
      expect(find.byIcon(Icons.male), findsOneWidget);
      if (scale == 1) {
        final preview = tester.getRect(find.text('正文摘要'));
        final tag = tester.getRect(find.text('# 站务公告'));
        expect(tag.top - preview.bottom, lessThan(24));
        expect(
          tester.getSize(find.byType(TextButton).last).height,
          greaterThanOrEqualTo(48),
        );
        final follow = find.widgetWithText(OutlinedButton, '关注');
        expect(follow, findsOneWidget);
        expect(tester.getSize(follow).height, greaterThanOrEqualTo(48));
        final surface = find
            .descendant(of: follow, matching: find.byType(Material))
            .first;
        expect(tester.getSize(surface).height, lessThanOrEqualTo(36));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
