import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/subway_models.dart';

class SubwayApiService {
  // ── API 키 설정 ──────────────────────────────────────────────────────────────
  // 실시간 도착: 서울교통공사 (https://data.seoul.go.kr)
  static const String _realtimeApiKey = '7a4555505767746538396c53637555';

  // 정적 시간표: 서울 열린데이터광장 (https://data.seoul.go.kr)
  static const String _timetableApiKey = '416d7254536774653131334f41454d51';
  // ─────────────────────────────────────────────────────────────────────────────

  /// 실시간 도착 정보 조회
  ///
  /// [stationName]: 역 이름 (예: "강남", "홍대입구")
  /// 반환값의 첫 번째 항목 = 현재 열차, 두 번째 항목 = 다음 열차
  static Future<List<ArrivalInfo>> fetchRealtimeArrival(
    String stationName,
  ) async {
    if (_realtimeApiKey == 'YOUR_REALTIME_API_KEY') {
      // API 키가 없을 때 더미 데이터 반환
      await Future.delayed(const Duration(milliseconds: 500));
      return [
        ArrivalInfo(
          currentTrainStatus: '당역 진입',
          destination: '종착역',
          trainLineName: '상행 - 다음역 방면',
          updnLine: '상행',
          subwayId: '1001',
          remainingSeconds: 30,
          arvlCd: 0,
        ),
        ArrivalInfo(
          currentTrainStatus: '2분 전역 출발',
          destination: '종착역',
          trainLineName: '하행 - 이전역 방면',
          updnLine: '하행',
          subwayId: '1001',
          remainingSeconds: 120,
          arvlCd: 3,
        ),
      ];
    }

    final uri = Uri.parse(
      'http://swopenapi.seoul.go.kr/api/subway/$_realtimeApiKey'
      '/json/realtimeStationArrival/1/10/$stationName',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('서버 오류: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final errorMsg = data['errorMessage'] as Map<String, dynamic>?;
    if (errorMsg != null) {
      final status =
          int.tryParse(errorMsg['status']?.toString() ?? '200') ?? 200;
      if (status != 200) {
        throw Exception(errorMsg['message'] as String? ?? '도착 정보 조회 실패');
      }
    }

    final list = (data['realtimeArrivalList'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>().map(ArrivalInfo.fromJson).toList();
  }

  /// 정적 시간표 조회
  static Future<List<TrainSchedule>> fetchTimetable(
    String stationCode, {
    int direction = 1,
    int? dayType,
  }) async {
    if (_timetableApiKey == 'YOUR_TIMETABLE_API_KEY') {
      // API 키가 없을 때 더미 데이터 반환
      await Future.delayed(const Duration(milliseconds: 500));
      return List.generate(20, (index) {
        final hour = (5 + index ~/ 4);
        final minute = (index % 4) * 15;
        final isExpress = index % 3 == 0;
        return TrainSchedule(
          time:
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
          destination: direction == 1 ? '인천/신창' : '의정부/광운대',
          type: isExpress ? '급행' : '일반',
          isExpress: isExpress,
        );
      });
    }

    final day = dayType ?? currentDayType();
    final uri = Uri.parse(
      'http://openapi.seoul.go.kr:8088/$_timetableApiKey'
      '/json/SearchSTNTimeTableByIDService/1/500'
      '/$stationCode/$day/$direction',
    );
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('서버 오류: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final service =
        data['SearchSTNTimeTableByIDService'] as Map<String, dynamic>?;

    // 데이터 자체가 없는 경우 (키가 누락된 경우 포함) 빈 리스트 반환
    if (service == null) {
      return [];
    }

    final result = service['RESULT'] as Map<String, dynamic>?;
    if (result != null && result['CODE'] != 'INFO-000') {
      if (result['CODE'] == 'INFO-200') {
        return [];
      }
      throw Exception(result['MESSAGE'] as String? ?? '시간표 조회 실패');
    }

    final rows = (service['row'] as List?) ?? [];
    return rows
        .cast<Map<String, dynamic>>()
        .map(TrainSchedule.fromJson)
        .toList();
  }

  /// 전체 지하철역 마스터 정보 조회 (페이지네이션으로 전체 수집)
  static Future<List<SubwayStation>> fetchAllStations() async {
    const int pageSize = 500;
    final List<SubwayStation> fetchedStations = [];
    final Set<String> seen = {};
    int start = 1;
    int pageNum = 1;

    debugPrint('[fetchAllStations] 시작');
    try {
      while (true) {
        final end = start + pageSize - 1;
        final uri = Uri.parse(
          'http://openapi.seoul.go.kr:8088/$_timetableApiKey'
          '/json/SearchSTNBySubwayLineInfo/$start/$end/',
        );

        debugPrint('[fetchAllStations] 페이지 $pageNum 요청: $start~$end');
        final response = await http.get(uri);
        debugPrint('[fetchAllStations] HTTP ${response.statusCode}');

        if (response.statusCode != 200) {
          debugPrint('[fetchAllStations] HTTP 오류로 중단');
          break;
        }

        final data = json.decode(response.body) as Map<String, dynamic>;
        final service =
            data['SearchSTNBySubwayLineInfo'] as Map<String, dynamic>?;
        if (service == null) {
          debugPrint(
            '[fetchAllStations] SearchSTNBySubwayLineService 키 없음 — 응답: ${response.body.substring(0, response.body.length.clamp(0, 200))}',
          );
          break;
        }

        final result = service['RESULT'] as Map<String, dynamic>?;
        final code = result?['CODE'] as String? ?? '';
        final message = result?['MESSAGE'] as String? ?? '';
        debugPrint('[fetchAllStations] RESULT CODE=$code MESSAGE=$message');

        if (code.isNotEmpty && code != 'INFO-000') {
          debugPrint('[fetchAllStations] 데이터 종료 (CODE=$code)');
          break;
        }

        final rows = (service['row'] as List?) ?? [];
        debugPrint('[fetchAllStations] 페이지 $pageNum: ${rows.length}행 수신');
        if (rows.isEmpty) break;

        // 첫 번째 행 샘플 출력으로 필드명 확인
        if (pageNum == 1 && rows.isNotEmpty) {
          debugPrint('[fetchAllStations] 첫 행 샘플: ${rows.first}');
        }

        for (var row in rows) {
          final name = row['STATION_NM'] as String? ?? '';
          final rawLine = row['LINE_NUM'] as String? ?? '';
          final code = row['STATION_CD'] as String? ?? '';

          if (name.isEmpty || code.isEmpty) continue;

          // API가 "01호선", "02호선" 형식으로 반환하는 경우 정규화
          final line = rawLine.replaceFirstMapped(
            RegExp(r'^0+(\d)'),
            (m) => m.group(1)!,
          );

          final key = '$name|$line';
          if (!seen.contains(key)) {
            seen.add(key);
            fetchedStations.add(
              SubwayStation(
                stationName: name,
                lineName: line,
                stationCode: code,
              ),
            );
          }
        }

        debugPrint('[fetchAllStations] 누적: ${fetchedStations.length}역');

        if (rows.length < pageSize) {
          debugPrint('[fetchAllStations] 마지막 페이지 도달');
          break;
        }
        start += pageSize;
        pageNum++;
      }

      fetchedStations.sort((a, b) => a.stationName.compareTo(b.stationName));
      debugPrint('[fetchAllStations] 완료: 총 ${fetchedStations.length}역');
      return fetchedStations;
    } catch (e, st) {
      debugPrint('[fetchAllStations] 예외: $e\n$st');
      return fetchedStations;
    }
  }

  static int currentDayType() {
    final weekday = DateTime.now().weekday;
    if (weekday == DateTime.saturday) return 2;
    if (weekday == DateTime.sunday) return 3;
    return 1;
  }
}
