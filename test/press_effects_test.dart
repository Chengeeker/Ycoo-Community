import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/core/theme/app_theme.dart';
import 'package:yuan_community/core/widgets/review_gallery_glass_button.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/pages/home.dart';

Future<Uint8List> pixels(WidgetTester tester, GlobalKey key) async {
  final bytes = await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'custom-color topic and gallery buttons also suppress press ink, dark=$dark',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final site = Site(await SharedPreferences.getInstance());
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
            home: Scaffold(
              body: Column(
                children: [
                  TopicTile(
                    site,
                    const Topic(id: '1', title: 'post', uid: '2', likes: '3'),
                  ),
                  ReviewGalleryGlassIconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '关闭',
                    onPressed: () {},
                    opacity: 1,
                    opacityKey: const ValueKey('press-icon'),
                    useLiquidGlass: false,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OutlinedButton>(find.byType(OutlinedButton))
              .style!
              .overlayColor!
              .resolve({WidgetState.pressed}),
          Colors.transparent,
        );
        expect(
          tester
              .widget<TextButton>(
                find.widgetWithIcon(TextButton, Icons.thumb_up_outlined),
              )
              .style!
              .overlayColor!
              .resolve({WidgetState.pressed}),
          Colors.transparent,
        );
        final galleryButton = find.descendant(
          of: find.byType(ReviewGalleryGlassIconButton),
          matching: find.byType(IconButton),
        );
        expect(
          tester.widget<IconButton>(galleryButton).style!.overlayColor!.resolve(
            {WidgetState.pressed},
          ),
          Colors.transparent,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('tap and long press paint no ink, dark=$dark', (tester) async {
      final theme = dark ? AppTheme.darkTheme() : AppTheme.lightTheme();
      for (final control in <Widget>[
        InkWell(
          onTap: () {},
          onLongPress: () {},
          child: const Padding(padding: EdgeInsets.all(16), child: Text('按键')),
        ),
        TextButton(
          onPressed: () {},
          onLongPress: () {},
          child: const Text('按键'),
        ),
        IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined)),
      ]) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: Material(
                    color: theme.colorScheme.surface,
                    child: SizedBox(
                      width: 200,
                      height: 80,
                      child: Center(child: control),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final before = await pixels(tester, key);
        final gesture = await tester.startGesture(
          tester.getCenter(find.byWidget(control)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          listEquals(before, await pixels(tester, key)),
          isTrue,
          reason: '${control.runtimeType} tap overlay',
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          listEquals(before, await pixels(tester, key)),
          isTrue,
          reason: '${control.runtimeType} long-press overlay',
        );
        await gesture.cancel();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('keyboard focus remains visible, dark=$dark', (tester) async {
      final theme = dark ? AppTheme.darkTheme() : AppTheme.lightTheme();
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: Material(
                  color: theme.colorScheme.surface,
                  child: SizedBox(
                    width: 200,
                    height: 80,
                    child: Center(
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('键盘焦点'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = await pixels(tester, key);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(listEquals(before, await pixels(tester, key)), isFalse);
      expect(
        theme.switchTheme.overlayColor!.resolve({WidgetState.pressed}),
        Colors.transparent,
      );
      expect(
        theme.radioTheme.overlayColor!.resolve({WidgetState.pressed}),
        Colors.transparent,
      );
      expect(
        theme.checkboxTheme.overlayColor!.resolve({WidgetState.pressed}),
        Colors.transparent,
      );
      expect(
        theme.tabBarTheme.overlayColor!.resolve({WidgetState.pressed}),
        Colors.transparent,
      );
      expect(
        theme.navigationBarTheme.overlayColor!.resolve({WidgetState.pressed}),
        Colors.transparent,
      );
      expect(
        WidgetStateProperty.resolveAs(theme.sliderTheme.overlayColor, {
          WidgetState.dragged,
        }),
        Colors.transparent,
      );
      expect(
        WidgetStateProperty.resolveAs(theme.sliderTheme.overlayColor, {
          WidgetState.focused,
        }),
        isNot(Colors.transparent),
      );
    });
  }
}
