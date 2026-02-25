// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:arweave_aoconnect_mobile_template/services/arweavejs.dart';
import 'package:arweave_aoconnect_mobile_template/services/wallet_vault.dart';
import 'package:flutter/material.dart';
import 'package:arweave_aoconnect_mobile_template/services/aoconnect.dart';

void showSnackBar(BuildContext context, String message, {Duration? duration}) {
  if (duration == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message))
    );
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
    ),
  );
}

Future<String?> generateAndStoreWallet(BuildContext context, String pw, {WalletVault? vault}) async {
  if (pw.isEmpty) {
    showSnackBar(context, 'Please enter a password.');
    return null;
  }

  showSnackBar(context, 'Generating wallet...');

  final wallet = await ArweaveJs.generateWallet();
  if (wallet['ok'] != true) {
    showSnackBar(context, 'Failed to generate wallet.');
    return null;
  } else {
    showSnackBar(context, 'Wallet generated successfully!');
  }

  vault ??= WalletVault();
  final String jwkJson = jsonEncode(wallet['value']['jwk']);
  final String encryptedJwk = await vault.encryptJwkToExportString(
    password: pw,
    jwkJson: jwkJson,
  );

  await vault.saveExportString(encryptedJwk);
  await vault.savePassword(pw);

  // Immediately hydrate authenticated session state for the app
  final bool authenticated = await vault.attemptLogin(
    encryptedJwk: encryptedJwk,
    password: pw,
  );

  if (!authenticated) {
    await vault.deleteExportString();
    WalletVault.jwk = null;
    showSnackBar(context, 'Wallet saved, but authentication failed.');
    return null;
  }

  // Ensure AO is connected right after account creation so message/spawn calls work
  try {
    await AOConnectJs.connect(jwk: WalletVault.jwk!);
  } catch (e) {
    showSnackBar(context, 'Wallet created, but AO connect failed: $e');
    return null;
  }

  showSnackBar(context, 'Wallet encrypted, stored, authenticated, and AO connected.');
  return encryptedJwk;
}

/// Connect and cache AO instance in JS bridge.
Future<bool> connectAO(
  BuildContext context, {
  required Map<String, dynamic> jwk,
  required String hbUrl,
  required String scheduler,
}) async {
  try {
    await AOConnectJs.connect(jwk: jwk, hbUrl: hbUrl, operatorId: scheduler);
    showSnackBar(context, 'AO connected.');
    return true;
  } catch (e) {
    showSnackBar(context, 'AO connect failed: $e');
    return false;
  }
}

/// Spawn process via AO bridge.
/// Returns message/process response object from JS, or null on failure.
Future<dynamic> spawnAOProcess(
  BuildContext context, {
  String data = "",
  Map<String, dynamic>? jwk,
  String? hbUrl,
  String? scheduler,
}) async {
  try {
    final res = await AOConnectJs.spawn(
      data: data,
      jwk: jwk,
      hbUrl: hbUrl,
      operatorId: scheduler,
    );
    showSnackBar(context, 'AO spawn sent.');
    return res;
  } catch (e) {
    showSnackBar(context, 'AO spawn failed: $e');
    return null;
  }
}

/// Send message to AO process.
/// Returns AO response object, or null on failure.
Future<dynamic> messageAOProcess(
  BuildContext context, {
  required String process,
  List<Map<String, String>> tags = const [],
  String data = "",
  Map<String, dynamic>? jwk,
  String? hbUrl,
  String? scheduler,
}) async {
  try {
    final res = await AOConnectJs.message(
      process: process,
      tags: tags,
      data: data,
      jwk: jwk,
      hbUrl: hbUrl,
      operatorId: scheduler,
    );
    showSnackBar(context, 'AO message sent.');
    return res;
  } catch (e) {
    showSnackBar(context, 'AO message failed: $e');
    return null;
  }
}

/// Fetch result for AO message id.
/// Returns AO result object, or null on failure.
Future<dynamic> getAOProcessResult(
  BuildContext context, {
  required String process,
  required String messageId,
  Map<String, dynamic>? jwk,
  String? hbUrl,
  String? scheduler,
}) async {
  try {
    final res = await AOConnectJs.result(
      process: process,
      message: messageId,
      jwk: jwk,
      hbUrl: hbUrl,
      operatorId: scheduler,
    );
    return res;
  } catch (e) {
    showSnackBar(context, 'AO result failed: $e');
    return null;
  }
}