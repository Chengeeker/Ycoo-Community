import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yuan_community/data/site.dart';
import 'package:yuan_community/pages/editor_tools.dart';
import 'package:yuan_community/pages/common.dart';

class SignSite extends Site {
  SignSite(super.prefs);
  int requests = 0;
  String response = '签到成功';
  @override
  Future<Response<dynamic>> request(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
    int redirects = 0,
  }) async {
    requests++;
    expect(query?['operation'], 'qiandao');
    return Response(
      data: response,
      requestOptions: RequestOptions(path: path),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native file selection is serial and releases its guard on cancellation',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final pending = Completer<List<String>?>();
      messenger.setMockMethodCallHandler(appActions, (_) => pending.future);
      try {
        final first = chooseUploadFile();
        await expectLater(chooseUploadFile(), throwsA(isA<SiteException>()));
        pending.complete(null);
        expect(await first, isNull);
        messenger.setMockMethodCallHandler(appActions, (_) async => null);
        expect(await chooseUploadFile(), isNull);
      } finally {
        messenger.setMockMethodCallHandler(appActions, null);
      }
    },
  );
  test('BBCode wraps selection and quick replies persist order', () async {
    final input = TextEditingController(text: '前内容后')
      ..selection = const TextSelection(baseOffset: 1, extentOffset: 3);
    applyReplyTool(input, defaultReplyTools.first);
    expect(input.text, '前[b]内容[/b]后');
    expect(
      input.selection,
      const TextSelection(baseOffset: 4, extentOffset: 6),
    );
    SharedPreferences.setMockInitialValues({
      'replyTools': '[{"title":"谢谢","placeholder":"感谢分享","custom":true},{"title":"加粗","before":"[b]","after":"[/b]"}]',
    });
    final tools = loadReplyTools(await SharedPreferences.getInstance());
    expect(tools.map((e) => e.title), ['谢谢', '加粗']);
    input.selection = TextSelection.collapsed(offset: input.text.length);
    applyReplyTool(input, tools.first);
    expect(input.text, endsWith('感谢分享'));
    input.dispose();
  });
  test(
    'automatic sign-in requires opt-in, account and confirmed daily result',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final site = SignSite(prefs)
        ..uid = '1'
        ..formhash = '1234abcd';
      await site.maybeAutoSignIn();
      expect(site.requests, 0);
      await prefs.setBool('autoSignIn', true);
      site.uid = '0';
      await site.maybeAutoSignIn();
      expect(site.requests, 0);
      site.uid = '1';
      site.response = '验证失败';
      await site.maybeAutoSignIn();
      expect(prefs.getString('signIn.1.date'), isNull);
      site.response = '签到成功';
      await site.maybeAutoSignIn();
      await site.maybeAutoSignIn();
      expect(site.requests, 2);
      site.uid = '2';
      await site.maybeAutoSignIn();
      expect(site.requests, 3);
    },
  );
  test(
    'download detection only accepts HTTP links without embedded credentials',
    () {
      expect(
        isDownloadUri(
          Uri.parse('https://ycoo.net/forum.php?mod=attachment&aid=1'),
        ),
        isTrue,
      );
      expect(isDownloadUri(Uri.parse('https://example.com/book.epub')), isTrue);
      expect(
        isDownloadUri(Uri.parse('https://user:pass@example.com/book.pdf')),
        isFalse,
      );
      expect(isDownloadUri(Uri.parse('file:///book.pdf')), isFalse);
      expect(
        isDownloadUri(Uri.parse('https://ycoo.net/thread-1-1-1.html')),
        isFalse,
      );
    },
  );
}
