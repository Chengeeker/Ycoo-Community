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
            final strip = tester.getRect(
              find.byKey(const ValueKey('gallery-thumbnail-strip')),
            );
            expect(strip.bottom, size.height - 20 - 32);
            expect(strip.top, greaterThan(size.height / 2));
            expect(
              tester
                  .getCenter(find.byKey(const ValueKey('gallery-thumbnail-0')))
                  .dx,
              closeTo(size.width / 2, 1),
            );
            await tester.drag(viewport, Offset(-size.width * .8, 0));
            await tester.pump(const Duration(milliseconds: 500));
            expect(find.text('2 / 2'), findsOneWidget);
            expect(
              tester
                  .getCenter(find.byKey(const ValueKey('gallery-thumbnail-1')))
                  .dx,
              closeTo(size.width / 2, 1),
            );
            expect(tester.getRect(viewport), Offset.zero & size);
          }
          await tester.tapAt(Offset(size.width / 2, size.height / 2 + 70));
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pump(const Duration(milliseconds: 150));
          expect(
            tester
                .widget<IgnorePointer>(
                  find.byKey(const ValueKey('gallery-top-controls')),
                )
                .ignoring,
            isTrue,
          );
          expect(tester.getRect(viewport), Offset.zero & size);
          await tester.tapAt(Offset(size.width / 2, size.height / 2 + 70));
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pump(const Duration(milliseconds: 150));
          expect(
            tester
                .widget<IgnorePointer>(
                  find.byKey(const ValueKey('gallery-top-controls')),
                )
                .ignoring,
            isFalse,
          );
          if (count > 1) {
            expect(
              tester
                  .getCenter(find.byKey(const ValueKey('gallery-thumbnail-1')))
                  .dx,
              closeTo(size.width / 2, 1),
            );
          }
          expect(tester.getRect(viewport), Offset.zero & size);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'Review reel continuously drives the image and yields to a new main swipe',
    (tester) async {
      tester.view.physicalSize = const Size(393, 873);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: GalleryPage(
            List.generate(12, (i) => 'https://example.invalid/reel-$i.png'),
            5,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final main = find.byType(ExtendedImageGesturePageView);
      final mainController = tester
          .widget<ExtendedImageGesturePageView>(main)
          .controller;
      final reelController = tester
          .widget<PageView>(find.byType(PageView))
          .controller!;
      final strip = find.byKey(const ValueKey('gallery-thumbnail-strip'));
      expect(
        tester.getCenter(find.byKey(const ValueKey('gallery-thumbnail-5'))).dx,
        closeTo(393 / 2, 1),
      );
      final drag = await tester.startGesture(tester.getCenter(strip));
      await drag.moveBy(const Offset(-25, 0));
      await tester.pump();
      await drag.moveBy(const Offset(-45, 0));
      await tester.pump();
      expect(reelController.page, greaterThan(5));
      expect(mainController.page, closeTo(reelController.page!, .02));
      await drag.up();
      for (var frame = 0; frame < 50; frame++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(mainController.position.isScrollingNotifier.value, isFalse);
      expect(reelController.position.isScrollingNotifier.value, isFalse);
      expect(
        mainController.page,
        closeTo(mainController.page!.roundToDouble(), .001),
      );
      expect(reelController.page, closeTo(mainController.page!, .001));
      await tester.drag(main, const Offset(300, 0));
      for (var frame = 0; frame < 50; frame++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(reelController.page, closeTo(mainController.page!, .001));
      final selected = mainController.page!.round();
      expect(
        tester
            .getCenter(find.byKey(ValueKey('gallery-thumbnail-$selected')))
            .dx,
        closeTo(393 / 2, 1),
      );
      await tester.tapAt(const Offset(196, 400));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(196, 400));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey('gallery-top-controls')),
            )
            .ignoring,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
