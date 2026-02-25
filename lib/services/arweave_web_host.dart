import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ArweaveWebViewHost extends StatefulWidget {
  final void Function(InAppWebViewController controller) onReady;
  const ArweaveWebViewHost({super.key, required this.onReady});

  @override
  State<ArweaveWebViewHost> createState() => _ArweaveWebViewHostState();
}

class _ArweaveWebViewHostState extends State<ArweaveWebViewHost> {
  bool _readyFired = false;

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialFile: "assets/arweave_runner.html",
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
      ),
      onWebViewCreated: (controller) async {
        debugPrint('[arweave_host] onWebViewCreated');
      },
      onLoadStop: (controller, url) {
        debugPrint('[arweave_host] onLoadStop url=$url');
        if (!_readyFired) {
          _readyFired = true;
          widget.onReady(controller);
        }
      },
      onReceivedError: (controller, request, error) {
        debugPrint('[arweave_host] onReceivedError url=${request.url} error=$error');
      },
      onConsoleMessage: (controller, consoleMessage) {
        debugPrint('[arweave_host] console: ${consoleMessage.message}');
      },
    );
  }
}
