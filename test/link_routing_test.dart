import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/core/widgets/app_scope.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/settings.dart';
import 'package:yuan_community/pages/common.dart';
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

void main() {
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
