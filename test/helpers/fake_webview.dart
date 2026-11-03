import 'package:flutter/material.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
// The installed WebView plugin provides these interfaces for platform fakes.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class FakeWebViewPlatform extends WebViewPlatform {
  late FakeWebViewController controller;
  late FakeNavigationDelegate delegate;
  PlatformWebViewWidgetCreationParams? widgetParams;
  int widgetsCreated = 0;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = FakeWebViewController(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    widgetParams = params;
    widgetsCreated++;
    return _WebViewWidget(params);
  }
}

class FakeWebViewController extends PlatformWebViewController
    implements AndroidWebViewController {
  FakeWebViewController(super.params) : super.implementation();
  final loads = <Uri>[];
  int reloads = 0;

  @override
  Future<void> loadRequest(LoadRequestParams params) async =>
      loads.add(params.uri);
  @override
  Future<void> reload() async => reloads++;
  @override
  Future<String?> getTitle() async => '官网页面';
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setUserAgent(String? value) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate value,
  ) async {}
  @override
  Future<void> setOnShowFileSelector(
    Future<List<String>> Function(FileSelectorParams)? callback,
  ) async {}
  @override
  Future<void> setOnJavaScriptAlertDialog(
    Future<void> Function(JavaScriptAlertDialogRequest) callback,
  ) async {}
  @override
  Future<void> setOnJavaScriptConfirmDialog(
    Future<bool> Function(JavaScriptConfirmDialogRequest) callback,
  ) async {}
  @override
  Future<void> setOnJavaScriptTextInputDialog(
    Future<String> Function(JavaScriptTextInputDialogRequest) callback,
  ) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();
  late ProgressCallback progress;
  late PageEventCallback finished;
  late WebResourceErrorCallback error;
  late NavigationRequestCallback navigate;

  @override
  Future<void> setOnProgress(ProgressCallback callback) async =>
      progress = callback;
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async =>
      finished = callback;
  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {}
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async =>
      error = callback;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async => navigate = callback;
}

class _WebViewWidget extends PlatformWebViewWidget {
  _WebViewWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
