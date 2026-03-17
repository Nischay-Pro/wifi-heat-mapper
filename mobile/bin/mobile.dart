import 'dart:io';

import 'package:mobile/mobile.dart';

Future<void> main(List<String> arguments) async {
  final serverUrl =
      arguments.isNotEmpty ? normalizeServerUrl(arguments.first) : await promptForServerUrl();

  stdout.writeln('Connecting to $serverUrl');

  try {
    final serverInfo = await fetchServerInfo(serverUrl);
    final compatibility = checkServerCompatibility(serverInfo);

    if (!compatibility.isCompatible) {
      stderr.writeln(compatibility.message);
      exitCode = 1;
      return;
    }

    stdout.writeln(
      'Connected to ${serverInfo.name} ${serverInfo.version} '
      '(server API ${serverInfo.apiVersion}, client API $clientApiVersion).',
    );
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on HttpException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on SocketException catch (error) {
    stderr.writeln('Could not reach server: ${error.message}');
    exitCode = 1;
  } catch (error) {
    stderr.writeln('Unexpected error: $error');
    exitCode = 1;
  }
}
