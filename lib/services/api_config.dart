// lib/services/api_config.dart
class ApiConfig {
  // 시간표 API용 (8088 포트 사용 서비스)
  static const String seoulApiKey = String.fromEnvironment(
    'SEOUL_API_KEY',
    defaultValue: 'none',
  );

  // 실시간 도착 정보 API용 (swopenapi 서비스)
  static const String subwayApiKey = String.fromEnvironment(
    'SUBWAY_API_KEY',
    defaultValue: 'none',
  );
}
