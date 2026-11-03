import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/core/widgets/app_scope.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/settings.dart';
import 'package:yuan_community/pages/common.dart';
import 'package:yuan_community/pages/home.dart';
import 'package:yuan_community/pages/login.dart';
import 'package:yuan_community/pages/native_site.dart';
import 'package:yuan_community/pages/thread.dart';

class RoutingSite extends Site {
  RoutingSite(super.prefs);
  @override
  Future<Map<String, dynamic>> api(
    String module, {
    Map<String, dynamic> query = const {},
    Map<String, dynamic>? data,
  }) async => {
    'thread': {'replies': '0'},
    'postlist': [],
    'ppp': '10',
  };
}

// Capture the destination without starting an Android WebView in widget tests.
class _CapturingNavigator extends Navigator {
  _CapturingNavigator({required Widget home, required this.onPush})
    : super(
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => home),
      );

  final ValueChanged<Widget> onPush;

  @override
  NavigatorState createState() => _CapturingNavigatorState();
}

class _CapturingNavigatorState extends NavigatorState {
  @override
  Future<T?> push<T extends Object?>(Route<T> route) async {
    (widget as _CapturingNavigator).onPush(
      (route as MaterialPageRoute<T>).builder(context),
    );
    return null;
  }
}

void main() {
  testWidgets('membership links use the browser, other plugins stay native', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final site = RoutingSite(prefs);
    Widget? destination;
    late BuildContext linkContext;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            AppScope(site: site, settings: Settings(prefs), child: child!),
        home: _CapturingNavigator(
          onPush: (page) => destination = page,
          home: Builder(
            builder: (context) {
              linkContext = context;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    for (final link in [
      '/plugin.php?id=boan_group&frame=yes',
      '/plugin.php?id=boan_group&frame=yes&mobile=2',
      'https://ycoo.net/plugin.php?frame=yes&id=boan_group',
      '/plugin.php?id=comiis_app_homestyle&mobile=2',
      '/plugin.php?id=jnfarm&mobile=2',
      '/plugin.php?id=bphp_clouds:index&mobile=2',
      '/group.php?mod=my&mobile=2',
      '/forum.php?mod=collection&op=all&mobile=2',
      '/home.php?mod=magic&mobile=2',
      for (final kind in ['friend', 'blog', 'album', 'doing', 'follow', 'pm'])
        '/home.php?mod=space&do=$kind&mobile=2',
      for (final action in ['avatar', 'profile', 'invite', 'pm'])
        '/home.php?mod=spacecp&ac=$action&mobile=2',
      for (final operation in ['transfer', 'buy'])
        '/home.php?mod=spacecp&ac=credit&op=$operation&mobile=2',
    ]) {
      await openWeb(linkContext, link, title: '繁星开通');
      expect(destination, isA<BrowserPage>(), reason: link);
      expect(
        (destination as BrowserPage).url,
        normalizeSiteLink(link).toString(),
      );
      expect((destination as BrowserPage).title, '繁星开通');
    }
    for (final link in [
      '/plugin.php?id=boan_group_other&frame=yes',
      '/plugin.php?id=other_plugin&frame=yes',
      '/home.php?id=boan_group&frame=yes',
      '/home.php?mod=space&do=notice&view=system',
      '/home.php?mod=spacecp&ac=credit&op=log',
      '/home.php?mod=spacecp&ac=friend&op=add&uid=7',
      '/home.php?mod=space&do=friend&view=visitor&mobile=2',
      '/home.php?mod=task&mobile=2',
      '/home.php?mod=medal&mobile=2',
      '/home.php?mod=medal&action=log&mobile=2',
    ]) {
      await openWeb(linkContext, link);
      expect(destination, isA<NativeSitePage>(), reason: link);
    }
    expect(tester.takeException(), isNull);
  });

  test('official-page routing requires an exact same-site URL', () {
    for (final value in [
      'https://example.com/home.php?mod=magic',
      'https://ycoo.net.evil.invalid/plugin.php?id=boan_group',
      'https://user@ycoo.net/group.php',
      'https://ycoo.net:444/home.php?mod=task',
      'https://ycoo.net/other.php?mod=magic',
    ]) {
      expect(requiresSiteWebView(Uri.parse(value)), isFalse, reason: value);
    }
  });

  testWidgets('dashboard membership opens the supplied URL after login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final site = RoutingSite(prefs);
    Widget? destination;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            AppScope(site: site, settings: Settings(prefs), child: child!),
        home: _CapturingNavigator(
          onPush: (page) => destination = page,
          home: MyDashboardPage(site, Settings(prefs)),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('繁星开通'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('繁星开通'));
    await tester.pump();
    expect(destination, isA<LoginPage>());
    site.uid = '23706';
    await tester.tap(find.text('繁星开通'));
    await tester.pump();
    expect(destination, isA<BrowserPage>());
    expect(
      (destination as BrowserPage).url,
      'https://ycoo.net/plugin.php?id=boan_group&frame=yes',
    );
    expect(find.text('更改头像'), findsNothing);
    expect(find.text('空间背景'), findsNothing);
    for (final label in ['最近访客', '任务中心', '我的勋章']) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pump();
      expect(destination, isA<NativeSitePage>(), reason: label);
      if (label == '我的勋章') {
        expect(
          Uri.parse((destination as NativeSitePage).url)
              .queryParameters['action'],
          'log',
        );
      }
    }
    expect(tester.takeException(), isNull);
  });

  test(
    'only exact same-site post links route natively, including query links',
    () {
      expect(nativeThreadId(normalizeSiteLink('/thread-123-1-1.html')), '123');
      expect(
        nativeThreadId(
          normalizeSiteLink('http://ycoo.net/forum.php?mod=viewthread&tid=456'),
        ),
        '456',
      );
      for (final value in [
        'https://example.com/thread-123-1-1.html',
        'https://ycoo.net.evil.invalid/thread-123-1-1.html',
        'https://user@ycoo.net/thread-123-1-1.html',
        'https://ycoo.net/forum.php?mod=viewthread&tid=not-a-number',
      ]) {
        expect(nativeThreadId(normalizeSiteLink(value)), isNull);
      }
      expect(
        isDirectForumImage(
          Uri.parse('https://example.com/photo.jpg?size=original'),
        ),
        isTrue,
      );
      expect(
        isDirectForumImage(Uri.parse('https://user@example.com/photo.jpg')),
        isFalse,
      );
    },
  );
  testWidgets('common link opener sends community posts to native details', (
    tester,
  ) async {
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
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final site = RoutingSite(prefs);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            AppScope(site: site, settings: Settings(prefs), child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openWeb(context, '/thread-123-1-1.html'),
              child: const Text('打开帖子'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开帖子'));
    await tester.pumpAndSettle();
    expect(find.byType(ThreadPage), findsOneWidget);
    expect(find.byType(BrowserPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
