import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/theme.dart';

class PrivacyWebScreen extends StatefulWidget {
  const PrivacyWebScreen({super.key});

  @override
  State<PrivacyWebScreen> createState() => _PrivacyWebScreenState();
}

class _PrivacyWebScreenState extends State<PrivacyWebScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse('https://leadmantracrm.com/privacy-policy'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(color: AppTheme.accent, height: 3),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
