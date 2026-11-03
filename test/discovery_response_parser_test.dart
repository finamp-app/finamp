import 'dart:convert';

import 'package:finamp/services/discovery_response_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Discovery response validation', () {
    for (final payload in [
      'not-json',
      'null',
      '[]',
      '42',
      '{}',
      '{"Address":null}',
      '{"Address":42}',
      '{"Address":""}',
      '{"Address":"   "}',
      '{"Address":"/relative"}',
      '{"Address":"http://"}',
      '{"Address":"http://["}',
      '{"Address":"ftp://example.test"}',
      '{"Address":"http://example.test","Name":42}',
    ]) {
      test('ignores invalid response: $payload', () {
        expect(parseDiscoveryResponse(utf8.encode(payload)), isNull);
      });
    }

    test('ignores malformed UTF-8', () {
      expect(parseDiscoveryResponse([0xff, 0xfe]), isNull);
    });

    for (final address in ['http://192.0.2.10:8096', 'https://example.test/jellyfin', 'http://[2001:db8::1]:8096']) {
      test('preserves a usable server address: $address', () {
        final response = parseDiscoveryResponse(
          utf8.encode(
            jsonEncode({
              'Address': address,
              'Id': 'test-server',
              'Name': 'Test server',
              'EndpointAddress': address,
              'FutureField': true,
            }),
          ),
        );
        expect(response?.address, address);
        expect(response?.name, 'Test server');
        expect(response?.id, 'test-server');
      });
    }

    test('a malformed packet does not prevent parsing the next valid packet', () {
      expect(parseDiscoveryResponse(utf8.encode('not-json')), isNull);
      expect(
        parseDiscoveryResponse(utf8.encode('{"Address":"http://192.0.2.10:8096"}'))?.address,
        'http://192.0.2.10:8096',
      );
    });
  });
}
