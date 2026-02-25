import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ArweaveJs {
  static InAppWebViewController? _controller;

  static Future<void> init(InAppWebViewController controller) async {
    _controller = controller;
  }

  static Future debugTest() async {
    final res = await _evalJson("""
      ({
        hasBridge: !!globalThis.ArweaveBridge,
        bridgeKeys: globalThis.ArweaveBridge ? Object.keys(globalThis.ArweaveBridge) : null
      })
    """);
    debugPrint(res.toString());
    return res;
  }

  static Future<Map<String, dynamic>> generateWallet() async {
    final res = await _evalJson("ArweaveBridge.generateWallet()");
    return res;
  }

  static Future<String> getAddress(Map<String, dynamic> jwk) async {
    final jwkJson = jsonEncode(jwk);
    final res = await _evalJson("ArweaveBridge.getAddress($jwkJson)");
    return res['value']["address"] as String;
  }

  /// messageBytes should be the exact bytes you intend to sign for auth
  static Future<String> sign({
    required Map<String, dynamic> jwk,
    required List<int> messageBytes,
  }) async {
    final jwkJson = jsonEncode(jwk);
    final msgB64Url = _toBase64Url(messageBytes);
    final res = await _evalJson("ArweaveBridge.sign($jwkJson, '$msgB64Url')");
    return res['value']["signatureB64Url"] as String;
  }

  static Future<Map<String, dynamic>> _evalJson(String jsExpr) async {
    final controller = _controller;
    if (controller == null) {
      throw StateError("ArweaveJs not initialized");
    }

    final result = await controller.callAsyncJavaScript(
      functionBody: """
        return (async () => {
          try {
            const value = await ($jsExpr);
            return { ok: true, value: (value ?? null) };
          } catch (e) {
            return { ok: false, error: String(e), stack: e?.stack ?? null };
          }
        })();
      """,
    );

    final v = result?.value;
    if (v == null) {
      // Usually means the JS context isn't ready / page not loaded / JS disabled.
      throw StateError("JS returned null (page not ready or result not serializable)");
    }

    // callAsyncJavaScript may already decode; keep a fallback for string payloads.
    if (v is String) {
      return Map<String, dynamic>.from(jsonDecode(v) as Map);
    }
    return Map<String, dynamic>.from(v as Map);
  }

  static String _toBase64Url(List<int> bytes) {
    final b64 = base64Encode(bytes);
    return b64.replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
  }
}
