import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:extended_image/extended_image.dart';
import 'package:yuan_community/pages/media.dart';
import 'package:yuan_community/data/site.dart';

const url = 'https://example.invalid/reentry.png';

class GalleryObserver extends NavigatorObserver {
  int openings = 0, hostPops = 0;
  final galleries = <PageRouteBuilder<void>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRouteBuilder<void>) {
      openings++;
      galleries.add(route);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) hostPops++;
  }
}

class GalleryHost {
  final navigator = GlobalKey<NavigatorState>();
  final boundary = GlobalKey();
  final observer = GalleryObserver();
  final scope = Object();
  late BuildContext source;
  late ui.Image image;
  Completer<ImageInfo>? pendingImage;
  int articleOpens = 0;

  Future<void> mount(
    WidgetTester tester, {
    bool delayGallery = false,
    bool corner = false,
  }) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xff22aadd), BlendMode.src);
    image = await recorder.endRecording().toImage(32, 32);
    addTearDown(image.dispose);
    for (final sourceUrl in [url, 'https://ycoo.net/reentry.png']) {
      final provider = ExtendedNetworkImageProvider(sourceUrl, cache: true);
      final cacheKey = await provider.obtainKey(ImageConfiguration.empty);
      if (delayGallery && sourceUrl == url) {
        pendingImage = Completer<ImageInfo>();
      }
      PaintingBinding.instance.imageCache.putIfAbsent(
        cacheKey,
        () => OneFrameImageStreamCompleter(
          delayGallery && sourceUrl == url
              ? pendingImage!.future
              : Future.value(ImageInfo(image: image.clone())),
        ),
      );
    }
    addTearDown(() {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) {
              source = context;
              return Scaffold(
                body: Align(
                  alignment: corner ? Alignment.topLeft : Alignment.center,
                  child: Padding(
                    padding: corner
                        ? const EdgeInsets.only(left: 16, top: 90)
                        : EdgeInsets.zero,
                    child: GestureDetector(
                      onTap: () => articleOpens++,
                      child: InkWell(
                        key: const ValueKey('article-image'),
                        onTap: () => open(),
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          child: Hero(
                            tag: forumGalleryHeroTag(scope, 0, url),
                            createRectTween: (a, b) =>
                                RectTween(begin: a, end: b),
                            flightShuttleBuilder: forumGalleryFlight,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 180,
                                height: 120,
                                child: RawImage(
                                  image: image,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open({bool readCookie = false}) => openGallery(
    source,
    [readCookie ? 'https://ycoo.net/reentry.png' : url],
    0,
    cookie: readCookie ? '' : 'fixture',
    heroScope: scope,
  );

  Future<void> verifyHost(WidgetTester tester) async {
    expect(observer.hostPops, 0);
    expect(find.byType(GalleryPage, skipOffstage: false), findsNothing);
    expect(navigator.currentState!.canPop(), isFalse);
    final point = tester.getCenter(find.byKey(const ValueKey('article-image')));
    final pixel = await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final snapshot = await render.toImage();
      final bytes = (await snapshot.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final offset = (point.dy.floor() * snapshot.width + point.dx.floor()) * 4;
      final result = bytes.buffer.asUint8List().sublist(offset, offset + 4);
      snapshot.dispose();
      return result;
    });
    expect(pixel, [
      0x22,
      0xaa,
      0xdd,
      0xff,
    ], reason: 'Article image must be visible after every return');
    expect(tester.takeException(), isNull);
  }

  Future<Rect> imageBounds(
    WidgetTester tester,
  ) async => (await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final snapshot = await render.toImage();
    try {
      final bytes = (await snapshot.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      var left = snapshot.width, top = snapshot.height, right = -1, bottom = -1;
      for (var y = 0; y < snapshot.height; y++) {
        for (var x = 0; x < snapshot.width; x++) {
          final i = (y * snapshot.width + x) * 4;
          if (bytes[i] < 70 && bytes[i + 1] > 120 && bytes[i + 2] > 170) {
            if (x < left) left = x;
            if (y < top) top = y;
            if (x > right) right = x;
            if (y > bottom) bottom = y;
          }
        }
      }
      expect(right, greaterThanOrEqualTo(left));
      return Rect.fromLTRB(
        left.toDouble(),
        top.toDouble(),
        (right + 1).toDouble(),
        (bottom + 1).toDouble(),
      );
    } finally {
      snapshot.dispose();
    }
  }))!;
}

void main() {
  testWidgets(
    'repeatedly interrupting reopened players leaves only the latest route',
    (tester) async {
      final host = GalleryHost();
      await host.mount(tester, corner: true);
      final point = tester.getCenter(
        find.byKey(const ValueKey('article-image')),
      );
      await tester.tapAt(point);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 8; i++) {
        host.navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
        await tester.tapAt(point);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(host.observer.openings, i + 2);
        expect(host.observer.hostPops, 0);
        expect(host.articleOpens, 0);
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(GalleryPage, skipOffstage: false), findsOneWidget);
      host.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await host.verifyHost(tester);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final openingMs in [100, 350]) {
    for (final returningMs in openingMs == 100 ? [10, 40] : [10, 120]) {
      for (final heldMs in [0, 120]) {
        testWidgets(
          'returning photo redirects to the player: open=$openingMs return=$returningMs hold=$heldMs',
          (tester) async {
            final host = GalleryHost();
            await host.mount(tester, corner: true);
            final point = tester.getCenter(
              find.byKey(const ValueKey('article-image')),
            );
            await tester.tapAt(point);
            await tester.pump();
            await tester.pump(Duration(milliseconds: openingMs));
            for (var round = 0; round < 3; round++) {
              host.navigator.currentState!.pop();
              await tester.pump();
              await tester.pump(Duration(milliseconds: returningMs));
              expect(
                host.observer.galleries.last.animation!.status,
                AnimationStatus.reverse,
              );
              final before = heldMs == 0
                  ? await host.imageBounds(tester)
                  : null;
              final pointer = await tester.startGesture(point);
              if (heldMs > 0) await tester.pump(Duration(milliseconds: heldMs));
              await pointer.up();
              await tester.pump();
              await tester.pump();
              expect(host.observer.openings, round + 2);
              expect(host.articleOpens, 0);
              if (before != null) {
                final after = await host.imageBounds(tester);
                expect(after.left, closeTo(before.left, 1));
                expect(after.top, closeTo(before.top, 1));
                expect(after.width, closeTo(before.width, 1));
                expect(after.height, closeTo(before.height, 1));
              }
              var previous = await host.imageBounds(tester);
              for (final ms in [30, 60, 120, 180]) {
                await tester.pump(Duration(milliseconds: ms));
                final frame = await host.imageBounds(tester);
                expect(frame.width, greaterThanOrEqualTo(previous.width - 1));
                expect(frame.height, greaterThanOrEqualTo(previous.height - 1));
                expect(
                  frame.center.dy,
                  greaterThanOrEqualTo(previous.center.dy - 1),
                );
                previous = frame;
              }
              expect(previous.center.dx, closeTo(196.5, 1));
              expect(previous.center.dy, closeTo(436.5, 1));
            }
            host.navigator.currentState!.pop();
            await tester.pump();
            final drag = await tester.startGesture(point);
            await drag.moveBy(const Offset(70, 0));
            await drag.up();
            await tester.pumpAndSettle();
            await host.verifyHost(tester);
            expect(host.observer.openings, 4);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
  testWidgets(
    'pending edge tap cannot pop the article during system-back animation',
    (tester) async {
      final host = GalleryHost();
      await host.mount(tester);
      final opening = host.open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tapAt(const Offset(20, 400));
      await tester.pump(const Duration(milliseconds: 150));
      host.navigator.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 160));
      expect(host.observer.hostPops, 0);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await opening;
      await host.verifyHost(tester);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a returning Hero accepts a source tap before its route completes',
    (tester) async {
      final host = GalleryHost();
      await host.mount(tester);
      var finished = false;
      final opening = host.open().whenComplete(() => finished = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      host.navigator.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 30));
      expect(finished, isFalse);
      await tester.tapAt(const Offset(196, 436));
      await tester.pump();
      await tester.pump();
      expect(host.observer.openings, 2);
      expect(host.articleOpens, 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(GalleryPage), findsOneWidget);
      host.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await opening;
      expect(finished, isTrue);
      await host.verifyHost(tester);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'twelve rapid open/back/reopen cycles retain the visible article',
    (tester) async {
      final host = GalleryHost();
      await host.mount(tester);
      for (var i = 0; i < 12; i++) {
        final opening = host.open();
        await tester.pump();
        await tester.pump(Duration(milliseconds: i.isEven ? 100 : 350));
        if (i.isOdd) {
          final back = tester.widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
          );
          back.onPressed!();
          back.onPressed!();
        } else {
          host.navigator.currentState!.pop();
        }
        await tester.pump(const Duration(milliseconds: 20));
        expect(host.observer.openings, i + 1);
        await tester.pump(const Duration(milliseconds: 400));
        await opening;
        await host.verifyHost(tester);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'duplicate taps while cookies are pending only open one gallery',
    (tester) async {
      final host = GalleryHost();
      await host.mount(tester);
      final cookie = Completer<String>();
      var reads = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        Site.cookies,
        (_) {
          reads++;
          return cookie.future;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          Site.cookies,
          null,
        ),
      );
      final first = host.open(readCookie: true);
      final second = host.open(readCookie: true);
      await tester.pump();
      expect(reads, 1);
      cookie.complete('fixture');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(host.observer.openings, 1);
      host.navigator.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await Future.wait([first, second]);
      await host.verifyHost(tester);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cookie failures release the gallery guard for the next attempt',
    (tester) async {
      final host = GalleryHost();
      await host.mount(tester);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        Site.cookies,
        (_) async => throw PlatformException(code: 'unavailable'),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          Site.cookies,
          null,
        ),
      );
      final failed = host.open(readCookie: true);
      final assertion = expectLater(failed, throwsA(isA<PlatformException>()));
      await tester.pump();
      await assertion;
      final opening = host.open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(host.observer.openings, 1);
      host.navigator.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await opening;
      await host.verifyHost(tester);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'leaving the source while cookies are pending cancels the stale opening',
    (tester) async {
      final host = GalleryHost();
      await host.mount(tester);
      final cookie = Completer<String>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        Site.cookies,
        (_) => cookie.future,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          Site.cookies,
          null,
        ),
      );
      final stale = host.open(readCookie: true);
      host.navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('other page')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      cookie.complete('fixture');
      await tester.pump();
      await stale;
      expect(host.observer.openings, 0);
      host.navigator.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 400));
      final opening = host.open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(host.observer.openings, 1);
      host.navigator.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await opening;
      await host.verifyHost(tester);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('disposing the navigator completes the pending gallery opening', (
    tester,
  ) async {
    final host = GalleryHost();
    await host.mount(tester);
    var finished = false;
    final opening = host.open().whenComplete(() => finished = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(finished, isTrue);
    await opening;
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'rapid return while the original is loading leaves no black overlay',
    (tester) async {
      final host = GalleryHost();
      await host.mount(tester, delayGallery: true);
      for (var i = 0; i < 8; i++) {
        final opening = host.open();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        host.navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        await opening;
        expect(host.observer.openings, i + 1);
        await host.verifyHost(tester);
      }
      host.pendingImage!.complete(ImageInfo(image: host.image.clone()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
