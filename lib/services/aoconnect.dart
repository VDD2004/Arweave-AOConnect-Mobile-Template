import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class AOConnectJs {
  // ID of the deployed AO process. For this template, it's on the local-ran HB node
  // TODO specify your own PID
  static const String aoPID = "7xlHvKSESovkrexmUPXwQVPGqtjTdUT5FwCYUI8NY3I";
  // TODO specify your own HB URL (if needed)
  static const String hbUrl = "http://10.0.2.2:10000";
  // TODO specify your own operator ID
  static const String operatorId = "4OVMOIxzFXuZmN9ZZf2UMYVk4ddNZGDbJN2xnqG19NM";

  static InAppWebViewController? _controller;

  static Future<void> init(InAppWebViewController controller) async {
    _controller = controller;
  }

  static Future<Map<String, dynamic>> debugTest() async {
    final res = await _evalJson("""
      ({
        hasAOConnect: !!globalThis.AOConnect,
        aoConnectKeys: globalThis.AOConnect ? Object.keys(globalThis.AOConnect) : null,
        hasInstance: !!globalThis.aoInstance
      })
    """);
    debugPrint(res.toString());
    return res;
  }

  static Future<void> connect({
    required Map<String, dynamic> jwk,
    String? hbUrl,
    String? operatorId,
  }) async {
    final jwkJson = jsonEncode(jwk);
    final hbUrlJson = jsonEncode(hbUrl ?? AOConnectJs.hbUrl);
    final operatorJson = jsonEncode(operatorId ?? AOConnectJs.operatorId);

    await _callValue("""
      (async () => {
        await AOConnect.connect($jwkJson, $hbUrlJson, $operatorJson);
        return { connected: true };
      })()
    """);
  }

  static Future<dynamic> spawn({
    String data = "",
    Map<String, dynamic>? jwk,
    String? hbUrl,
    String? operatorId,
  }) async {
    final payload = <String, dynamic>{
      'data': data,
      'jwk': jwk,
      'hbUrl': hbUrl,
      'operator': operatorId,
    }..removeWhere((_, v) => v == null);

    return _callValue("AOConnect.spawn(${jsonEncode(payload)})");
  }

  static Future<dynamic> message({
    String process = aoPID,
    List<Map<String, String>> tags = const [],
    String data = "",
    Map<String, dynamic>? jwk,
    String? hbUrl,
    String? operatorId,
  }) async {
    final payload = <String, dynamic>{
      'process': process,
      'tags': tags,
      'data': data,
      'jwk': jwk,
      'hbUrl': hbUrl,
      'operator': operatorId,
    }..removeWhere((_, v) => v == null);

    return _callValue("AOConnect.message(${jsonEncode(payload)})");
  }

  static Future<dynamic> result({
    String process = aoPID,
    required String message,
    Map<String, dynamic>? jwk,
    String? hbUrl,
    String? operatorId,
  }) async {
    final payload = <String, dynamic>{
      'process': process,
      'message': message,
      'jwk': jwk,
      'hbUrl': hbUrl,
      'operator': operatorId,
    }..removeWhere((_, v) => v == null);

    return _callValue("AOConnect.result(${jsonEncode(payload)})");
  }

  static Future<dynamic> _callValue(String jsExpr) async {
    final res = await _evalJson(jsExpr);
    if (res['ok'] == true) return res['value'];

    throw StateError(
      "AOConnect JS error: ${res['error'] ?? 'Unknown error'}",
    );
  }

  static Future<Map<String, dynamic>> _evalJson(String jsExpr) async {
    final controller = _controller;
    if (controller == null) {
      throw StateError("AOConnectJs not initialized");
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
      throw StateError("JS returned null (page not ready or result not serializable)");
    }

    if (v is String) {
      return Map<String, dynamic>.from(jsonDecode(v) as Map);
    }

    return Map<String, dynamic>.from(v as Map);
  }
}
