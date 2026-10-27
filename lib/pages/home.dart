import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/design_system/components/review_card.dart';
import '../core/design_system/components/review_choice_tile.dart';
import '../core/design_system/components/review_frosted_app_bar.dart';
import '../core/design_system/components/review_navigation_bar.dart';
import '../core/design_system/components/review_preference_tile.dart';
import '../core/design_system/components/review_switch_tile.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_section_card.dart';
import '../data/site.dart';
import '../data/portal.dart';
import '../settings.dart';
import '../core/utils/haptic_feedback_util.dart';
import 'common.dart';
import 'thread.dart';
import 'login.dart';
import 'portal.dart';
import 'media.dart';
import 'reading_settings.dart';
import 'editor_tools.dart';
import 'account_features.dart';

class HomePage extends StatefulWidget {
  const HomePage(this.site, this.settings, {super.key});
  final Site site;
  final Settings settings;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  final visited = <int>{0};
  var feed = GlobalKey<_TopicsPageState>();
  var guide = GlobalKey<_TopicsPageState>();
  late Future<List<Map<String, dynamic>>> forums;
  late final Future<void> initialSession;
  Future<void>? sessionRetry;
  bool sessionResolved = false;
  DateTime? lastTap;
  void selectTab(int value) {
    setState(() {
      index = value;
      visited.add(value);
    });
  }

  void sessionChanged() {
    if (mounted) {
      feed.currentState?.change(nextType: feed.currentState?.type);
      guide.currentState?.change(nextType: guide.currentState?.type);
      setState(() {});
    }
  }

  Future<void> ensureSessionReady() async {
    if (sessionResolved) return;
    try {
      await initialSession;
    } catch (_) {
      final retry = sessionRetry ??= widget.site.syncSession();
      try {
        await retry;
      } finally {
        if (identical(sessionRetry, retry)) sessionRetry = null;
      }
    }
    sessionResolved = true;
  }

  @override
  void dispose() {
    widget.site.removeListener(sessionChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final session = initialSession = widget.site.syncSession();
    forums = session.then(
      (_) => widget.site.forums(),
      onError: (_) => widget.site.forums(),
    );
    widget.site.addListener(sessionChanged);
    session
        .then((_) async {
          sessionResolved = true;
          if (mounted) setState(() {});
          try {
            final result = await widget.site.maybeAutoSignIn();
            if (mounted && result != null) feedback(context, result);
          } catch (_) {
            if (mounted) feedback(context, '自动签到未完成，请打开每日签到查看');
          }
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: widget.settings.floating,
    body: IndexedStack(
      index: index,
      children: [
        if (visited.contains(0))
          TopicsPage(
            widget.site,
            key: feed,
            root: true,
            home: true,
            ensureSessionReady: ensureSessionReady,
            active: index == 0,
            floatingNavigation: widget.settings.floating,
            liquidGlassNavigation: widget.settings.liquidGlass,
            onOpenForums: () => selectTab(1),
          )
        else
          const SizedBox.shrink(),
        if (visited.contains(1))
          ForumsPage(
            widget.site,
            key: ValueKey(widget.site.uid),
            forums: forums,
            onRefresh: () async {
              final next = widget.site.forums();
              setState(() => forums = next);
              await next;
            },
            floatingNavigation: widget.settings.floating,
            liquidGlassNavigation: widget.settings.liquidGlass,
          )
        else
          const SizedBox.shrink(),
        if (visited.contains(2))
          TopicsPage(
            widget.site,
            key: guide,
            root: true,
            guide: true,
            floatingNavigation: widget.settings.floating,
            liquidGlassNavigation: widget.settings.liquidGlass,
            initialView: 'newthread',
            title: '导读',
          )
        else
          const SizedBox.shrink(),
        if (visited.contains(3))
          MyDashboardPage(widget.site, widget.settings)
        else
          const SizedBox.shrink(),
      ],
    ),
    bottomNavigationBar: SizedBox(
      height: widget.settings.floating
          ? 76 + MediaQuery.viewPaddingOf(context).bottom
          : null,
      child: ReviewNavigationBar(
        selectedIndex: index,
        hasBottomInset: MediaQuery.viewPaddingOf(context).bottom > 0,
        useFloating: widget.settings.floating,
        useLiquidGlass: widget.settings.liquidGlass,
        onSelected: (value) {
          if (value == index && value == 0) {
            feed.currentState?.scrollToTop();
            final now = DateTime.now();
            if (lastTap != null &&
                now.difference(lastTap!).inMilliseconds < 300) {
              feed.currentState?.load(refresh: true);
            }
            lastTap = now;
          } else {
            selectTab(value);
          }
        },
      ),
    ),
  );
}

class TopicsPage extends StatefulWidget {
  const TopicsPage(
    this.site, {
    this.fid,
    this.title = '源社区',
    this.root = false,
    this.home = false,
    this.guide = false,
    this.active = true,
    this.floatingNavigation = false,
    this.liquidGlassNavigation = false,
    this.initialView = 'portal',
    this.onOpenForums,
    this.ensureSessionReady,
    this.embeddedTop,
    super.key,
  });
  final Site site;
  final String? fid;
  final String title;
  final bool root;
  final bool home, guide;
  final bool floatingNavigation;
  final bool liquidGlassNavigation;
  final String initialView;
  final bool active;
  final VoidCallback? onOpenForums;
  final Future<void> Function()? ensureSessionReady;
  final double? embeddedTop;
  @override
  State<TopicsPage> createState() => _TopicsPageState();
}

class _TopicsPageState extends State<TopicsPage> with TickerProviderStateMixin {
  static const followingViews = [
    'following',
    'following_forums',
    'following_friends',
  ];
  late final TabController homeTabs;
  late final TabController followingTabs;
  final scroll = ScrollController();
  final items = <Topic>[];
  String view = 'portal';
  String? type;
  Map<String, String> types = {};
  PortalData? portal;
  bool loading = false, more = true, checkingSession = false;
  Object? error;
  int page = 0, epoch = 0, selectionEpoch = 0;
  String get cacheKey =>
      'cache.v2.${widget.site.uid}.${widget.fid ?? view}.${type ?? 'all'}';
  @override
  void initState() {
    super.initState();
    view = widget.initialView;
    homeTabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: [
        'circles',
        'portal',
        'following',
      ].indexOf(view).clamp(0, 2),
    );
    followingTabs = TabController(length: 3, vsync: this);
    restore();
    scroll.addListener(() {
      if (scroll.position.extentAfter < 450 &&
          !loading &&
          more &&
          error == null) {
        load();
      }
    });
  }

  void restore() {
    final raw = widget.site.prefs.getString(cacheKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map;
        final cached = (data['items'] as List)
            .whereType<Map>()
            .map(Topic.fromJson)
            .toList();
        final incompletePins =
            widget.fid != null &&
            cached.any((topic) => topic.pinned && topic.author.isEmpty);
        if (incompletePins) {
          page = 0;
          more = true;
        } else {
          items.addAll(cached);
          page = number(data['page']);
          more = data['more'] == true;
        }
        types = Map<String, String>.from(data['types'] as Map? ?? {});
        if (data['portal'] is Map) {
          portal = PortalData.fromJson(data['portal'] as Map);
        }
      } catch (_) {
        items.clear();
      }
    }
    if (items.isEmpty) {
      load();
    } else if (items.any(
      (topic) => topic.level.isNotEmpty && topic.levelColor.isEmpty,
    )) {
      unawaited(_restoreLevelColors());
    }
  }

  Future<void> _restoreLevelColors() async {
    final generation = epoch;
    final session = widget.site.sessionEpoch;
    final key = cacheKey;
    final cachedPages = page.clamp(1, 200);
    try {
      for (var cachedPage = 1; cachedPage <= cachedPages; cachedPage++) {
        if (!mounted ||
            generation != epoch ||
            session != widget.site.sessionEpoch ||
            key != cacheKey)
          return;
        final batch = await widget.site.topics(
          fid: widget.fid,
          view: view,
          page: cachedPage,
          type: type,
        );
        if (!mounted ||
            generation != epoch ||
            session != widget.site.sessionEpoch ||
            key != cacheKey)
          return;
        final fresh = {for (final topic in batch.topics) topic.id: topic};
        var changed = false;
        for (var i = 0; i < items.length; i++) {
          final old = items[i];
          final current = fresh[old.id];
          if (old.level.isEmpty ||
              old.levelColor.isNotEmpty ||
              old.uid.isEmpty ||
              current == null ||
              current.uid != old.uid ||
              current.level != old.level ||
              current.levelColor.isEmpty)
            continue;
          items[i] = Topic.fromJson({
            ...old.toJson(),
            'levelColor': current.levelColor,
          });
          changed = true;
        }
        if (changed) {
          setState(() {});
          if (!loading) {
            final raw = widget.site.prefs.getString(key);
            if (raw != null) {
              final data = jsonDecode(raw) as Map;
              data['items'] = items.map((topic) => topic.toJson()).toList();
              await widget.site.prefs.setString(key, jsonEncode(data));
            }
          }
        }
        if (!batch.hasMore ||
            !items.any(
              (topic) =>
                  topic.level.isNotEmpty &&
                  topic.levelColor.isEmpty &&
                  topic.uid.isNotEmpty,
            ))
          break;
      }
    } catch (_) {
      // Keep the restored feed usable when metadata cannot be refreshed.
    }
  }

  Future<void> load({bool refresh = false}) async {
    if (loading && !refresh) return;
    final generation = refresh ? ++epoch : epoch;
    final next = refresh ? 1 : page + 1;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final batch = await widget.site.topics(
        fid: widget.fid,
        view: view,
        page: next,
        type: type,
      );
      if (!mounted || generation != epoch) return;
      setState(() {
        if (refresh) items.clear();
        final seen = items.map((e) => e.id).toSet();
        items.addAll(batch.topics.where((e) => seen.add(e.id)));
        page = next;
        more = batch.hasMore;
        types = batch.types;
        if (batch.portal != null) portal = batch.portal;
        loading = false;
      });
      // shortcut: cache at most the first 200 summaries; revisit for offline full-thread support.
      if (items.length <= 200) {
        await widget.site.prefs.setString(
          cacheKey,
          jsonEncode({
            'items': items.map((e) => e.toJson()).toList(),
            'page': page,
            'more': more,
            'types': types,
            'portal': portal?.toJson(),
          }),
        );
      }
    } catch (e) {
      if (mounted && generation == epoch) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  void scrollToTop() {
    if (!scroll.hasClients) return;
    scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void change({String? nextView, String? nextType}) {
    epoch++;
    setState(() {
      view = nextView ?? view;
      portal = null;
      type = nextType;
      items.clear();
      page = 0;
      more = true;
      loading = false;
      error = null;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
    restore();
  }

  Future<void> chooseView(String nextView) async {
    HapticFeedbackUtil.selection();
    final selection = ++selectionEpoch;
    if (checkingSession) setState(() => checkingSession = false);
    if (nextView == 'following' &&
        !widget.site.loggedIn &&
        widget.ensureSessionReady != null) {
      setState(() => checkingSession = true);
      try {
        await widget.ensureSessionReady!();
      } catch (_) {
        if (mounted && selection == selectionEpoch) {
          homeTabs.animateTo(
            view.startsWith('following')
                ? 2
                : ['circles', 'portal'].indexOf(view).clamp(0, 1),
          );
          feedback(context, '无法确认登录状态，请检查网络后重试');
        }
        return;
      } finally {
        if (mounted && selection == selectionEpoch) {
          setState(() => checkingSession = false);
        }
      }
      if (!mounted || selection != selectionEpoch) return;
    }
    if (nextView == 'following' && !widget.site.loggedIn) {
      await push(context, LoginPage(widget.site));
      if (!mounted || selection != selectionEpoch) return;
      if (!widget.site.loggedIn) {
        homeTabs.animateTo(
          view.startsWith('following')
              ? 2
              : ['circles', 'portal'].indexOf(view).clamp(0, 1),
        );
        return;
      }
    }
    change(
      nextView: nextView == 'following'
          ? followingViews[followingTabs.index]
          : nextView,
    );
  }

  void openPortalEntry(PortalEntry entry) {
    final fid = RegExp(r'forum-(\d+)')
        .firstMatch(Uri.parse(entry.url).path)
        ?.group(1);
    if (fid != null) {
      push(context, TopicsPage(widget.site, fid: fid, title: entry.title));
    } else {
      routeLink(context, widget.site, entry.url);
    }
  }

  @override
  void dispose() {
    epoch++;
    homeTabs.dispose();
    followingTabs.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toolbarHeight = widget.home && widget.root
        ? (MediaQuery.textScalerOf(context).scale(46) + 12).clamp(
            64.0,
            double.infinity,
          )
        : widget.root
        ? 76.0
        : kToolbarHeight;
    final showFollowingTabs = widget.home && view.startsWith('following');
    final filterTabs = widget.fid == null
        ? const <MapEntry<String?, String>>[
            MapEntry('newthread', '最新'),
            MapEntry('hot', '热门'),
            MapEntry('digest', '精华'),
            MapEntry('new', '回复'),
            MapEntry('sofa', '抢沙发'),
          ]
        : <MapEntry<String?, String>>[
            const MapEntry(null, '全部'),
            ...types.entries,
          ];
    final selectedFilter = filterTabs.indexWhere(
      (entry) => entry.key == (widget.fid == null ? view : type),
    );
    final filterTabHeight = (MediaQuery.textScalerOf(context).scale(14) + 28)
        .clamp(48.0, double.infinity);
    final scrollFilterTabs =
        filterTabs.length > 3 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2 ||
        filterTabs.any((entry) => entry.value.runes.length > 4);
    final top =
        widget.embeddedTop ??
        MediaQuery.paddingOf(context).top +
            toolbarHeight +
            (widget.home ? 48 : filterTabHeight) +
            (showFollowingTabs ? 48 : 0);
    final bottomClearance = widget.root || widget.embeddedTop != null
        ? reviewFloatingNavigationClearance(
            context,
            useFloating: widget.floatingNavigation,
            useLiquidGlass: widget.liquidGlassNavigation,
          )
        : 16.0;
    final scaffold = Scaffold(
      extendBodyBehindAppBar: true,
      appBar: widget.embeddedTop != null
          ? null
          : ReviewFrostedAppBar(
              bottom: widget.home
                  ? PreferredSize(
                      preferredSize: Size.fromHeight(
                        showFollowingTabs ? 96 : 48,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TabBar(
                            controller: homeTabs,
                            dividerColor: showFollowingTabs
                                ? Colors.transparent
                                : null,
                            onTap: (index) => chooseView(
                              ['circles', 'portal', 'following'][index],
                            ),
                            tabs: const [
                              Tab(text: '圈子'),
                              Tab(text: '推荐'),
                              Tab(text: '关注'),
                            ],
                          ),
                          if (showFollowingTabs)
                            TabBar.secondary(
                              controller: followingTabs,
                              onTap: (index) {
                                HapticFeedbackUtil.selection();
                                if (view != followingViews[index]) {
                                  change(nextView: followingViews[index]);
                                }
                              },
                              tabs: const [
                                Tab(text: '我的关注'),
                                Tab(text: '关注版块'),
                                Tab(text: '好友动态'),
                              ],
                            ),
                        ],
                      ),
                    )
                  : PreferredSize(
                      preferredSize: Size.fromHeight(filterTabHeight),
                      child: TabBar(
                        isScrollable: scrollFilterTabs,
                        tabAlignment: scrollFilterTabs
                            ? TabAlignment.start
                            : null,
                        onTap: (index) {
                          if (widget.fid == null) {
                            chooseView(filterTabs[index].key!);
                          } else {
                            HapticFeedbackUtil.selection();
                            change(nextType: filterTabs[index].key);
                          }
                        },
                        tabs: [
                          for (final entry in filterTabs)
                            Tab(height: filterTabHeight, text: entry.value),
                        ],
                      ),
                    ),
              automaticallyImplyLeading: !widget.root,
              toolbarHeight: toolbarHeight,
              title: GestureDetector(
                onTap: () {
                  HapticFeedbackUtil.light();
                  scrollToTop();
                },
                onDoubleTap: () {
                  HapticFeedbackUtil.light();
                  load(refresh: true);
                },
                child: widget.root
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title),
                          Text(
                            '更好的浏览体验',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      )
                    : Text(widget.title),
              ),
              actions: [
                if (widget.root)
                  IconButton(
                    tooltip: '刷新',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => load(refresh: true),
                  ),
                IconButton(
                  tooltip: '搜索',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => push(context, SearchPage(widget.site)),
                ),
                if (widget.root)
                  PopupMenuButton<String>(
                    tooltip: '更多操作',
                    onSelected: (value) {
                      if (value == 'site') {
                        openWeb(
                          context,
                          widget.home
                              ? '/portal.php'
                              : '/forum.php?mod=guide&view=newthread',
                          title: '原站',
                        );
                      } else if (value == 'forums') {
                        widget.onOpenForums?.call();
                      }
                    },
                    itemBuilder: (_) => [
                      if (widget.home)
                        const PopupMenuItem(
                          value: 'forums',
                          child: Text('浏览全部版块'),
                        ),
                      const PopupMenuItem(value: 'site', child: Text('打开原站')),
                    ],
                  ),
              ],
            ),
      floatingActionButton: widget.fid == null
          ? null
          : FloatingActionButton(
              tooltip: '发帖',
              onPressed: () => push(
                context,
                ComposePage(widget.site, fid: widget.fid!, types: types),
              ),
              child: const Icon(Icons.edit_outlined),
            ),
      body: checkingSession
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在确认登录状态'),
                ],
              ),
            )
          : RefreshIndicator(
              edgeOffset: top,
              onRefresh: () =>
                  HapticFeedbackUtil.refresh(() => load(refresh: true)),
              child: CustomScrollView(
                controller: scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.only(
                      top: top + (showFollowingTabs ? 0 : 12),
                    ),
                  ),
                  if (widget.home && !showFollowingTabs && portal != null)
                    SliverToBoxAdapter(
                      child: PortalSections(
                        data: portal!,
                        onOpen: openPortalEntry,
                        active: widget.active,
                        onOpenForums: view == 'circles'
                            ? () => openWeb(
                                context,
                                '/group.php?mobile=2',
                                title: '全部圈子',
                              )
                            : widget.onOpenForums,
                      ),
                    ),
                  if (items.isEmpty && loading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (items.isEmpty && error != null)
                    SliverFillRemaining(
                      child: Failure(error!, () => load(refresh: true)),
                    ),
                  if (items.isEmpty && !loading && error == null)
                    const SliverFillRemaining(
                      child: Center(child: Text('暂无帖子')),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) => TopicTile(
                        widget.site,
                        items[i],
                        followed: view == 'following',
                      ),
                    ),
                  ),
                  if (items.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: error != null
                              ? TextButton(
                                  onPressed: () => load(),
                                  child: Text('$error · 点击重试'),
                                )
                              : loading
                              ? const CircularProgressIndicator()
                              : more
                              ? TextButton(
                                  onPressed: () => load(),
                                  child: const Text('加载更多'),
                                )
                              : const Text('已显示全部内容'),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.only(bottom: bottomClearance),
                  ),
                ],
              ),
            ),
    );
    return widget.home || widget.embeddedTop != null
        ? scaffold
        : DefaultTabController(
            key: ValueKey(filterTabs.map((entry) => entry.key).join('|')),
            length: filterTabs.length,
            initialIndex: selectedFilter < 0 ? 0 : selectedFilter,
            child: scaffold,
          );
  }
}

class TopicTile extends StatelessWidget {
  const TopicTile(this.site, this.topic, {this.followed = false, super.key});
  final Site site;
  final Topic topic;
  final bool followed;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelValue = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(topic.levelColor)
        ? int.tryParse(topic.levelColor.substring(1), radix: 16)
        : null;
    final levelColor = Color(0xff000000 | (levelValue ?? 0xff9900));
    final levelText = levelColor.computeLuminance() > 0.179
        ? Colors.black
        : Colors.white;
    final followColor = theme.brightness == Brightness.dark
        ? const Color(0xffffb45e)
        : const Color(0xff875000);
    final genderColor = topic.gender == 'male'
        ? (theme.brightness == Brightness.dark
              ? const Color(0xff80caff)
              : const Color(0xff0061a4))
        : (theme.brightness == Brightness.dark
              ? const Color(0xffffb1c8)
              : const Color(0xffac2f65));
    return ReviewCard(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onTap: () => push(context, ThreadPage(site, topic)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: topic.uid.isEmpty
                      ? null
                      : () => push(context, ProfilePage(site, topic.uid)),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: SiteAvatar(
                        uid: topic.uid,
                        name: topic.author,
                        url: topic.avatar,
                        radius: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            topic.author.isEmpty ? '作者信息暂不可用' : topic.author,
                            style: theme.textTheme.labelLarge,
                          ),
                          if (topic.level.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: levelColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                topic.level,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: levelText,
                                ),
                              ),
                            ),
                          if (topic.gender == 'male' ||
                              topic.gender == 'female')
                            Semantics(
                              label: topic.gender == 'male' ? '男' : '女',
                              child: Icon(
                                topic.gender == 'male'
                                    ? Icons.male
                                    : Icons.female,
                                size: 17,
                                color: genderColor,
                              ),
                            ),
                          if (topic.verificationIcon.isNotEmpty)
                            Image.network(
                              topic.verificationIcon,
                              width: 18,
                              height: 18,
                              headers: siteImageHeaders(topic.verificationIcon),
                              semanticLabel: topic.verificationLabel.isEmpty
                                  ? '认证'
                                  : topic.verificationLabel,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.verified, size: 18),
                            ),
                        ],
                      ),
                      if (topic.time.isNotEmpty)
                        Text(
                          topic.time,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (topic.uid.isNotEmpty && topic.uid != site.uid)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: followColor,
                      side: BorderSide(color: followColor),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(48, 32),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () async {
                      if (!site.loggedIn) {
                        await push(context, LoginPage(site));
                      } else if (context.mounted) {
                        await openWeb(
                          context,
                          '/home.php?mod=space&uid=${topic.uid}&do=profile&mobile=2',
                          title: '关注与用户资料',
                        );
                      }
                    },
                    child: Text(followed ? '已关注' : '关注'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (topic.pinned) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 2, right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '置顶',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    topic.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            if (topic.preview.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  topic.preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (topic.images.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: topic.images.length == 1 ? 220 : 190,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: topic.images.length >= 3 ? 2 : 1,
                      child: _image(context, 0),
                    ),
                    if (topic.images.length > 1) ...[
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _image(context, 1)),
                            if (topic.images.length > 2) ...[
                              const SizedBox(height: 4),
                              Expanded(child: _image(context, 2)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (topic.forum.isNotEmpty ||
                topic.likes.isNotEmpty ||
                topic.replies.isNotEmpty ||
                topic.views.isNotEmpty)
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (topic.forum.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '# ${topic.forum}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  if (topic.likes.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: () => openWeb(
                        context,
                        '/thread-${topic.id}-1-1.html?mobile=2',
                        title: '点赞与帖子互动',
                      ),
                      icon: const Icon(
                        Icons.thumb_up_outlined,
                        size: 16,
                        semanticLabel: '点赞',
                      ),
                      label: Text(topic.likes),
                    ),
                  if (topic.replies.isNotEmpty)
                    _topicCount(
                      context,
                      Icons.chat_bubble_outline_rounded,
                      topic.replies,
                      '回复',
                    ),
                  if (topic.views.isNotEmpty)
                    _topicCount(
                      context,
                      Icons.visibility_outlined,
                      topic.views,
                      '阅读',
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _topicCount(
    BuildContext context,
    IconData icon,
    String count,
    String label,
  ) => Semantics(
    label: '$label $count',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            count,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _image(BuildContext context, int index) {
    final url = topic.images[index];
    return InkWell(
      onTap: () => openGallery(context, topic.images, index, heroScope: topic),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: forumGalleryHeroTag(topic, index, url),
              flightShuttleBuilder: forumGalleryFlight,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: 900,
                headers: siteImageHeaders(url),
                errorBuilder: (_, _, _) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_outlined),
                ),
              ),
            ),
            if (index == 2 && topic.images.length > 3)
              ColoredBox(
                color: Colors.black45,
                child: Center(
                  child: Text(
                    '+${topic.images.length - 3}',
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommunityStat extends StatelessWidget {
  const _CommunityStat({required this.label, required this.value});
  final String label;
  final Object value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(value.toString(), style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

class _ForumCard extends StatelessWidget {
  const _ForumCard(this.forum, {required this.onTap, this.compact = false});
  final Map<String, dynamic> forum;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = textOf(forum, 'icon');
    final radius = compact ? 14.0 : 16.0;
    return ReviewCard(
      margin: EdgeInsets.zero,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: icon.isEmpty
                  ? Container(
                      width: 44,
                      height: 44,
                      color: scheme.secondaryContainer,
                      child: Icon(
                        Icons.forum_outlined,
                        color: scheme.onSecondaryContainer,
                      ),
                    )
                  : Image.network(
                      icon,
                      width: 44,
                      height: 44,
                      cacheWidth: 96,
                      fit: BoxFit.cover,
                      headers: siteImageHeaders(icon),
                      errorBuilder: (_, _, _) => Container(
                        width: 44,
                        height: 44,
                        color: scheme.secondaryContainer,
                        child: Icon(
                          Icons.forum_outlined,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textOf(forum, 'name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${number(forum['todayposts'])} 今日 · ${number(forum['threads'])} 主题',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (!compact) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class ForumsPage extends StatefulWidget {
  const ForumsPage(
    this.site, {
    required this.forums,
    required this.onRefresh,
    this.floatingNavigation = false,
    this.liquidGlassNavigation = false,
    super.key,
  });
  final Site site;
  final Future<List<Map<String, dynamic>>> forums;
  final Future<void> Function() onRefresh;
  final bool floatingNavigation;
  final bool liquidGlassNavigation;
  @override
  State<ForumsPage> createState() => _ForumsPageState();
}

class _ForumsPageState extends State<ForumsPage> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    const toolbarHeight = 76.0;
    final tabHeight = (MediaQuery.textScalerOf(context).scale(14) + 28).clamp(
      48.0,
      double.infinity,
    );
    final contentTop =
        MediaQuery.paddingOf(context).top + toolbarHeight + tabHeight + 12;
    final bottomClearance = reviewFloatingNavigationClearance(
      context,
      useFloating: widget.floatingNavigation,
      useLiquidGlass: widget.liquidGlassNavigation,
    );
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: ReviewFrostedAppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: toolbarHeight,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(tabHeight),
            child: Builder(
              builder: (context) => TabBar(
                onTap: (index) {
                  HapticFeedbackUtil.selection();
                  setState(() => selected = index);
                },
                tabs: [
                  for (final label in const ['版区', '新帖', '精选', '热门'])
                    Tab(height: tabHeight, text: label),
                ],
              ),
            ),
          ),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('社区'),
              Text(
                '浏览版块与今日动态',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '搜索',
              icon: const Icon(Icons.search_rounded),
              onPressed: () => push(context, SearchPage(widget.site)),
            ),
            IconButton(
              tooltip: '刷新版块',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: widget.onRefresh,
            ),
          ],
        ),
        body: selected != 0
            ? TopicsPage(
                widget.site,
                key: ValueKey('community-feed-$selected'),
                initialView: const ['newthread', 'digest', 'hot'][selected - 1],
                embeddedTop: contentTop - 12,
                floatingNavigation: widget.floatingNavigation,
                liquidGlassNavigation: widget.liquidGlassNavigation,
              )
            : FutureBuilder(
                future: widget.forums,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Failure(snapshot.error!, widget.onRefresh);
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final roots = snapshot.data!;
                  final forumById = <String, Map<String, dynamic>>{
                    for (final root in roots) '${root['fid']}': root,
                    for (final root in roots)
                      for (final child
                          in (root['sublist'] as List? ?? const []))
                        if (child is Map)
                          '${child['fid']}': Map<String, dynamic>.from(child),
                  };
                  final forums = forumById.values.toList();
                  final groups = <String, List<Map<String, dynamic>>>{};
                  for (final forum in forums) {
                    final category = textOf(forum, 'category');
                    groups
                        .putIfAbsent(
                          category.isEmpty ? '全部版块' : category,
                          () => [],
                        )
                        .add(forum);
                  }
                  final today = roots.fold<int>(
                    0,
                    (sum, f) => sum + number(f['todayposts']),
                  );
                  final threads = roots.fold<int>(
                    0,
                    (sum, f) => sum + number(f['threads']),
                  );
                  final posts = roots.fold<int>(
                    0,
                    (sum, f) => sum + number(f['posts']),
                  );
                  return RefreshIndicator(
                    onRefresh: () =>
                        HapticFeedbackUtil.refresh(widget.onRefresh),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.only(top: contentTop),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ReviewCard(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    if (widget.site.forumStatistics.isNotEmpty)
                                      for (final entry
                                          in widget
                                              .site
                                              .forumStatistics
                                              .entries)
                                        _CommunityStat(
                                          label: entry.key,
                                          value: entry.value,
                                        )
                                    else ...[
                                      _CommunityStat(
                                        label: '今日新帖',
                                        value: today,
                                      ),
                                      _CommunityStat(
                                        label: '主题',
                                        value: threads,
                                      ),
                                      _CommunityStat(label: '帖子', value: posts),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                            child: Text(
                              '全部版块',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                        for (final group in groups.entries)
                          SliverToBoxAdapter(
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              maintainState: true,
                              title: Text(group.key),
                              onExpansionChanged: (_) =>
                                  HapticFeedbackUtil.selection(),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                12,
                              ),
                              children: [
                                GridView.builder(
                                  padding: EdgeInsets.zero,
                                  primary: false,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: group.value.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount:
                                            MediaQuery.sizeOf(context).width >=
                                                840
                                            ? 4
                                            : 2,
                                        mainAxisExtent: 88,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                      ),
                                  itemBuilder: (context, index) {
                                    final forum = group.value[index];
                                    return _ForumCard(
                                      forum,
                                      compact: true,
                                      onTap: () => push(
                                        context,
                                        TopicsPage(
                                          widget.site,
                                          fid: '${forum['fid']}',
                                          title: textOf(forum, 'name'),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.only(bottom: bottomClearance),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage(this.site, {super.key});
  final Site site;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final input = TextEditingController();
  Future<TopicBatch>? future;
  void search() {
    if (input.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => future = widget.site.search(input.text.trim()));
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ReviewFrostedAppBar(
      title: TextField(
        controller: input,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => search(),
        decoration: const InputDecoration(
          hintText: '搜索源社区',
          border: InputBorder.none,
        ),
      ),
      actions: [
        IconButton(
          tooltip: '搜索',
          icon: const Icon(Icons.search),
          onPressed: search,
        ),
      ],
    ),
    body: future == null
        ? const Center(child: Text('输入关键词搜索帖子'))
        : FutureBuilder(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Failure(snapshot.error!, search);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.topics.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('暂无结果'),
                      TextButton(
                        onPressed: () => openWeb(
                          context,
                          '/search.php?mod=forum',
                          title: '原站搜索',
                        ),
                        child: const Text('打开原站搜索'),
                      ),
                    ],
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  ...snapshot.data!.topics.map(
                    (e) => TopicTile(widget.site, e),
                  ),
                  if (snapshot.data!.next != null)
                    TextButton(
                      onPressed: () {
                        final previous = snapshot.data!.topics;
                        final next = snapshot.data!.next!;
                        setState(
                          () => future = widget.site
                              .search(input.text.trim(), next: next)
                              .then(
                                (batch) => TopicBatch(
                                  [...previous, ...batch.topics],
                                  batch.hasMore,
                                  next: batch.next,
                                ),
                              ),
                        );
                      },
                      child: const Text('加载更多结果'),
                    ),
                  TextButton(
                    onPressed: () => openWeb(
                      context,
                      '/search.php?mod=forum',
                      title: '原站搜索',
                    ),
                    child: const Text('更多搜索选项'),
                  ),
                ],
              );
            },
          ),
  );
}

class MyDashboardPage extends StatelessWidget {
  const MyDashboardPage(this.site, this.settings, {super.key});
  final Site site;
  final Settings settings;

  Future<void> openContent(
    BuildContext context,
    String module,
    String title,
  ) async {
    if (!site.loggedIn) {
      await push(context, LoginPage(site));
    }
    if (context.mounted && site.loggedIn) {
      await push(context, MyContentPage(site, module, title));
    }
  }

  Future<void> openSpace(BuildContext context) async {
    if (!site.loggedIn) {
      await push(context, LoginPage(site));
    }
    if (context.mounted && site.loggedIn) {
      await push(context, ProfilePage(site, site.uid));
    }
  }

  Future<void> openAccountWeb(
    BuildContext context,
    String path,
    String title,
  ) async {
    if (!site.loggedIn) await push(context, LoginPage(site));
    if (context.mounted && site.loggedIn) {
      await openWeb(context, path, title: title);
    }
  }

  Future<void> openAccountPage(BuildContext context, Widget page) async {
    if (!site.loggedIn) await push(context, LoginPage(site));
    if (context.mounted && site.loggedIn) await push(context, page);
  }

  @override
  Widget build(BuildContext context) {
    const toolbarHeight = 76.0;
    final scheme = Theme.of(context).colorScheme;
    final bottomClearance = reviewFloatingNavigationClearance(
      context,
      useFloating: settings.floating,
      useLiquidGlass: settings.liquidGlass,
    );
    final shortcuts = [
      ('我的空间', Icons.home_work_outlined, () => openSpace(context)),
      (
        '我的帖子',
        Icons.article_outlined,
        () => openContent(context, 'mythread', '我的帖子'),
      ),
      (
        '我的收藏',
        Icons.bookmark_outline_rounded,
        () => openContent(context, 'myfavthread', '我的收藏'),
      ),
      (
        '我的好友',
        Icons.people_outline,
        () => openAccountWeb(
          context,
          '/home.php?mod=space&do=friend&mobile=2',
          '我的好友',
        ),
      ),
      (
        '我的日志',
        Icons.book_outlined,
        () => openAccountWeb(
          context,
          '/home.php?mod=space&do=blog&view=me&mobile=2',
          '我的日志',
        ),
      ),
      (
        '我的相册',
        Icons.photo_library_outlined,
        () => openAccountWeb(
          context,
          '/home.php?mod=space&do=album&view=me&mobile=2',
          '我的相册',
        ),
      ),
      (
        '我的圈子',
        Icons.groups_outlined,
        () => openAccountWeb(context, '/group.php?mod=my&mobile=2', '我的圈子'),
      ),
      (
        '我的心情',
        Icons.mood_outlined,
        () => openAccountWeb(
          context,
          '/home.php?mod=space&do=doing&view=me&mobile=2',
          '我的心情',
        ),
      ),
    ];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: ReviewFrostedAppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: toolbarHeight,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('我的'),
            Text(
              '个人空间与设置',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => push(context, SettingsPage(site, settings)),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + toolbarHeight + 12,
          16,
          bottomClearance,
        ),
        children: [
          _MyIdentityCard(
            site,
            key: ValueKey(site.uid),
            onTap: () => openSpace(context),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Text(
                      '我的内容',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  GridView.builder(
                    key: const ValueKey('my-content-grid'),
                    padding: EdgeInsets.zero,
                    primary: false,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: shortcuts.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisExtent: 86,
                        ),
                    itemBuilder: (context, index) {
                      final (label, icon, onTap) = shortcuts[index];
                      final color = switch (index % 4) {
                        0 => scheme.primary,
                        1 => scheme.tertiary,
                        2 => scheme.secondary,
                        _ => scheme.error,
                      };
                      return Semantics(
                        button: true,
                        label: label,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: onTap,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, size: 28, color: color),
                              const SizedBox(height: 8),
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppSectionCard(
            child: Column(
              children: [
                ReviewPreferenceTile(
                  title: '消息提醒',
                  leading: Icon(
                    Icons.notifications_none_rounded,
                    color: scheme.primary,
                  ),
                  onTap: () => openAccountPage(context, MessagesMenuPage(site)),
                ),
                ReviewPreferenceTile(
                  title: '我的私信',
                  leading: Icon(Icons.mail_outline, color: scheme.secondary),
                  onTap: () => openContent(context, 'mypm', '私信'),
                ),
                ReviewPreferenceTile(
                  title: '个性化',
                  subtitle: '主题、色彩、字体、导航与液态玻璃',
                  leading: Icon(Icons.palette_outlined, color: scheme.tertiary),
                  onTap: () => push(context, AppearancePage(settings)),
                ),
                ReviewPreferenceTile(
                  title: '阅读历史',
                  leading: Icon(Icons.history_rounded, color: scheme.primary),
                  onTap: () => push(context, HistoryPage(site)),
                ),
                ReviewPreferenceTile(
                  title: '社区服务',
                  subtitle: '签到、圈子、排行与站点插件',
                  leading: Icon(
                    Icons.explore_outlined,
                    color: scheme.secondary,
                  ),
                  onTap: () => push(context, ServicesPage(site)),
                ),
                ReviewSwitchTile(
                  title: '夜间模式',
                  leading: const Icon(Icons.dark_mode_outlined),
                  value: Theme.of(context).brightness == Brightness.dark,
                  onChanged: (value) => settings.set(
                    'themeMode',
                    (value ? ThemeMode.dark : ThemeMode.light).index,
                  ),
                ),
                ReviewPreferenceTile(
                  title: '访问推广',
                  leading: Icon(Icons.send_outlined, color: scheme.secondary),
                  onTap: () => openAccountPage(context, PromotionPage(site)),
                ),
                ReviewPreferenceTile(
                  title: '资料设置',
                  leading: Icon(Icons.badge_outlined, color: scheme.secondary),
                  onTap: () =>
                      openAccountPage(context, ProfileSettingsPage(site)),
                ),
                ReviewPreferenceTile(
                  title: '我的积分',
                  leading: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: scheme.primary,
                  ),
                  onTap: () => openAccountPage(context, CreditsPage(site)),
                ),
                ReviewPreferenceTile(
                  title: '小黑屋',
                  leading: Icon(Icons.block_outlined, color: scheme.error),
                  onTap: () => push(context, DarkroomPage(site)),
                ),
                for (final entry in const [
                  (
                    '最近访客',
                    '/home.php?mod=space&do=friend&view=visitor&mobile=2',
                    Icons.directions_walk_rounded,
                  ),
                  (
                    '邀请好友',
                    '/home.php?mod=spacecp&ac=invite&mobile=2',
                    Icons.person_add_alt_1_rounded,
                  ),
                  (
                    '繁星开通',
                    '/plugin.php?id=boan_group&frame=yes&mobile=2',
                    Icons.stars_outlined,
                  ),
                  (
                    '我的任务',
                    '/home.php?mod=task&mobile=2',
                    Icons.task_alt_outlined,
                  ),
                  (
                    '我的勋章',
                    '/home.php?mod=medal&mobile=2',
                    Icons.workspace_premium_outlined,
                  ),
                  (
                    '我的道具',
                    '/home.php?mod=magic&mobile=2',
                    Icons.auto_fix_high_outlined,
                  ),
                  (
                    '更改头像',
                    '/home.php?mod=spacecp&ac=avatar&mobile=2',
                    Icons.add_a_photo_outlined,
                  ),
                  (
                    '空间背景',
                    '/plugin.php?id=comiis_app_homestyle&mobile=2',
                    Icons.wallpaper_outlined,
                  ),
                ])
                  ReviewPreferenceTile(
                    title: entry.$1,
                    leading: Icon(entry.$3, color: scheme.secondary),
                    onTap: () => openAccountWeb(context, entry.$2, entry.$1),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyIdentityCard extends StatefulWidget {
  const _MyIdentityCard(this.site, {required this.onTap, super.key});
  final Site site;
  final VoidCallback onTap;

  @override
  State<_MyIdentityCard> createState() => _MyIdentityCardState();
}

class _MyIdentityCardState extends State<_MyIdentityCard> {
  Map<String, int>? stats;
  int? requestedSession;

  Map<String, int>? _readStats(Object? value, String uid) {
    if (value is! Map || '${value['uid'] ?? ''}' != uid) return null;
    final result = <String, int>{};
    for (final field in ['threads', 'posts', 'credits']) {
      final count = int.tryParse('${value[field] ?? ''}');
      if (count == null || count < 0) return null;
      result[field] = count;
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    if (widget.site.loggedIn) {
      final uid = widget.site.uid;
      try {
        final cached = widget.site.prefs.getString('cache.profile.$uid');
        if (cached != null) stats = _readStats(jsonDecode(cached), uid);
      } catch (_) {
        // An invalid snapshot is ignored and replaced by a verified response.
      }
      requestedSession = widget.site.sessionEpoch;
      unawaited(_loadStats(uid, requestedSession!));
    }
  }

  @override
  void didUpdateWidget(covariant _MyIdentityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.site.loggedIn && requestedSession != widget.site.sessionEpoch) {
      requestedSession = widget.site.sessionEpoch;
      unawaited(_loadStats(widget.site.uid, requestedSession!));
    }
  }

  Future<void> _loadStats(String uid, int session) async {
    try {
      final profile = await widget.site.api('profile', query: {'uid': uid});
      final next = _readStats(profile['space'], uid);
      if (!mounted ||
          widget.site.uid != uid ||
          widget.site.sessionEpoch != session ||
          next == null)
        return;
      setState(() => stats = next);
      await widget.site.prefs.setString(
        'cache.profile.$uid',
        jsonEncode({'uid': uid, ...next}),
      );
    } catch (_) {
      // Retain the last verified counts if the site is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final scheme = Theme.of(context).colorScheme;
    if (!site.loggedIn) {
      return AppSectionCard(
        child: ListTile(
          contentPadding: const EdgeInsets.all(20),
          leading: CircleAvatar(
            radius: 30,
            backgroundColor: scheme.primaryContainer,
            child: Icon(
              Icons.person_outline_rounded,
              color: scheme.onPrimaryContainer,
            ),
          ),
          title: const Text('登录源社区'),
          subtitle: const Text('登录后查看帖子、收藏和消息'),
          trailing: const Icon(Icons.chevron_right),
          onTap: widget.onTap,
        ),
      );
    }
    return AppSectionCard(
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
            leading: SiteAvatar(
              uid: site.uid,
              name: site.username,
              url: site.avatar,
              radius: 30,
            ),
            title: Text(site.username),
            subtitle: Text('UID ${site.uid} · 查看个人空间'),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onTap,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                _CommunityStat(label: '主题', value: stats?['threads'] ?? '—'),
                _CommunityStat(label: '帖子', value: stats?['posts'] ?? '—'),
                _CommunityStat(label: '积分', value: stats?['credits'] ?? '—'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage(this.site, this.settings, {super.key});
  final Site site;
  final Settings settings;
  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: const ReviewFrostedAppBar(title: Text('设置')),
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + kToolbarHeight + 16,
        16,
        24,
      ),
      children: [
        const _SettingsSectionTitle('账号设置'),
        AppSectionCard(
          child: Column(
            children: [
              ReviewPreferenceTile(
                title: '我的账户',
                subtitle: '登录、消息、收藏和帖子',
                leading: const Icon(Icons.account_circle_outlined),
                onTap: () => push(context, AccountPage(site)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SettingsSectionTitle('偏好与功能'),
        AppSectionCard(
          child: Column(
            children: [
              ReviewPreferenceTile(
                title: '阅读历史',
                leading: const Icon(Icons.history_rounded),
                onTap: () => push(context, HistoryPage(site)),
              ),
              ReviewPreferenceTile(
                title: '个性化',
                subtitle: '明暗、色彩、字体、导航与效果',
                leading: const Icon(Icons.palette_outlined),
                onTap: () => push(context, AppearancePage(settings)),
              ),
              ReviewPreferenceTile(
                title: '阅读与社区功能',
                subtitle: '自动签到、回复分页、URL 链接与 FPS',
                leading: const Icon(Icons.auto_stories_outlined),
                onTap: () => push(context, ReadingSettingsPage(site, settings)),
              ),
              ReviewPreferenceTile(
                title: '编辑回复菜单',
                subtitle: '文字格式、菜单排序与快捷回复',
                leading: const Icon(Icons.edit_note_outlined),
                onTap: () => push(context, ReplyToolsPage(site.prefs)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SettingsSectionTitle('内容与服务'),
        AppSectionCard(
          child: Column(
            children: [
              ReviewPreferenceTile(
                title: '清除内容缓存',
                subtitle: '保留账户和阅读历史',
                leading: const Icon(Icons.cleaning_services_outlined),
                onTap: () async {
                  await site.clearContentCache();
                  if (context.mounted) feedback(context, '内容缓存已清除');
                },
              ),
              ReviewPreferenceTile(
                title: '社区服务',
                subtitle: '签到、圈子、排行与站点插件',
                leading: const Icon(Icons.explore_outlined),
                onTap: () => push(context, ServicesPage(site)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SettingsSectionTitle('关于与支持'),
        AppSectionCard(
          child: Column(
            children: [
              ReviewPreferenceTile(
                title: '关于源社区',
                subtitle: '1.0.0 · 界面复用自 Review',
                leading: const Icon(Icons.info_outline),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: '源社区',
                  applicationVersion: '1.0.0',
                  children: [
                    const Text(
                      '基于源论坛的第三方客户端。M3 主题与通用组件复用自 Review（MIT）。社区内容与账户权限由原站提供。',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AppearancePage extends StatelessWidget {
  const AppearancePage(this.settings, {super.key});
  final Settings settings;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ReviewFrostedAppBar(title: Text('个性化')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsSectionTitle('明暗模式'),
              ReviewChoiceTile<ThemeMode>(
                title: '跟随系统',
                summary: '自动匹配系统深色/浅色设置',
                value: ThemeMode.system,
                groupValue: settings.mode,
                onSelected: () =>
                    settings.set('themeMode', ThemeMode.system.index),
              ),
              const Divider(height: 1, indent: 72),
              ReviewChoiceTile<ThemeMode>(
                title: '浅色模式',
                value: ThemeMode.light,
                groupValue: settings.mode,
                onSelected: () =>
                    settings.set('themeMode', ThemeMode.light.index),
              ),
              const Divider(height: 1, indent: 72),
              ReviewChoiceTile<ThemeMode>(
                title: '深色模式',
                value: ThemeMode.dark,
                groupValue: settings.mode,
                onSelected: () =>
                    settings.set('themeMode', ThemeMode.dark.index),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ReviewSwitchTile(
                leading: Icon(
                  Icons.contrast_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: '纯黑深色模式',
                value: settings.pureBlack,
                onChanged: (v) => settings.set('pureBlack', v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsSectionTitle('色彩方案'),
                ReviewSwitchTile(
                  leading: Icon(
                    Icons.auto_awesome_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: 'Material You (Monet) 动态取色',
                  summary: '从 Android 12+ 壁纸自动提取主色调',
                  value: settings.dynamicColor,
                  onChanged: (v) => settings.set('dynamicColor', v),
                ),
                if (!settings.dynamicColor) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Text(
                      'Material 3 预置主题色',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < AppTheme.themeColors.length; i++)
                          ChoiceChip(
                            avatar: CircleAvatar(
                              radius: 10,
                              backgroundColor: AppTheme.getSeedColor(i),
                            ),
                            label: Text('${AppTheme.themeColors[i]['name']}'),
                            selected: settings.color == i,
                            onSelected: (_) => settings.set('color', i),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(
              Icons.format_size_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('应用字体大小'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${(settings.textScale * 100).round()}% · 同时遵循系统字体设置'),
                Slider(
                  value: settings.textScale.clamp(0.8, 1.4),
                  min: 0.8,
                  max: 1.4,
                  divisions: 12,
                  label: '${(settings.textScale * 100).round()}%',
                  onChanged: (v) => settings.set('textScale', v),
                  onChangeEnd: (_) => HapticFeedbackUtil.selection(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsSectionTitle('底部导航'),
              ReviewSwitchTile(
                leading: Icon(
                  Icons.dock_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: '使用悬浮底栏',
                summary: '居中显示悬浮式导航栏',
                value: settings.floating,
                onChanged: (v) => settings.set('floating', v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsSectionTitle('显示效果'),
              ReviewSwitchTile(
                leading: Icon(
                  Icons.blur_on_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: '使用液态玻璃效果',
                summary: '控制液态玻璃控件；当前应用于悬浮底栏',
                value: settings.liquidGlass,
                onChanged: (v) => settings.set('liquidGlass', v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsSectionTitle('触感与震动'),
              ReviewSwitchTile(
                leading: Icon(
                  Icons.vibration_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: '触感与震动反馈',
                summary: '按键和导航操作时提供轻微触感',
                value: settings.haptics,
                onChanged: (v) => settings.set('haptics', v),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class HistoryPage extends StatefulWidget {
  const HistoryPage(this.site, {super.key});
  final Site site;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    final rows = widget.site.history();
    return Scaffold(
      appBar: ReviewFrostedAppBar(
        title: const Text('阅读历史'),
        actions: [
          IconButton(
            tooltip: '清空历史',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('清空阅读历史？'),
                  content: const Text('只清除此设备上的阅读记录。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('清空'),
                    ),
                  ],
                ),
              );
              if (yes == true) {
                await widget.site.prefs.remove('history.${widget.site.uid}');
                if (mounted) setState(() {});
              }
            },
          ),
        ],
      ),
      body: rows.isEmpty
          ? const Center(child: Text('还没有阅读记录'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: rows.map((e) => TopicTile(widget.site, e)).toList(),
            ),
    );
  }
}

class ServicesPage extends StatelessWidget {
  const ServicesPage(this.site, {super.key});
  final Site site;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const ReviewFrostedAppBar(title: Text('社区服务')),
    body: ListView(
      children: [
        for (final entry in const {
          '门户原站': '/portal.php',
          '每日签到': '/k_misign-sign.html?mobile=2',
          '开心农场': '/plugin.php?id=jnfarm&mobile=2',
          '心情墙': '/home.php?mod=space&do=doing&view=all&mobile=2',
          '云盘': '/plugin.php?id=bphp_clouds:index&mobile=2',
          '淘专辑': '/forum.php?mod=collection&op=all&mobile=2',
          '圈子': '/group.php?mod=index&mobile=2',
          '排行榜': '/misc.php?mod=ranklist&type=member&view=credit&mobile=2',
          '标签': '/misc.php?mod=tag&mobile=2',
          '访问推广': '/home.php?mod=spacecp&ac=promotion&mobile=2',
          '小黑屋': '/forum.php?mod=misc&action=showdarkroom&mobile=2',
          '当前在线': '/forum.php?showoldetails=yes&mobile=no#online',
          '电脑版': '/forum.php?mobile=no',
          '注册与邀请': '/member.php?mod=register&mobile=2',
        }.entries)
          ListTile(
            title: Text(entry.key),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              if (entry.key == '小黑屋') {
                await push(context, DarkroomPage(site));
              } else if (entry.key == '访问推广') {
                if (!site.loggedIn) await push(context, LoginPage(site));
                if (context.mounted && site.loggedIn)
                  await push(context, PromotionPage(site));
              } else {
                await openWeb(context, entry.value, title: entry.key);
              }
            },
          ),
      ],
    ),
  );
}
