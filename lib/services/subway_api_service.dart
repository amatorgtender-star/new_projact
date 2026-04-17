import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subway_models.dart';

class SubwayApiService {
  // ── API 키 설정 ──────────────────────────────────────────────────────────────
  // 실시간 도착: 서울교통공사 (https://data.seoul.go.kr)
  static const String _realtimeApiKey = 'YOUR_REALTIME_API_KEY';

  // 정적 시간표: 서울 열린데이터광장 (https://data.seoul.go.kr)
  static const String _timetableApiKey = 'YOUR_TIMETABLE_API_KEY';
  // ─────────────────────────────────────────────────────────────────────────────

  /// 실시간 도착 정보 조회
  ///
  /// [stationName]: 역 이름 (예: "강남", "홍대입구")
  /// 반환값의 첫 번째 항목 = 현재 열차, 두 번째 항목 = 다음 열차
  static Future<List<ArrivalInfo>> fetchRealtimeArrival(
    String stationName,
  ) async {
    final uri = Uri.parse(
      'http://swopenapi.seoul.go.kr/api/subway/$_realtimeApiKey'
      '/json/realtimeStationArrival/0/20/$stationName',
    );
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('서버 오류: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final errorMsg = data['errorMessage'] as Map<String, dynamic>?;
    if (errorMsg != null && errorMsg['status'] != 200) {
      throw Exception(errorMsg['message'] as String? ?? '도착 정보 조회 실패');
    }

    final list = (data['realtimeArrivalList'] as List?) ?? [];
    return list
        .cast<Map<String, dynamic>>()
        .map(ArrivalInfo.fromJson)
        .toList();
  }

  /// 정적 시간표 조회
  ///
  /// [stationCode]: 역코드 4자리 (예: "0222" = 강남 2호선)
  /// [direction]: 1 = 상행/내선, 2 = 하행/외선
  /// [dayType]: 1 = 평일, 2 = 토요일, 3 = 공휴일 (null 이면 오늘 자동 판단)
  static Future<List<TrainSchedule>> fetchTimetable(
    String stationCode, {
    int direction = 1,
    int? dayType,
  }) async {
    final day = dayType ?? _currentDayType();
    final uri = Uri.parse(
      'http://openapi.seoul.go.kr:8088/$_timetableApiKey'
      '/json/SearchSTNTimeTableByIDService/1/200'
      '/$stationCode/$direction/$day',
    );
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('서버 오류: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final service =
        data['SearchSTNTimeTableByIDService'] as Map<String, dynamic>?;
    if (service == null) throw Exception('시간표 데이터 없음');

    final result = service['RESULT'] as Map<String, dynamic>?;
    if (result != null && result['CODE'] != 'INFO-000') {
      throw Exception(result['MESSAGE'] as String? ?? '시간표 조회 실패');
    }

    final rows = (service['row'] as List?) ?? [];
    return rows.cast<Map<String, dynamic>>().map(TrainSchedule.fromJson).toList();
  }

  static int _currentDayType() {
    final weekday = DateTime.now().weekday;
    if (weekday == DateTime.saturday) return 2;
    if (weekday == DateTime.sunday) return 3;
    return 1;
  }
}
