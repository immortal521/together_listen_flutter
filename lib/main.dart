import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});
  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  WebViewController? controller;
  var loadingPercentage = 0;
  var hasError = false;
  var _canGoBack = false;

  @override
  void initState() {
    super.initState();

    // 仅在 Android 和 iOS 平台初始化 WebViewController
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final params = PlatformWebViewControllerCreationParams();
      controller = WebViewController.fromPlatformCreationParams(params)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              setState(() {
                hasError = false;
                loadingPercentage = 0;
              });
            },
            onProgress: (progress) {
              setState(() {
                loadingPercentage = progress;
              });
            },
            onPageFinished: (url) async {
              setState(() => loadingPercentage = 100);
              _canGoBack = await controller!.canGoBack();
            },
            onWebResourceError: (error) =>
                setState(() => hasError = true),
            onNavigationRequest: (request) {
              // 如果是在 Web 平台，就在浏览器中打开链接
              if (kIsWeb) {
                launchUrl(Uri.parse(request.url));
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..enableZoom(false)
        ..loadRequest(Uri.parse('https://immort.top'));

      // 针对 Android 单独配置
      if (controller!.platform is AndroidWebViewController) {
        (controller!.platform as AndroidWebViewController)
          ..setBackgroundColor(const Color(0x00000000));
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (controller != null && _canGoBack && !kIsWeb) {
      controller!.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // 如果当前平台不是 Android 或 iOS，则显示提示页面
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return Scaffold(
        appBar: AppBar(title: const Text('提示')),
        body: const Center(
          child: Text(
            '当前平台不支持 WebView 功能。\n请使用 Android 或 iOS 设备运行应用。',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Android 和 iOS 平台则显示 WebView 页面
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('网页浏览'),
      flexibleSpace: const SafeArea(child: SizedBox.shrink()),
      actions: [
        if (hasError)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller?.reload(),
          ),
      ],
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: WebViewWidget(controller: controller!),
          ),
        ),
        if (hasError)
          Positioned.fill(
            child: Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 50),
                    SizedBox(height: 16),
                    Text('加载失败，请检查网络连接'),
                  ],
                ),
              ),
            ),
          ),
        if (loadingPercentage < 100)
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: loadingPercentage / 100,
              backgroundColor: Colors.grey[200],
              minHeight: 3,
              color: Colors.blue,
            ),
          ),
      ],
    );
  }
}
