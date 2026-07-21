import 'local_config.dart';

class SentryConfig {
  static const dsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: LocalConfig.sentryDsn,
  );

  static bool get isEnabled => dsn.isNotEmpty;
}
