import 'dart:async';
import 'dart:isolate';

import 'package:chopper/chopper.dart';
import 'package:finamp/services/chopper_aggregate_logger.dart';
import 'package:finamp/services/performance_benchmark_service.dart';

final aggregateLogger = ChopperAggregateLogger();

/// A HttpLoggingInterceptor that aggregates the request and
/// response logs from Chopper, using the [ChopperAggregateLogger].
class BenchmarkHttpMetricRelay {
  SendPort? sendPort;

  void send(Map<String, Object?> value) {
    sendPort?.send(value);
  }
}

class HttpAggregateLoggingInterceptor extends HttpLoggingInterceptor {
  HttpAggregateLoggingInterceptor({super.level = Level.body, this.benchmarkRelay}) : super(logger: aggregateLogger);

  final BenchmarkHttpMetricRelay? benchmarkRelay;

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) async {
    aggregateLogger.onStartRequest(chain.request);
    final benchmark = PerformanceBenchmarkService.instance;
    if (PerformanceBenchmarkService.enabled && benchmarkRelay?.sendPort != null) {
      benchmarkRelay!.send(const <String, Object?>{"type": "start"});
    } else {
      benchmark.networkRequestStarted();
    }
    final stopwatch = Stopwatch()..start();
    int? responseBytes;
    int? statusCode;
    try {
      final Response<BodyType> response = await super.intercept(HttpAggregateLoggingChain(chain));
      responseBytes = int.tryParse(response.base.headers["content-length"] ?? "");
      statusCode = response.statusCode;
      // Request info isn't printed until after response completes
      aggregateLogger.onEndRequest(chain.request);
      aggregateLogger.onEndResponse(response);
      return response;
    } finally {
      stopwatch.stop();
      if (PerformanceBenchmarkService.enabled && benchmarkRelay?.sendPort != null) {
        benchmarkRelay!.send(<String, Object?>{
          "type": "complete",
          "responseBytes": responseBytes,
          "durationMicros": stopwatch.elapsedMicroseconds,
          "statusCode": statusCode,
        });
      } else {
        benchmark.networkRequestCompleted(
          responseBytes: responseBytes,
          durationMicros: stopwatch.elapsedMicroseconds,
          statusCode: statusCode,
        );
      }
    }
  }
}

class HttpAggregateLoggingChain<T> implements Chain<T> {
  HttpAggregateLoggingChain(this._chain);

  final Chain<T> _chain;

  @override
  FutureOr<Response<T>> proceed(Request request) async {
    var response = await _chain.proceed(request);
    aggregateLogger.onStartResponse(response);
    return response;
  }

  @override
  Request get request => _chain.request;
}
