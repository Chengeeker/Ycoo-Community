import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:yuan_community/pages/thread.dart';
import 'package:yuan_community/pages/media.dart';
import 'package:yuan_community/pages/common.dart';
import 'package:yuan_community/core/widgets/review_gallery_glass_button.dart';

import 'dart:typed_data';

import 'package:yuan_community/data/site.dart';

void main() {
  testWidgets(
    'HTML source newlines do not duplicate BR spacing; pre keeps its lines',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HtmlContent(
              '甲<br />\n<br />\n<br />\n乙<pre>代码\n  缩进</pre>',
              onLink: (_) {},
            ),
          ),
        ),
      );
      final texts = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((e) => e.textSpan!.toPlainText())
          .toList();
      expect(texts.first.replaceAll(' ', ''), '甲\n\n\n乙');
      expect(texts.last, '代码\n  缩进');
    },
  );
  testWidgets('separate image attachments open the native gallery', (
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
    final source = forumPostHtml({
      'message': '正文',
      'attachments': {
        '1': {
          'isimage': '1',
          'url': 'data/attachment/forum/',
          'attachment': 'test.png',
        },
      },
    });
    expect(html.parseFragment(source).querySelectorAll('img'), hasLength(1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HtmlContent(
            source,
            onLink: (_) => fail('Image must open gallery'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GalleryPage), findsOneWidget);
    expect(find.byType(BrowserPage), findsNothing);
    expect(find.byType(ReviewGalleryGlassIconButton), findsNWidgets(2));
    expect(find.byTooltip('保存图片到相册'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  test('image attachment already in body is not duplicated', () {
    final source = forumPostHtml({
      'message':
          '<a href="/thread-1-1-1.html">链接</a><img aid="1" src="thumb.png">',
      'attachments': {
        '1': {
          'isimage': '1',
          'url': 'data/attachment/forum/',
          'attachment': 'test.png',
        },
      },
    });
    final doc = html.parseFragment(source);
    expect(doc.querySelectorAll('img'), hasLength(1));
    expect(doc.querySelector('a')!.text, '链接');
    expect(doc.querySelector('img')!.attributes['file'], endsWith('/test.png'));
  });
  test('gallery save rejects HTML and preserves image file formats', () {
    expect(
      galleryImageFormat(Uint8List.fromList('<html>login</html>'.codeUnits)),
      isNull,
    );
    expect(
      galleryImageFormat(
        Uint8List.fromList([137, 80, 78, 71, 0, 0, 0, 0, 0, 0, 0, 0]),
      )!.$2,
      'image/png',
    );
    expect(
      galleryImageFormat(
        Uint8List.fromList([255, 216, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
      )!.$1,
      'jpg',
    );
  });
}
