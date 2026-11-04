import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/pages/home.dart';
import 'package:yuan_community/pages/media.dart';
import 'package:yuan_community/pages/thread.dart';

const thumbnail =
    'https://ycoo.net/data/attachment/image/000/16/69/73_500_99999.jpg';
const original = 'https://ycoo.net/data/attachment/forum/test.png';
late final Uint8List pixels;

class ImageClient extends Fake implements HttpClient {
  int status = 404;
  final requests = <String>[];
  final requestHeaders = <String, Map<String, String>>{};
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests.add(url.toString());
    final headers = ImageHeaders();
    requestHeaders[url.toString()] = headers.values;
    return ImageRequest(
      headers,
      url.path.contains('/attachment/image/') ? status : 200,
    );
  }
}

class ImageHeaders extends Fake implements HttpHeaders {
  final values = <String, String>{};
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = '$value';
  }
}

class ImageRequest extends Fake implements HttpClientRequest {
  ImageRequest(this.headers, this.status);
  @override
  final HttpHeaders headers;
  final int status;
  @override
  Future<HttpClientResponse> close() async => ImageResponse(status);
}

class ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  ImageResponse(this.statusCode);
  @override
  final int statusCode;
  @override
  int get contentLength => pixels.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(pixels).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ThumbnailSite extends Site {
  ThumbnailSite(super.prefs);
  int reads = 0;
  Completer<void>? pending;
  Map<String, dynamic> result = {
    'thread': {'tid': '157330'},
    'postlist': [
      {
        'first': '1',
        'attachments': {
          '166973': {
            'isimage': '1',
            'url': 'data/attachment/forum/',
            'attachment': 'test.png',
          },
        },
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> api(
    String module, {
    Map<String, dynamic> query = const {},
    Map<String, dynamic>? data,
  }) async {
    expect(module, 'viewthread');
    expect(query['tid'], '157330');
    expect(data, isNull);
    reads++;
    await pending?.future;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xff22aadd), BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(32, 32);
    picture.dispose();
    pixels = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
    image.dispose();
  });
  late ThumbnailSite site;
  late ImageClient client;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    site = ThumbnailSite(await SharedPreferences.getInstance());
    client = ImageClient();
    debugNetworkImageHttpClientProvider = () => client;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Site.cookies, (_) async => 'auth=fixture');
  });
  tearDown(() {
    debugNetworkImageHttpClientProvider = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Site.cookies, null);
  });

  testWidgets(
    'expired cached thumbnail recovers its matching original without reloading the list',
    (tester) async {
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TopicTile(
                site,
                const Topic(
                  id: '157330',
                  title: 'cached post',
                  images: [thumbnail],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(site.reads, 1);
        expect(client.requests, contains(original));
        expect(client.requestHeaders[original]?['Cookie'], 'auth=fixture');
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(Image).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final gallery = tester.widget<GalleryPage>(find.byType(GalleryPage));
        expect(gallery.images, [original]);
        expect(gallery.cookie, 'auth=fixture');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    },
  );

  test('thumbnail aid parsing only accepts the observed same-site format', () {
    expect(forumThumbnailAid(thumbnail), '166973');
    expect(
      forumThumbnailAid(thumbnail.replaceFirst('https:', 'http:')),
      '166973',
    );
    expect(
      forumThumbnailAid(thumbnail.replaceFirst('ycoo.net', 'outside.invalid')),
      isNull,
    );
    expect(
      forumThumbnailAid(thumbnail.replaceFirst('ycoo.net', 'user@ycoo.net')),
      isNull,
    );
    expect(forumThumbnailAid(original), isNull);
  });

  test(
    'original metadata reads coalesce and do not cache a failed request',
    () async {
      site.pending = Completer<void>();
      final first = site.topicImageOriginals('157330');
      final second = site.topicImageOriginals('157330');
      final firstError = expectLater(first, throwsA(isA<SiteException>()));
      final secondError = expectLater(second, throwsA(isA<SiteException>()));
      expect(site.reads, 1);
      site.pending!.completeError(SiteException('offline'));
      await Future.wait([firstError, secondError]);
      site.pending = null;
      expect((await site.topicImageOriginals('157330'))['166973'], original);
      expect(site.reads, 2);
    },
  );

  test(
    'recovery preserves attachment permissions and validates thread and URL',
    () async {
      final attachments =
          (site.result['postlist'] as List).first['attachments'] as Map;
      attachments['paid'] = {
        'isimage': '1',
        'url': 'data/attachment/forum/',
        'attachment': 'paid.jpg',
        'price': '2',
        'payed': '0',
      };
      attachments['unsafe'] = {
        'isimage': '1',
        'url': 'https://user@outside.invalid/',
        'attachment': 'test.jpg',
      };
      attachments['external'] = {
        'isimage': '1',
        'url': 'https://outside.invalid/',
        'attachment': 'test.jpg',
      };
      final recovered = await site.topicImageOriginals('157330');
      expect(recovered.keys, unorderedEquals(['166973', 'external']));
      expect(
        siteImageHeaders(recovered['external']!, cookie: 'secret'),
        isNot(contains('Cookie')),
      );
      site.result['forum_threadpay'] = '1';
      expect(await site.topicImageOriginals('157330'), isEmpty);
      site.result['forum_threadpay'] = '0';
      site.result['thread'] = {'tid': 'wrong'};
      await expectLater(
        site.topicImageOriginals('157330'),
        throwsA(isA<SiteException>()),
      );
    },
  );

  test('account changes reject pending original metadata', () async {
    site.pending = Completer<void>();
    final request = site.topicImageOriginals('157330');
    final error = expectLater(request, throwsA(isA<SiteException>()));
    site.sessionEpoch++;
    site.uid = 'new-account';
    site.pending!.complete();
    await error;
  });

  testWidgets(
    'healthy thumbnails use scoped cookies and need no metadata request',
    (tester) async {
      try {
        client.status = 200;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TopicTile(
                site,
                const Topic(
                  id: '157330',
                  title: 'healthy',
                  images: [thumbnail],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(client.requests, contains(thumbnail));
        expect(client.requestHeaders[thumbnail]?['Cookie'], 'auth=fixture');
        expect(site.reads, 0);
        expect(find.byTooltip('图片加载失败，点击重试'), findsNothing);
        final decoded = (await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(pixels);
          final image = (await codec.getNextFrame()).image;
          codec.dispose();
          return image;
        }))!;
        addTearDown(decoded.dispose);
        final galleryProvider = ExtendedNetworkImageProvider(
          thumbnail,
          cache: true,
        );
        PaintingBinding.instance.imageCache.putIfAbsent(
          await galleryProvider.obtainKey(ImageConfiguration.empty),
          () => OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: decoded.clone())),
          ),
        );
        final source = tester.getCenter(find.byType(Hero));
        final navigator = Navigator.of(tester.element(find.byType(TopicTile)));
        await tester.tapAt(source);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        navigator.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
        await tester.tapAt(source);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(GalleryPage), findsOneWidget);
        expect(find.byType(ThreadPage), findsNothing);
        navigator.pop();
        await tester.pumpAndSettle();
        expect(navigator.canPop(), false);
        expect(tester.takeException(), isNull);
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    },
  );

  testWidgets('external images receive no site cookie or attachment recovery', (
    tester,
  ) async {
    try {
      const external =
          'https://outside.invalid/data/attachment/image/000/16/69/73_500_99999.jpg';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicTile(
              site,
              const Topic(id: '157330', title: 'external', images: [external]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(client.requestHeaders[external], isNot(contains('Cookie')));
      expect(site.reads, 0);
      expect(tester.takeException(), isNull);
    } finally {
      debugNetworkImageHttpClientProvider = null;
    }
  });

  testWidgets('temporary failure retries the image without a metadata loop', (
    tester,
  ) async {
    try {
      client.status = 503;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicTile(
              site,
              const Topic(id: '157330', title: 'offline', images: [thumbnail]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(site.reads, 0);
      expect(find.byTooltip('图片加载失败，点击重试'), findsOneWidget);
      client.status = 200;
      await tester.tap(find.byTooltip('图片加载失败，点击重试'));
      await tester.pumpAndSettle();
      expect(client.requests.where((url) => url == thumbnail), hasLength(2));
      expect(site.reads, 0);
      expect(find.byTooltip('图片加载失败，点击重试'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugNetworkImageHttpClientProvider = null;
    }
  });

  testWidgets(
    'unavailable original stays retryable without repeated API reads',
    (tester) async {
      try {
        site.result['forum_threadpay'] = '1';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TopicTile(
                site,
                const Topic(
                  id: '157330',
                  title: 'restricted',
                  images: [thumbnail],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(site.reads, 1);
        expect(client.requests, isNot(contains(original)));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(site.reads, 1);
        expect(find.byTooltip('图片加载失败，点击重试'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
    },
  );
}
