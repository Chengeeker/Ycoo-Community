import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuan_community/pages/media.dart';

void main() {
  for (final size in [const Size(393, 873), const Size(873, 393)]) {
    for (final count in [1, 2]) {
      testWidgets(
        'gallery fills $size with $count images, independent of chrome',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(top: 24, bottom: 20),
                  viewPadding: const EdgeInsets.only(top: 24, bottom: 20),
                ),
                child: child!,
              ),
              home: GalleryPage(
                List.generate(
                  count,
                  (i) => 'https://example.invalid/gallery-$count-$i.png',
                ),
                0,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          final viewport = find.byType(ExtendedImageGesturePageView);
          expect(tester.getRect(viewport), Offset.zero & size);
          expect(tester.getCenter(viewport).dy, size.height / 2);
          final back = tester.getRect(find.byTooltip('返回'));
          expect(back.top, greaterThanOrEqualTo(24));
          expect(back.bottom, lessThan(size.height / 2));
          if (count > 1) {
            final strip = tester.getRect(find.byType(ListView));
            expect(strip.bottom, size.height - 20 - 16);
            expect(strip.top, greaterThan(size.height / 2));
            final thumbs = find.descendant(
              of: find.byType(ListView),
              matching: find.byType(InkWell),
            );
            final first = tester.getRect(thumbs.at(0));
            final last = tester.getRect(thumbs.at(count - 1));
            expect(
              (first.center.dx + last.center.dx) / 2,
              closeTo(size.width / 2, 1),
            );
            await tester.drag(viewport, Offset(-size.width * .8, 0));
            await tester.pump(const Duration(milliseconds: 500));
            expect(find.text('2 / 2'), findsOneWidget);
            expect(tester.getRect(viewport), Offset.zero & size);
          }
          await tester.tapAt(Offset(size.width / 2, size.height / 2 + 70));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byTooltip('返回'), findsNothing);
          expect(tester.getRect(viewport), Offset.zero & size);
          await tester.tapAt(Offset(size.width / 2, size.height / 2 + 70));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.byTooltip('返回'), findsOneWidget);
          expect(tester.getRect(viewport), Offset.zero & size);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
