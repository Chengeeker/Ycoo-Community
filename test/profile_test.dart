import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/data/profile.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/pages/home.dart';
import 'package:yuan_community/pages/common.dart' show SiteAvatar;
import 'package:yuan_community/core/theme/app_theme.dart';
import 'package:yuan_community/pages/profile.dart';

final variables = jsonDecode(
  File('test/fixtures/user-profile.json').readAsStringSync(),
) as Map<String, dynamic>;
final source = File('test/fixtures/user-profile.html').readAsStringSync();

class UserSite extends Site {
  UserSite(super.prefs);
  final sections = <String>[];
  final pending = <String, Completer<String>>{};
  Map<String, dynamic> values = variables;
  String htmlSource = source;
  @override
  Future<Map<String, dynamic>> api(
    String module, {
    Map<String, dynamic> query = const {},
    Map<String, dynamic>? data,
  }) async => values;
  @override
  Future<Response<dynamic>> request(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
    int redirects = 0,
  }) async {
    final section = '${query?['do'] ?? 'profile'}';
    sections.add(section);
    return Response(
      data: section == 'profile'
          ? htmlSource
          : await pending[section]?.future ??
                '<div class="comiis_bodybox">暂无内容</div>',
      requestOptions: RequestOptions(path: path),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'official public profile preserves screenshot fields and reply count',
    () {
      final user = UserProfile(
        '34747',
        variables['space'],
        variables['extcredits'],
        source,
      );
      expect(user.name, '2488916893');
      expect(user.count('threads'), '530');
      expect(user.count('replies'), '325');
      expect(user.count('follower'), '177');
      expect(user.count('extcredits2'), '9729');
      expect(user.group, '大会员');
      expect(user.level, 'Lv.7');
      expect(user.cover, contains('home_bg.jpg'));
      expect(user.medals, hasLength(7));
      expect(user.signature, contains('这家伙很懒'));
      expect(UserProfile.action(source, '34747', 'follow'), isNull);
    },
  );

  test('administrator header ignores gender glyph and resolves avatar and identity', () {
    final admin = jsonDecode(
      File('test/fixtures/user-profile-admin.json').readAsStringSync(),
    ) as Map;
    final adminSource = File('test/fixtures/user-profile-admin.html')
        .readAsStringSync();
    final user = UserProfile(
      '1',
      {...admin['space'] as Map, 'username': '旧昵称'},
      admin['extcredits'],
      adminSource,
    );
    expect(user.name, 'admin');
    expect(user.level, 'Lv.16');
    expect(user.group, '管理员');
    expect(user.levelColor, '#FF0000');
    expect(
      user.avatar,
      'https://ycoo.net/data/avatar/000/00/00/01_avatar_middle.jpg',
    );
    final wrongPage = UserProfile(
      '34747',
      variables['space'],
      variables['extcredits'],
      adminSource,
    );
    expect(wrongPage.name, '2488916893');
    expect(wrongPage.avatar, contains('/47_avatar_middle.jpg'));
    expect(wrongPage.level, isEmpty);
  });

  for (final uid in ['16966', '25430', '5427']) {
    testWidgets(
      'ordinary user $uid renders empty-string medals without a gray screen',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final fixture = jsonDecode(
          File('test/fixtures/user-profile-$uid.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        expect((fixture['space'] as Map)['medals'], '');
        final site = UserSite(await SharedPreferences.getInstance())
          ..values = fixture
          ..htmlSource = File('test/fixtures/user-profile-$uid.html')
              .readAsStringSync();
        await tester.pumpWidget(MaterialApp(home: ProfilePage(site, uid)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(
          find.text(textOf(fixture['space'] as Map, 'username')),
          findsOneWidget,
        );
      },
    );
  }

  test(
    'optional profile metadata accepts empty values and keyed medal records',
    () async {
      for (final value in [null, '', <String, dynamic>{}, <dynamic>[], 0]) {
        final user = UserProfile(
          '1',
          {
            'uid': '1',
            'username': '用户',
            'group': value,
            'medals': value,
            'posts': '-1',
            'threads': '0',
          },
          {},
          '',
        );
        expect(user.medals, isEmpty);
        expect(user.group, isEmpty);
        expect(user.levelColor, isEmpty);
        expect(user.count('replies'), '—');
      }
      final keyed = UserProfile(
        '1',
        {
          'medals': {
            '45': {'name': '勋章', 'image': 'medal.gif'},
          },
        },
        {},
        '',
      );
      expect(keyed.medals.single['name'], '勋章');
      SharedPreferences.setMockInitialValues({});
      final site = UserSite(await SharedPreferences.getInstance())
        ..values = {...variables, 'extcredits': ''};
      expect((await site.userProfile('34747')).credits, isEmpty);
    },
  );

  test('user profile routing excludes content and relationship operations', () {
    expect(
      nativeUserProfileId(Uri.parse('https://ycoo.net/space-uid-34747.html')),
      '34747',
    );
    expect(
      nativeUserProfileId(
        Uri.parse('https://ycoo.net/home.php?mod=space&uid=34747&do=profile'),
      ),
      '34747',
    );
    for (final url in [
      'https://ycoo.net/home.php?mod=space&uid=34747&do=blog',
      'https://ycoo.net/home.php?mod=spacecp&ac=friend&uid=34747',
      'https://evil.test/space-uid-34747.html',
    ]) {
      expect(nativeUserProfileId(Uri.parse(url)), isNull);
    }
  });
  test(
    'profile thread fallback keeps thread identity and available author',
    () {
      final user = UserProfile(
        '34747',
        variables['space'],
        variables['extcredits'],
        source,
      );
      final topics = profileTopics(
        '<div id="ct"><table><tr><td><a href="thread-123-1-1.html">用户主题</a><div class="list_body">实际简介</div></td></tr></table></div>',
        user,
      );
      expect(topics.single.id, '123');
      expect(topics.single.author, user.name);
      expect(topics.single.preview, '实际简介');
    },
  );
  test('profile actions accept only exact same-site and target-user links', () {
    for (final target in [
      'home.php?mod=spacecp&ac=follow&op=add&fuid=34747',
      'https://ycoo.net/home.php?mod=spacecp&ac=follow&op=del&fuid=34747',
    ]) {
      expect(
        UserProfile.action(
          '<a id="followmod" href="$target">关注</a>',
          '34747',
          'follow',
        ),
        isNotNull,
      );
    }
    for (final target in [
      'https://evil.test/home.php?mod=spacecp&ac=follow&fuid=34747',
      'home.php?mod=spacecp&ac=follow&fuid=1',
      'home.php?mod=spacecp&ac=follow&fuid=34747&uid=1',
      'javascript:alert(1)',
    ]) {
      expect(
        UserProfile.action(
          '<a id="followmod" href="$target">关注</a>',
          '34747',
          'follow',
        ),
        isNull,
      );
    }
    expect(
      UserProfile.action(
        '''<div class="comiis_space_foot"><a href="javascript:;" onclick="showWindow('friend','home.php?mod=spacecp&ac=friend&op=add&uid=34747')">加好友</a></div>''',
        '34747',
        'friend',
      ),
      isNotNull,
    );
  });

  test('album cover and separate caption merge into one item', () {
    final entries = ProfileContentEntry.parse(
      '<div id="ct"><a href="home.php?mod=space&albumid=7"><img src="cover.jpg"></a><a href="home.php?mod=space&albumid=7">旅行相册</a></div>',
      'album',
    );
    expect(entries, hasLength(1));
    expect(entries.single.title, '旅行相册');
    expect(entries.single.image, 'cover.jpg');
  });

  test('profile response must match requested identity', () async {
    SharedPreferences.setMockInitialValues({});
    final site = UserSite(await SharedPreferences.getInstance());
    await expectLater(site.userProfile('0'), throwsA(isA<SiteException>()));
    await expectLater(site.userProfile('1'), throwsA(isA<SiteException>()));
    expect((await site.userProfile('34747')).name, '2488916893');
  });

  test(
    'blog and album items keep actual links and discard cross-site items',
    () {
      final entries = ProfileContentEntry.parse(
        '''<div class="comiis_bodybox"><a href="home.php?mod=space&do=blog&id=1&blogid=5">日志标题</a><a href="home.php?mod=space&do=blog&blogid=5">重复</a><a href="https://evil.test/home.php?blogid=8">外站</a></div>''',
        'blog',
      );
      expect(entries, hasLength(1));
      expect(entries.single.title, '日志标题');
      expect(entries.single.url, contains('blogid=5'));
    },
  );

  testWidgets('author name opens the same full native profile as avatar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final site = UserSite(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopicTile(
            site,
            const Topic(id: '1', title: '示例帖子', author: '点击用户名', uid: '34747'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('点击用户名'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('2488916893'), findsOneWidget);
    expect(find.text('个人主页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'profile tabs stay below app bar and QR works at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(393, 873);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final site = UserSite(await SharedPreferences.getInstance());
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: ProfilePage(site, '34747'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.scrollUntilVisible(
          find.text('二维码'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('二维码'));
        await tester.pumpAndSettle();
        expect(find.byType(QrImageView), findsOneWidget);
        Navigator.of(tester.element(find.byType(QrImageView))).pop();
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byType(TabBar)).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
        );
        await tester.tap(
          find.descendant(of: find.byType(TabBar), matching: find.text('帖子')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(site.sections, contains('thread'));
        expect(find.text('暂无可见内容'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 360.0, 393.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('profile rows stay compact at width $width scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 873);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final admin = jsonDecode(
          File('test/fixtures/user-profile-admin.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        final site = UserSite(await SharedPreferences.getInstance())
          ..values = admin
          ..htmlSource = File('test/fixtures/user-profile-admin.html')
              .readAsStringSync();
        await tester.pumpWidget(
          MaterialApp(
            theme: width == 360
                ? AppTheme.darkTheme(fontWeightAdjustment: 100)
                : AppTheme.lightTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: ProfilePage(site, '1'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('admin'), findsOneWidget);
        expect(find.text('Lv.16'), findsOneWidget);
        final avatar = tester.widget<SiteAvatar>(
          find.byKey(const ValueKey('profile-avatar')),
        );
        expect(avatar.url, startsWith('https://ycoo.net/data/avatar/'));
        expect(avatar.radius, 32);
        final stats = ['views', 'following', 'followers']
            .map(
              (name) =>
                  tester.getRect(find.byKey(ValueKey('profile-header-$name'))),
            )
            .toList();
        expect(stats[0].center.dy, closeTo(stats[1].center.dy, .1));
        expect(stats[1].center.dy, closeTo(stats[2].center.dy, .1));
        final actions = ['friend', 'poke', 'pm', 'block']
            .map(
              (name) =>
                  tester.getRect(find.byKey(ValueKey('profile-action-$name'))),
            )
            .toList();
        for (final rect in actions) {
          expect(rect.top, closeTo(actions.first.top, .1));
          expect(rect.height, greaterThanOrEqualTo(48));
        }
        expect(actions.last.right, lessThanOrEqualTo(width));
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('profile-metrics')),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('profile-metrics')),
        );
        await tester.pump();
        final cells = List.generate(
          8,
          (index) =>
              tester.getRect(find.byKey(ValueKey('profile-metric-$index'))),
        );
        for (var i = 0; i < 4; i++) {
          expect(cells[i].top, closeTo(cells[0].top, .1));
          expect(cells[i + 4].top, closeTo(cells[4].top, .1));
          if (i > 0) expect(cells[i].left, greaterThan(cells[i - 1].left));
        }
        expect(cells[4].top, greaterThan(cells[0].top));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('switching tabs while requests run loads both destinations', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final site = UserSite(await SharedPreferences.getInstance());
    site.pending['thread'] = Completer<String>();
    site.pending['blog'] = Completer<String>();
    await tester.pumpWidget(MaterialApp(home: ProfilePage(site, '34747')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(
      find.descendant(of: find.byType(TabBar), matching: find.text('帖子')),
    );
    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text('帖子')),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text('日志')),
    );
    await tester.pump();
    expect(site.sections, containsAll(['thread', 'blog']));
    site.pending['thread']!.complete('<div class="comiis_bodybox">暂无帖子</div>');
    site.pending['blog']!.complete('<div class="comiis_bodybox">暂无日志</div>');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('暂无可见内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
