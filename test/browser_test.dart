import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:yuan_community/pages/common.dart';

import 'helpers/fake_webview.dart';

void main() {
  late FakeWebViewPlatform platform;
  setUp(() {
    final previous = WebViewPlatform.instance;
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    if (previous != null) {
      addTearDown(() => WebViewPlatform.instance = previous);
    }
  });

  testWidgets('Android browser keeps one native view through loading updates', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BrowserPage('/plugin.php?id=boan_group&frame=yes'),
      ),
    );
    await tester.pumpAndSettle();
    expect(platform.controller.loads, [
      Uri.parse('https://ycoo.net/plugin.php?id=boan_group&frame=yes'),
    ]);
    expect(
      (platform.widgetParams as AndroidWebViewWidgetCreationParams)
          .displayWithHybridComposition,
      isTrue,
    );
    expect(find.byType(BackdropFilter), findsNothing);
    final view = tester.widget<WebViewWidget>(find.byType(WebViewWidget));
    platform.delegate.progress(50);
    await tester.pump();
    platform.delegate.progress(100);
    platform.delegate.finished(
      'https://ycoo.net/plugin.php?id=boan_group&frame=yes',
    );
    await tester.pumpAndSettle();
    expect(find.text('官网页面'), findsOneWidget);
    expect(identical(tester.widget(find.byType(WebViewWidget)), view), isTrue);
    expect(platform.widgetsCreated, 1);
    expect(platform.controller.loads, hasLength(1));
    for (final url in ['javascript:alert(1)', 'https://user@ycoo.net/']) {
      expect(
        await platform.delegate.navigate(
          NavigationRequest(url: url, isMainFrame: true),
        ),
        NavigationDecision.prevent,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded browser has no duplicate toolbar and supports retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BrowserPage(
          '/home.php?mod=spacecp&ac=credit&op=buy',
          embedded: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    platform.delegate.error(
      const WebResourceError(
        errorCode: -2,
        description: '网络错误',
        isForMainFrame: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('网络错误'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(platform.controller.reloads, 1);
    expect(tester.takeException(), isNull);
  });
}
