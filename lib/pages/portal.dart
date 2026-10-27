import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design_system/components/review_card.dart';
import '../data/portal.dart';
import '../data/site.dart';
import 'common.dart';

class PortalSections extends StatelessWidget {
  const PortalSections({
    required this.data,
    required this.onOpen,
    required this.active,
    this.onOpenForums,
    super.key,
  });
  final PortalData data;
  final ValueChanged<PortalEntry> onOpen;
  final VoidCallback? onOpenForums;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.banners.isNotEmpty)
            _PortalCarousel(
              entries: data.banners,
              onOpen: onOpen,
              active: active,
            ),
          if (data.services.isNotEmpty) ...[
            const SizedBox(height: 12),
            ReviewCard(
              margin: EdgeInsets.zero,
              onTap: () => onOpen(
                data.notices.firstOrNull ??
                    const PortalEntry(
                      title: '站务公告',
                      url: 'https://ycoo.net/forum-42-1.html',
                    ),
              ),
              child: ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: const Text('公告'),
                subtitle: data.notices.isEmpty
                    ? null
                    : Text(data.notices.first.title),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              padding: EdgeInsets.zero,
              primary: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.services.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisExtent: 88,
              ),
              itemBuilder: (context, i) {
                final item = data.services[i];
                final icon = switch (item.title) {
                  '每日签到' => Icons.event_available_outlined,
                  '开心农场' => Icons.agriculture_outlined,
                  '心情墙' => Icons.mood_outlined,
                  '云盘' => Icons.cloud_outlined,
                  _ => Icons.collections_bookmark_outlined,
                };
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onOpen(item),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(child: Icon(icon)),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          if (data.forums.isNotEmpty) ...[
            _heading(
              context,
              data.services.isEmpty ? '热门圈子' : '热门板块',
              onMore: onOpenForums,
            ),
            GridView.builder(
              key: const ValueKey('home-popular-forums'),
              padding: EdgeInsets.zero,
              primary: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.forums.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisExtent: 92,
              ),
              itemBuilder: (context, i) {
                final item = data.forums[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onOpen(item),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _PortalImage(item.image, width: 46, height: 46),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          if (data.rankings.isNotEmpty) ...[
            _heading(context, '七日排行榜'),
            ReviewCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < data.rankings.length; i++)
                    ListTile(
                      dense: true,
                      minTileHeight: 48,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      horizontalTitleGap: 8,
                      minLeadingWidth: 22,
                      leading: Text(
                        '${i + 1}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      title: Text(
                        data.rankings[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        data.rankings[i].detail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () => onOpen(data.rankings[i]),
                    ),
                ],
              ),
            ),
          ],
          if (data.pinned.isNotEmpty) ...[
            _heading(context, '置顶区'),
            GridView.builder(
              padding: EdgeInsets.zero,
              primary: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.pinned.length,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisExtent:
                    64 *
                    (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
                      1,
                      double.infinity,
                    ),
                crossAxisSpacing: 12,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, i) {
                final item = data.pinned[i];
                return ReviewCard(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  onTap: () => onOpen(item),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _PortalImage(
                            item.image,
                            width: 48,
                            height: 48,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                item.detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          _heading(context, '社区动态'),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String title, {VoidCallback? onMore}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (onMore != null)
              TextButton(onPressed: onMore, child: const Text('全部')),
          ],
        ),
      );
}

class _PortalCarousel extends StatefulWidget {
  const _PortalCarousel({
    required this.entries,
    required this.onOpen,
    required this.active,
  });
  final List<PortalEntry> entries;
  final ValueChanged<PortalEntry> onOpen;
  final bool active;
  @override
  State<_PortalCarousel> createState() => _PortalCarouselState();
}

class _PortalCarouselState extends State<_PortalCarousel>
    with WidgetsBindingObserver {
  final controller = PageController();
  Timer? timer;
  int index = 0;
  bool resumed = true;
  DateTime lastTouch = DateTime.fromMillisecondsSinceEpoch(0);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted ||
          !widget.active ||
          !resumed ||
          !controller.hasClients ||
          ModalRoute.of(context)?.isCurrent != true ||
          DateTime.now().difference(lastTouch).inSeconds < 8 ||
          widget.entries.length < 2) {
        return;
      }
      final next = (index + 1) % widget.entries.length;
      if (MediaQuery.disableAnimationsOf(context)) {
        controller.jumpToPage(next);
      } else {
        controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    resumed = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: AspectRatio(
      aspectRatio: 2,
      child: Listener(
        onPointerDown: (_) => lastTouch = DateTime.now(),
        onPointerMove: (_) => lastTouch = DateTime.now(),
        child: Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: widget.entries.length,
              onPageChanged: (value) => setState(() => index = value),
              itemBuilder: (context, i) {
                final item = widget.entries[i];
                return Material(
                  child: InkWell(
                    onTap: () => widget.onOpen(item),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _PortalImage(item.image),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SiteAvatar(
                                    uid: '',
                                    name: item.author,
                                    url: item.avatar,
                                    radius: 12,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.author,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                item.detail,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(
              right: 12,
              top: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    '${index + 1} / ${widget.entries.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PortalImage extends StatelessWidget {
  const _PortalImage(this.url, {this.width, this.height});
  final String url;
  final double? width, height;
  @override
  Widget build(BuildContext context) => Image.network(
    url,
    width: width,
    height: height,
    fit: BoxFit.cover,
    headers: siteImageHeaders(url),
    cacheWidth: width == null ? 1000 : 140,
    errorBuilder: (_, _, _) => ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.image_outlined)),
    ),
  );
}
