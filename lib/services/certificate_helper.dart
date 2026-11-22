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

    // Set permissions to prevent other users from reading the private keys
    for (final path in [certPath, keyPath]) {
      final file = File(path);
      if (!file.existsSync()) file.createSync();
      await Process.run('chmod', ['600', path]);
    }

    // Extract certificate chain (no keys)
    await _openssl(
      ['pkcs12', '-in', '-', '-out', certPath, '-clcerts', '-nokeys', '-passin', 'env:$_passwordEnvVar'],
      stdin: certificate.data,
      password: certificate.password,
    );

    // Extract private key (unencrypted, no certs)
    await _openssl(
      ['pkcs12', '-in', '-', '-out', keyPath, '-nocerts', '-nodes', '-passin', 'env:$_passwordEnvVar'],
      stdin: certificate.data,
      password: certificate.password,
    );

    return (certPath, keyPath);
  }

  /// Passing the password through the environment keeps it out of the process's command line,
  /// which other users can read via `/proc/<pid>/cmdline`.
  static const _passwordEnvVar = 'FINAMP_CERT_PASSWORD';

  Future<void> _openssl(List<String> args, {required List<int> stdin, required String password}) async {
    final process = await Process.start('openssl', args, environment: {_passwordEnvVar: password});
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
