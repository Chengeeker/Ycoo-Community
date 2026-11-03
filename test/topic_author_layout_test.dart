import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/core/theme/app_theme.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/pages/home.dart';

void main() {
  for (final width in [320.0, 360.0, 393.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('author baselines and avatar align at $width / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final site = Site(await SharedPreferences.getInstance());
        final name = scale == 2 ? '这是一个很长的用户名称' : 'zlinlang';
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme(fontWeightAdjustment: 100),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: TopicTile(
                  site,
                  Topic(
                    id: '1',
                    uid: '16966',
                    author: name,
                    title: '示例帖子',
                    time: '20 分钟前',
                    level: 'Lv.3',
                    gender: 'male',
                    verificationIcon: 'https://example.invalid/verify.png',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final avatar = tester.getRect(
          find.byKey(const ValueKey('topic-avatar-1')),
        );
        final author = tester.getRect(
          find.byKey(const ValueKey('topic-author-block-1')),
        );
        final follow = tester.getRect(
          find.widgetWithText(OutlinedButton, '关注'),
        );
        final user = tester.getRect(find.text(name));
        final level = tester.getRect(find.text('Lv.3'));
        final time = tester.getRect(find.text('20 分钟前'));
        double baseline(Finder finder) {
          final box = tester.renderObject<RenderBox>(finder);
          return box
              .localToGlobal(
                Offset(
                  0,
                  box.getDryBaseline(
                    BoxConstraints.tight(box.size),
                    TextBaseline.alphabetic,
                  )!,
                ),
              )
              .dy;
        }

        expect(avatar.center.dy, closeTo(author.center.dy, .1));
        expect(follow.center.dy, closeTo(author.center.dy, .1));
        expect(
          baseline(find.text(name)),
          closeTo(baseline(find.text('Lv.3')), .1),
        );
        expect(time.left, closeTo(user.left, .1));
        expect(time.top, greaterThanOrEqualTo(user.bottom));
        expect(time.top, greaterThanOrEqualTo(level.bottom));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
