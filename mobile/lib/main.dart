import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile/mobile.dart';

void main() {
  runApp(const WhmMobileApp());
}

class WhmMobileApp extends StatelessWidget {
  const WhmMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: clientName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F6A8A)),
      ),
      home: const ServerConnectPage(),
    );
  }
}

class ServerConnectPage extends StatefulWidget {
  const ServerConnectPage({super.key});

  @override
  State<ServerConnectPage> createState() => _ServerConnectPageState();
}

class _ServerConnectPageState extends State<ServerConnectPage> {
  final _controller = TextEditingController(text: 'http://localhost:5173');
  bool _isConnecting = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      final serverUrl = normalizeServerUrl(_controller.text);
      final serverInfo = await fetchServerInfo(serverUrl);
      final compatibility = checkServerCompatibility(serverInfo);

      if (!compatibility.isCompatible) {
        setState(() {
          _statusMessage = compatibility.message;
          _isError = true;
          _isConnecting = false;
        });
        return;
      }

      setState(() {
        _statusMessage =
            'Connected to ${serverInfo.name} ${serverInfo.version} '
            '(server API ${serverInfo.apiVersion}, client API $clientApiVersion).';
        _isError = false;
        _isConnecting = false;
      });
    } on FormatException catch (error) {
      setState(() {
        _statusMessage = error.message;
        _isError = true;
        _isConnecting = false;
      });
    } on HttpException {
      setState(() {
        _statusMessage =
            'The server responded unexpectedly. Verify the WHM server URL and that the server is running.';
        _isError = true;
        _isConnecting = false;
      });
    } on SocketException {
      setState(() {
        _statusMessage =
            'Could not connect to the server. Check the server URL, network access, and that the WHM server is reachable.';
        _isError = true;
        _isConnecting = false;
      });
    } on TimeoutException {
      setState(() {
        _statusMessage =
            'Connection timed out after ${serverConnectionTimeout.inSeconds}s. Check the server URL and network access.';
        _isError = true;
        _isConnecting = false;
      });
    } catch (error) {
      setState(() {
        _statusMessage = 'Unexpected error: $error';
        _isError = true;
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WHM Mobile'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Connect to server', style: textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the WHM server URL to validate compatibility before loading project data.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'http://localhost:5173',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isConnecting ? null : _connect,
                      child: _isConnecting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Connect'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Client version $clientVersion • API $clientApiVersion',
                    style: textTheme.bodySmall,
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isError
                            ? const Color(0xFFFFF1F0)
                            : const Color(0xFFF1F8F4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isError
                              ? const Color(0xFFE6A4A0)
                              : const Color(0xFF9AC8AB),
                        ),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: _isError ? const Color(0xFF7A1F17) : const Color(0xFF1F5C38),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
