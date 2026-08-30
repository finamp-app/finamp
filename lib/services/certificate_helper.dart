import 'dart:convert';
import 'dart:io';

import 'package:finamp/models/finamp_models.dart';
import 'package:path/path.dart' as p;
import 'package:xdg_directories/xdg_directories.dart';

class ClientCertificateHelper {
  Directory get certDir {
    final parentPath = (Platform.isLinux ? runtimeDir?.path : null) ?? Directory.systemTemp.path;
    return Directory(p.join(parentPath, "finamp"));
  }

  Future<(String, String)> extractClientCertificate(ClientCertificate certificate) async {
    final outputDir = certDir;
    await outputDir.create(recursive: true);
    final certPath = p.join(outputDir.path, 'finamp_client_cert.pem');
    final keyPath = p.join(outputDir.path, 'finamp_client_key.pem');

    // Extract certificate chain (no keys)
    await _openssl([
      'pkcs12',
      '-in',
      '-',
      '-out',
      certPath,
      '-clcerts',
      '-nokeys',
      '-passin',
      'pass:${certificate.password}',
    ], stdin: certificate.data);

    // Extract private key (unencrypted, no certs)
    await _openssl([
      'pkcs12',
      '-in',
      '-',
      '-out',
      keyPath,
      '-nocerts',
      '-nodes',
      '-passin',
      'pass:${certificate.password}',
    ], stdin: certificate.data);

    return (certPath, keyPath);
  }

  Future<void> _openssl(List<String> args, {required List<int> stdin}) async {
    final process = await Process.start('openssl', args);
    process.stdin.add(stdin);
    await process.stdin.close();
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final stderr = await process.stderr.transform(utf8.decoder).join();
      throw Exception('openssl failed (exit $exitCode): $stderr');
    }
  }

  Future<void> deleteClientCertificate() async {
    for (final name in ['finamp_client_cert.pem', 'finamp_client_key.pem']) {
      final f = File(p.join(certDir.path, name));
      if (await f.exists()) await f.delete();
    }
  }
}
