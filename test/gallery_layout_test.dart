import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/core/widgets/app_scope.dart';
import 'package:yuan_community/core/widgets/review_gallery_glass_button.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/pages/media.dart';
import 'package:yuan_community/settings.dart';

void main() {
  testWidgets('gallery glass controls fade in and are removed on return', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'liquidGlass': true});
    final prefs = await SharedPreferences.getInstance();
    final settings = Settings(prefs);
    addTearDown(settings.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) =>
            AppScope(site: Site(prefs), settings: settings, child: child!),
        home: const Scaffold(body: Text('host')),
      ),
    );

    navigator.currentState!.push(
      PageRouteBuilder<void>(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => const GalleryPage(
          [
            'https://example.invalid/gallery.png',
            'https://example.invalid/second.png',
          ],
          0,
          cookie: 'test',
        ),
      ),
    );
    await tester.pump();
    final glassButtons = find.byType(
      ReviewGalleryGlassIconButton,
      skipOffstage: false,
    );
    expect(glassButtons, findsNWidgets(2));
    expect(
      tester
          .widgetList<ReviewGalleryGlassIconButton>(glassButtons)
          .every((button) => button.opacity == 0),
      isTrue,
    );
    expect(
      find.byKey(
        const ValueKey('gallery-thumbnail-strip'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(
              const ValueKey('gallery-top-controls'),
              skipOffstage: false,
            ),
          )
          .ignoring,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(glassButtons, findsNWidgets(2));
    expect(
      tester
          .widgetList<ReviewGalleryGlassIconButton>(glassButtons)
          .every((button) => button.useLiquidGlass),
      isTrue,
    );
    expect(
      tester
          .widget<IgnorePointer>(
            find.byKey(
              const ValueKey('gallery-top-controls'),
              skipOffstage: false,
            ),
          )
          .ignoring,
      isFalse,
    );

    navigator.currentState!.pop();
    await tester.pump();
    expect(glassButtons, findsNothing);
    expect(
      find.byKey(
        const ValueKey('gallery-thumbnail-strip'),
        skipOffstage: false,
      ),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GalleryPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('Review hero target keeps the full viewport while loading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scope = Object();
    const url = 'https://example.invalid/hero.png';
    await tester.pumpWidget(
      MaterialApp(
        home: GalleryPage(const [url], 0, cookie: 'test', heroScope: scope),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final hero = find.byWidgetPredicate(
      (widget) =>
          widget is Hero && widget.tag == forumGalleryHeroTag(scope, 0, url),
    );
    expect(tester.getRect(hero), const Rect.fromLTWH(0, 0, 393, 873));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cover thumbnail return uses Review image-plane morph', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 32, 32),
      ui.Paint()..color = const ui.Color(0xff4488cc),
    );
    final image = await recorder.endRecording().toImage(32, 32);
    addTearDown(image.dispose);
    final scope = Object();
    final tag = forumGalleryHeroTag(
      scope,
      0,
      'https://example.invalid/cover.png',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Hero(
                  key: const ValueKey('gallery-source-hero'),
                  tag: tag,
                  flightShuttleBuilder: forumGalleryFlight,
                  child: SizedBox(
                    width: 220,
                    height: 320,
                    child: RawImage(image: image, fit: BoxFit.contain),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Hero(
                  key: const ValueKey('gallery-target-hero'),
                  tag: tag,
                  flightShuttleBuilder: forumGalleryFlight,
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: RawImage(image: image, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final from = tester.element(
      find.byKey(const ValueKey('gallery-source-hero')),
    );
    final to = tester.element(
      find.byKey(const ValueKey('gallery-target-hero')),
    );
    final flightAnimation = ProxyAnimation(
      const AlwaysStoppedAnimation<double>(1),
    );
    final shuttle = forumGalleryFlight(
      from,
      flightAnimation,
      HeroFlightDirection.pop,
      from,
      to,
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: shuttle)));
    expect(
      find.byKey(const ValueKey('gallery-return-image-plane')),
      findsOneWidget,
    );
    final painter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey('gallery-return-image-plane')),
        )
        .painter!;
    Future<Uint8List> paintAtFlightSize(Size size) async {
      final recorder = ui.PictureRecorder();
      painter.paint(ui.Canvas(recorder), size);
      final picture = recorder.endRecording();
      final pixels = await tester.runAsync(() async {
        final frame = await picture.toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        try {
          final bytes = await frame.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          return bytes!.buffer.asUint8List();
        } finally {
          frame.dispose();
        }
      });
      picture.dispose();
      return pixels!;
    }

    final returningFrame = await paintAtFlightSize(const Size(170, 220));
    expect(returningFrame[(40 * 170 + 85) * 4 + 2], 0xcc);
    flightAnimation.parent = const AlwaysStoppedAnimation<double>(0);
    final reopenedFrame = await paintAtFlightSize(const Size(170, 220));
    expect(reopenedFrame, orderedEquals(returningFrame));
    final redirectedFrame = await paintAtFlightSize(const Size(180, 240));
    expect(redirectedFrame[(40 * 180 + 90) * 4 + 2], 0xcc);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

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
