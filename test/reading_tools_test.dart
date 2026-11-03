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
  int checks = 0;
  bool signed = false;
  Completer<void>? pendingCheck;
  String response = '签到成功';
  @override
  Future<Response<dynamic>> request(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? data,
    int redirects = 0,
  }) async {
    if (path == '/k_misign-sign.html') {
      checks++;
      await pendingCheck?.future;
      return Response(
        data:
            '<script>var discuz_uid="1";</script>'
            '<a id="signresult">${signed ? '已签到' : '签到'}</a>'
            '<input name="formhash" value="1234abcd">',
        requestOptions: RequestOptions(path: path),
      );
    }
    requests++;
    expect(query?['operation'], 'qiandao');
    expect(query?['mobile'], 2);
    if (response == '签到成功') signed = true;
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
    'automatic sign-in checks server status and only submits when unsigned',
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
      expect(site.signed, isFalse);
      site.response = '签到成功';
      await site.maybeAutoSignIn();
      await site.maybeAutoSignIn();
      expect(site.requests, 2);
      expect(site.checks, 3);
      site.uid = '2';
      site.signed = false;
      await site.maybeAutoSignIn();
      expect(site.requests, 3);
    },
  );
  test('automatic sign-in deduplicates checks and stops after account change or disable', () async {
    SharedPreferences.setMockInitialValues({'autoSignIn': true});
    final prefs = await SharedPreferences.getInstance();
    final site = SignSite(prefs)..uid = '1';
    site.pendingCheck = Completer<void>();
    final first = site.maybeAutoSignIn();
    final second = site.maybeAutoSignIn();
    expect(site.checks, 1);
    site.uid = '2';
    site.sessionEpoch++;
    site.pendingCheck!.complete();
    await Future.wait([first, second]);
    expect(site.requests, 0);
    site.pendingCheck = Completer<void>();
    final disabled = site.maybeAutoSignIn();
    await prefs.setBool('autoSignIn', false);
    site.pendingCheck!.complete();
    await disabled;
    expect(site.requests, 0);
  });
  test(
    'automatic sign-in submits once concurrently and releases failed checks',
    () async {
      SharedPreferences.setMockInitialValues({'autoSignIn': true});
      final site = SignSite(await SharedPreferences.getInstance())..uid = '1';
      site.pendingCheck = Completer<void>();
      final first = site.maybeAutoSignIn();
      final second = site.maybeAutoSignIn();
      site.pendingCheck!.complete();
      await Future.wait([first, second]);
      expect(site.checks, 1);
      expect(site.requests, 1);
      site.pendingCheck = Completer<void>();
      final failed = site.maybeAutoSignIn();
      final failure = expectLater(failed, throwsStateError);
      site.pendingCheck!.completeError(StateError('offline'));
      await failure;
      site.pendingCheck = null;
      await site.maybeAutoSignIn();
      expect(site.checks, 3);
      expect(site.requests, 1);
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
