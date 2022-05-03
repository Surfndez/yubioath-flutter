import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

class Levels {
  /// Key for tracing information ([value] = 500).
  static const Level TRAFFIC = Level('TRAFFIC', 500);

  /// Key for static configuration messages ([value] = 700).
  static const Level DEBUG = Level('DEBUG', 700);

  /// Key for informational messages ([value] = 800).
  static const Level INFO = Level.INFO;

  /// Key for potential problems ([value] = 900).
  static const Level WARNING = Level.WARNING;

  /// Key for serious failures ([value] = 1000).
  static const Level ERROR = Level('ERROR', 1000);

  static const List<Level> LEVELS = [
    TRAFFIC,
    DEBUG,
    INFO,
    WARNING,
    ERROR,
  ];
}

extension LoggerExt on Logger {
  void error(Object? message, [Object? error, StackTrace? stackTrace]) =>
      log(Levels.ERROR, message, error, stackTrace);
  void debug(Object? message, [Object? error, StackTrace? stackTrace]) =>
      log(Levels.DEBUG, message, error, stackTrace);
  void traffic(Object? message, [Object? error, StackTrace? stackTrace]) =>
      log(Levels.TRAFFIC, message, error, stackTrace);
}

final logLevelProvider =
    StateNotifierProvider<LogLevelNotifier, Level>((ref) => LogLevelNotifier());

class LogLevelNotifier extends StateNotifier<Level> {
  final List<String> _buffer = [];
  LogLevelNotifier() : super(Logger.root.level) {
    Logger.root.onRecord.listen((record) {
      _buffer.add('[${record.loggerName}] ${record.level}: ${record.message}');
      if (record.error != null) {
        _buffer.add('${record.error}');
      }
      while (_buffer.length > 1000) {
        _buffer.removeAt(0);
      }
    });
  }

  void setLogLevel(Level level) {
    state = level;
    Logger.root.level = level;
  }

  List<String> getLogs() {
    return List.unmodifiable(_buffer);
  }
}

class LogWarningOverlay extends StatelessWidget {
  final Widget child;

  const LogWarningOverlay({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        child,
        Consumer(builder: (context, ref, _) {
          if (ref.watch(logLevelProvider
              .select((level) => level.value <= Level.CONFIG.value))) {
            return const Align(
              alignment: Alignment.bottomCenter,
              child: IgnorePointer(
                child: Text(
                  'WARNING: Potentially sensitive data is being logged!',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }
          return const SizedBox();
        }),
      ],
    );
  }
}
