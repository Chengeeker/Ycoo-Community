import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../core/design_system/components/review_frosted_app_bar.dart';
import '../data/site.dart';
import 'common.dart';
import '../core/utils/haptic_feedback_util.dart';
import '../core/widgets/app_scope.dart';
import '../core/widgets/review_gallery_glass_button.dart';

String? forumMediaUrl(String value) {
  final parsed = Uri.tryParse(value.trim());
  if (parsed == null) return null;
  var uri = parsed.hasScheme
      ? parsed
      : Uri.parse('$siteOrigin/').resolveUri(parsed);
  if (!['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  if (uri.scheme == 'http' && uri.host == 'ycoo.net') {
    uri = uri.replace(scheme: 'https');
  }
  return uri.toString();
}

bool isDirectForumVideo(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      RegExp(
        r'\.(mp4|m4v|mov|webm|m3u8)$',
        caseSensitive: false,
      ).hasMatch(uri.path);
}

Object forumGalleryHeroTag(Object scope, int index, String url) =>
    (scope, index, url);

class ForumVideoPreview extends StatelessWidget {
  const ForumVideoPreview({
    required this.url,
    required this.cookie,
    this.poster,
    super.key,
  });

  final String url;
  final String cookie;
  final String? poster;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Semantics(
        button: true,
        label: '播放视频',
        child: Card.outlined(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => push(context, ForumVideoPage(url, cookie: cookie)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (poster != null)
                    Image.network(
                      poster!,
                      headers: siteImageHeaders(poster!, cookie: cookie),
                      fit: BoxFit.cover,
                      cacheWidth: 960,
                      errorBuilder: (_, _, _) =>
                          ColoredBox(color: colors.surfaceContainerHighest),
                    )
                  else
                    ColoredBox(color: colors.surfaceContainerHighest),
                  Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 64,
                      color: colors.onSurface,
                      shadows: const [Shadow(blurRadius: 12)],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '视频 · 点击播放',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.onSurface,
                          backgroundColor: colors.surface.withValues(
                            alpha: .72,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GalleryPage extends StatefulWidget {
  const GalleryPage(
    this.images,
    this.initial, {
    this.cookie = '',
    this.heroScope,
    super.key,
  });

  final List<String> images;
  final String cookie;
  final int initial;
  final Object? heroScope;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

Future<void> openGallery(
  BuildContext context,
  List<String> images,
  int initial, {
  String cookie = '',
  Object? heroScope,
}) async {
  if (images.isEmpty || initial < 0 || initial >= images.length) return;
  if (cookie.isEmpty) {
    final source = images
        .map(Uri.tryParse)
        .whereType<Uri>()
        .where(isSite)
        .firstOrNull;
    if (source != null) {
      try {
        cookie =
            await Site.cookies.invokeMethod<String>('getCookies', {
              'url': source.toString(),
            }) ??
            '';
      } on MissingPluginException {
        /* Widget previews have no cookie store. */
      }
    }
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, animation, secondary) =>
          GalleryPage(images, initial, cookie: cookie, heroScope: heroScope),
      transitionsBuilder: (_, animation, secondary, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

Widget forumGalleryFlight(
  BuildContext context,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext from,
  BuildContext to,
) {
  if (direction == HeroFlightDirection.push) {
    final gallery = to.findAncestorStateOfType<_GalleryPageState>();
    ui.Image? preview;
    void visit(RenderObject object) {
      if (preview != null) return;
      if (object is RenderImage && object.image != null) {
        preview = object.image!.clone();
      }
      object.visitChildren(visit);
    }

    final object = from.findRenderObject();
    if (object != null) visit(object);
    if (gallery != null) {
      gallery.retainPreview(preview);
    } else {
      preview?.dispose();
    }
  }
  return (direction == HeroFlightDirection.push
          ? to.widget as Hero
          : from.widget as Hero)
      .child;
}

class _GalleryPageState extends State<GalleryPage>
    with SingleTickerProviderStateMixin {
  late final controller = ExtendedPageController(initialPage: widget.initial);
  final thumbnails = ScrollController();
  late final zoom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late int current = widget.initial;
  bool chrome = true, saving = false, sliding = false;
  VoidCallback? zoomListener;
  ui.Image? openingPreview;

  void retainPreview(ui.Image? image) {
    openingPreview?.dispose();
    openingPreview = image;
    if (image != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && thumbnails.hasClients) {
        thumbnails.jumpTo(
          (current * 62.0 - thumbnails.position.viewportDimension / 2 + 31)
              .clamp(0, thumbnails.position.maxScrollExtent),
        );
      }
    });
  }

  @override
  void dispose() {
    zoom.dispose();
    thumbnails.dispose();
    controller.dispose();
    openingPreview?.dispose();
    super.dispose();
  }

  void select(int index) {
    if (current == index) return;
    HapticFeedbackUtil.selection();
    controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final bytes = await loadGalleryImage(
        widget.images[current],
        widget.cookie,
      );
      final format = galleryImageFormat(bytes);
      if (format == null) throw SiteException('返回内容不是支持的图片');
      await appActions.invokeMethod('saveMediaToGallery', {
        'bytes': bytes,
        'fileName':
            'yuan_${DateTime.now().millisecondsSinceEpoch}.${format.$1}',
        'mimeType': format.$2,
      });
      if (mounted) feedback(context, '图片已保存至相册');
    } catch (e) {
      if (mounted) feedback(context, '保存失败：$e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final liquidGlass =
        AppScope.maybeOf(context)?.settings.liquidGlass ?? false;
    Widget button(String tooltip, IconData icon, VoidCallback? action) =>
        ReviewGalleryGlassIconButton(
          icon: Icon(icon, color: Colors.white),
          tooltip: tooltip,
          opacity: 1,
          opacityKey: ValueKey('gallery-$tooltip'),
          useLiquidGlass: liquidGlass,
          onPressed: action == null
              ? null
              : () {
                  HapticFeedbackUtil.light();
                  action();
                },
        );
    return ExtendedImageSlidePage(
      slideAxis: SlideAxis.vertical,
      slideType: SlideType.onlyImage,
      onSlidingPage: (state) {
        if (mounted && sliding != state.isSliding) {
          setState(() => sliding = state.isSliding);
        }
      },
      slidePageBackgroundHandler: (offset, size) => Colors.black.withValues(
        alpha: (1 - offset.dy.abs() / (size.height / 2)).clamp(0, 1),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  HapticFeedbackUtil.selection();
                  setState(() => chrome = !chrome);
                },
                child: ExtendedImageGesturePageView.builder(
                  controller: controller,
                  canScrollPage: (details) => (details?.totalScale ?? 1) <= 1,
                  itemCount: widget.images.length,
                  onPageChanged: (index) {
                    HapticFeedbackUtil.selectionTick();
                    setState(() => current = index);
                    if (thumbnails.hasClients) {
                      thumbnails.animateTo(
                        (index * 62.0 -
                                thumbnails.position.viewportDimension / 2 +
                                31)
                            .clamp(0, thumbnails.position.maxScrollExtent),
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  itemBuilder: (context, index) {
                    final url = widget.images[index];
                    Widget image = ExtendedImage.network(
                      url,
                      key: ValueKey((index, url)),
                      headers: siteImageHeaders(url, cookie: widget.cookie),
                      fit: BoxFit.contain,
                      mode: ExtendedImageMode.gesture,
                      enableSlideOutPage: true,
                      onDoubleTap: (state) {
                        HapticFeedbackUtil.selection();
                        final begin = state.gestureDetails?.totalScale ?? 1;
                        final end = begin > 1 ? 1.0 : 2.5;
                        zoom.stop();
                        zoom.reset();
                        if (zoomListener != null) {
                          zoom.removeListener(zoomListener!);
                        }
                        zoomListener = () {
                          if (state.mounted) {
                            state.handleDoubleTap(
                              scale:
                                  begin +
                                  (end - begin) *
                                      Curves.easeOutCubic.transform(zoom.value),
                              doubleTapPosition: state.pointerDownPosition,
                            );
                          }
                        };
                        zoom.addListener(zoomListener!);
                        zoom.forward();
                      },
                      initGestureConfigHandler: (_) => GestureConfig(
                        inPageView: true,
                        initialScale: 1,
                        maxScale: 5,
                        cacheGesture: false,
                      ),
                      loadStateChanged: (state) =>
                          switch (state.extendedImageLoadState) {
                            LoadState.loading =>
                              index == widget.initial && openingPreview != null
                                  ? RawImage(
                                      image: openingPreview,
                                      fit: BoxFit.contain,
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                            LoadState.failed => Center(
                              child: TextButton.icon(
                                onPressed: state.reLoadImage,
                                icon: const Icon(Icons.refresh),
                                label: const Text('图片加载失败，点击重试'),
                              ),
                            ),
                            LoadState.completed => null,
                          },
                    );
                    if (widget.heroScope case final scope?) {
                      image = Hero(
                        tag: forumGalleryHeroTag(scope, index, url),
                        flightShuttleBuilder: forumGalleryFlight,
                        child: image,
                      );
                    }
                    return SizedBox.expand(child: Center(child: image));
                  },
                ),
              ),
            ),
            if (chrome && !sliding)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        button(
                          '返回',
                          Icons.arrow_back_rounded,
                          () => Navigator.pop(context),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${current + 1} / ${widget.images.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        button(
                          saving ? '正在保存' : '保存图片到相册',
                          saving
                              ? Icons.hourglass_empty
                              : Icons.download_rounded,
                          saving ? null : save,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (chrome && !sliding && widget.images.length > 1)
              Positioned(
                left: 12,
                right: 12,
                bottom: MediaQuery.viewPaddingOf(context).bottom + 16,
                child: SizedBox(
                  height: 62,
                  child: LayoutBuilder(
                    builder: (context, constraints) => ListView.builder(
                      controller: thumbnails,
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            ((constraints.maxWidth -
                                        widget.images.length * 62) /
                                    2)
                                .clamp(0.0, double.infinity),
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.images.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () => select(index),
                          child: Container(
                            width: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: index == current
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                widget.images[index],
                                cacheWidth: 160,
                                headers: siteImageHeaders(
                                  widget.images[index],
                                  cookie: widget.cookie,
                                ),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<Uint8List> loadGalleryImage(String value, String cookie) async {
  var url = forumMediaUrl(value);
  if (url == null) throw SiteException('图片地址无效');
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 40),
    ),
  );
  try {
    for (var hop = 0; hop < 4; hop++) {
      final response = await dio.get<ResponseBody>(
        url!,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 400,
          headers: siteImageHeaders(url, cookie: cookie),
        ),
      );
      if ((response.statusCode ?? 200) >= 300) {
        final location = response.headers.value('location');
        await response.data!.stream.drain<void>();
        url = location == null
            ? null
            : forumMediaUrl(Uri.parse(url).resolve(location).toString());
        if (url == null) throw SiteException('图片跳转地址无效');
        continue;
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.data!.stream) {
        if (bytes.length + chunk.length > 64 * 1024 * 1024) {
          throw SiteException('图片超过 64MB，请使用原站下载');
        }
        bytes.add(chunk);
      }
      return bytes.takeBytes();
    }
    throw SiteException('图片跳转次数过多');
  } finally {
    dio.close(force: true);
  }
}

(String, String)? galleryImageFormat(Uint8List bytes) {
  if (bytes.length < 12) return null;
  if (bytes[0] == 0xff && bytes[1] == 0xd8) return ('jpg', 'image/jpeg');
  if (bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78 && bytes[3] == 71) {
    return ('png', 'image/png');
  }
  if (String.fromCharCodes(bytes.take(3)) == 'GIF') return ('gif', 'image/gif');
  if (String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
    return ('webp', 'image/webp');
  }
  if (bytes[0] == 66 && bytes[1] == 77) return ('bmp', 'image/bmp');
  if (String.fromCharCodes(bytes.skip(4).take(8)) == 'ftypavif') {
    return ('avif', 'image/avif');
  }
  return null;
}

class ForumVideoPage extends StatefulWidget {
  const ForumVideoPage(this.url, {this.cookie = '', super.key});

  final String url;
  final String cookie;

  @override
  State<ForumVideoPage> createState() => _ForumVideoPageState();
}

class _ForumVideoPageState extends State<ForumVideoPage>
    with WidgetsBindingObserver {
  VideoPlayerController? controller;
  Timer? hideControlsTimer;
  Object? error;
  bool controlsVisible = true;
  double speed = 1;
  double? scrubPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    final old = controller;
    controller = null;
    if (old != null) {
      old.removeListener(_videoChanged);
      await old.dispose();
    }
    if (!mounted) return;
    setState(() => error = null);
    final next = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: siteImageHeaders(widget.url, cookie: widget.cookie),
    );
    controller = next;
    next.addListener(_videoChanged);
    try {
      await next.initialize();
      if (!mounted) {
        next.removeListener(_videoChanged);
        if (identical(controller, next)) controller = null;
        await next.dispose();
        return;
      }
      await next.play();
      _showControlsTemporarily();
      setState(() {});
    } catch (_) {
      next.removeListener(_videoChanged);
      if (identical(controller, next)) controller = null;
      await next.dispose();
      if (mounted) setState(() => error = '视频加载失败');
    }
  }

  void _videoChanged() {
    if (!mounted) return;
    if (controller?.value.hasError == true) {
      if (error == null) setState(() => error = '视频播放失败');
    } else {
      setState(() {});
    }
  }

  void _showControlsTemporarily() {
    hideControlsTimer?.cancel();
    if (controller?.value.isPlaying != true) return;
    hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => controlsVisible = false);
    });
  }

  Future<void> _togglePlayback() async {
    final value = controller;
    if (value == null || !value.value.isInitialized) return;
    HapticFeedbackUtil.light();
    try {
      if (value.value.isPlaying) {
        await value.pause();
        hideControlsTimer?.cancel();
        setState(() => controlsVisible = true);
      } else {
        await value.play();
        setState(() => controlsVisible = true);
        _showControlsTemporarily();
      }
    } catch (_) {
      if (mounted) setState(() => error = '视频播放失败');
    }
  }

  Future<void> _setSpeed(double value) async {
    final active = controller;
    if (active == null) return;
    HapticFeedbackUtil.selection();
    try {
      await active.setPlaybackSpeed(value);
      if (mounted) setState(() => speed = value);
    } catch (_) {
      if (mounted) feedback(context, '无法调整播放速度');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        controller?.value.isPlaying == true) {
      unawaited(controller!.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    hideControlsTimer?.cancel();
    final active = controller;
    active?.removeListener(_videoChanged);
    if (active != null) unawaited(active.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = controller;
    return Scaffold(
      appBar: const ReviewFrostedAppBar(title: Text('视频播放')),
      body: error != null
          ? Failure(error!, _initialize)
          : active == null || !active.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: active.value.aspectRatio > 0
                            ? active.value.aspectRatio
                            : 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            VideoPlayer(active),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                HapticFeedbackUtil.selection();
                                setState(
                                  () => controlsVisible = !controlsVisible,
                                );
                                if (controlsVisible) {
                                  _showControlsTemporarily();
                                }
                              },
                              child: AnimatedOpacity(
                                opacity: controlsVisible ? 1 : 0,
                                duration: const Duration(milliseconds: 180),
                                child: ColoredBox(
                                  color: Colors.black.withValues(alpha: .24),
                                  child: Center(
                                    child: IconButton.filled(
                                      tooltip: active.value.isPlaying
                                          ? '暂停'
                                          : '播放',
                                      onPressed: _togglePlayback,
                                      iconSize: 36,
                                      icon: Icon(
                                        active.value.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _controls(active),
              ],
            ),
    );
  }

  Widget _controls(VideoPlayerController active) {
    final duration = active.value.duration;
    final position =
        scrubPosition ?? active.value.position.inMilliseconds.toDouble();
    final max = duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: position.clamp(0.0, max).toDouble(),
                max: max,
                semanticFormatterCallback: (value) =>
                    _formatDuration(Duration(milliseconds: value.round())),
                onChanged: (value) => setState(() => scrubPosition = value),
                onChangeEnd: (value) {
                  HapticFeedbackUtil.selection();
                  scrubPosition = null;
                  unawaited(
                    active
                        .seekTo(Duration(milliseconds: value.round()))
                        .catchError((_) {
                          if (mounted) feedback(context, '视频定位失败');
                        }),
                  );
                },
              ),
              Row(
                children: [
                  Text(
                    _formatDuration(
                      scrubPosition == null
                          ? active.value.position
                          : Duration(milliseconds: scrubPosition!.round()),
                    ),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Text(' / '),
                  Text(
                    _formatDuration(duration),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  PopupMenuButton<double>(
                    tooltip: '播放速度',
                    initialValue: speed,
                    onSelected: _setSpeed,
                    itemBuilder: (_) => [
                      for (final value in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                        PopupMenuItem(value: value, child: Text('$value×')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('$speed×'),
                    ),
                  ),
                  IconButton(
                    tooltip: active.value.isPlaying ? '暂停' : '播放',
                    onPressed: _togglePlayback,
                    icon: Icon(
                      active.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final seconds = duration.inSeconds;
  final hours = seconds ~/ 3600;
  final minutes = seconds ~/ 60 % 60;
  final remaining = seconds % 60;
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  final hourText = twoDigits(hours);
  final minuteText = twoDigits(minutes);
  final secondText = twoDigits(remaining);
  return hours > 0
      ? '$hourText:$minuteText:$secondText'
      : '$minuteText:$secondText';
}
