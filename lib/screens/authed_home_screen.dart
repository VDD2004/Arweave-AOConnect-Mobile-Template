import 'package:arweave_aoconnect_mobile_template/services/aoconnect.dart';
import 'package:flutter/material.dart';

import '../router.dart';
import '../shared_components/shared.dart';

class AuthedHomeScreen extends StatefulWidget {
  const AuthedHomeScreen({super.key});

  @override
  State<AuthedHomeScreen> createState() => _AuthedHomeScreenState();
}

class _AuthedHomeScreenState extends State<AuthedHomeScreen> {
  bool _isAwaitingResponse = false;
  String? _resultText;
  bool _resultIsError = false;

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: 'You Are Authenticated!',
      currentRoute: AppRoutes.home,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Authenticated',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _isAwaitingResponse
                        ? null
                        : () async {
                            setState(() {
                              _isAwaitingResponse = true;
                              _resultText = null;
                              _resultIsError = false;
                            });

                            try {
                              final messageId = await AOConnectJs.message(
                                tags: [
                                  {"name": "Action", "value": "Ping"},
                                ],
                              );
                              debugPrint("Message sent, ID: $messageId");
                              final result = await AOConnectJs.result(
                                message: '$messageId',
                              );
                              debugPrint("Result: $result");

                              if (!mounted) {
                                return;
                              }

                              setState(() {
                                _resultText = result.toString();
                                _resultIsError = false;
                              });
                            } catch (e) {
                              debugPrint("Error sending message: $e");
                              if (!mounted) {
                                return;
                              }
                              setState(() {
                                _resultText = "Error sending message: $e";
                                _resultIsError = true;
                              });
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isAwaitingResponse = false;
                                });
                              }
                            }
                          },
                    icon: _isAwaitingResponse
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _isAwaitingResponse
                          ? 'Awaiting AO response...'
                          : 'Message AO Process',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _resultIsError
                            ? Theme.of(context).colorScheme.errorContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _resultIsError
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _resultText ?? 'Result will appear here',
                          style: TextStyle(
                            color: _resultIsError
                                ? Theme.of(context).colorScheme.onErrorContainer
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
