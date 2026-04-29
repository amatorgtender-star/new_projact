import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/subway_models.dart';

class SubwayApiService {
  // ── API 키 설정 ──────────────────────────────────────────────────────────────
  // 실시간 도착: 서울교통공사 (https://data.seoul.go.kr)
  static const String _realtimeApiKey = '7a4555505767746538396c53637555';

  // 정적 시간표: 서울 열린데이터광장 (https://data.seoul.go.kr)
  static const String _seoulApiKey = '416d7254536774653131334f41454d51';

  // 시간표: 한국철도공사_열차운행정보 (https://www.data.go.kr/data/15143847/openapi.do)
  static const String _timetableApiKey =
      'd02d49a67b0c7b038d69ad5bf18ace33a87905b790fe5d0dca4f9de26562ba26';
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
      '/json/realtimeStationArrival/1/10/${Uri.encodeComponent(stationName)}',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('서버 오류: ${response.statusCode}');
    }

    dynamic data;
    try {
      data = json.decode(response.body);
    } catch (e) {
      debugPrint(
        'JSON 파싱 실패. 응답 내용: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
      );
      throw Exception('서버 응답 형식이 올바르지 않습니다 (JSON 아님)');
    }

    if (data is! Map<String, dynamic>) {
      throw Exception('서버 응답 형식이 올바르지 않습니다 (Map 아님)');
    }

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

  // 시간표
  static Future<List<TrainSchedule>> fetchTimetable(
    String lineName, // '경의선', '1호선' 등
    String stationCode, { // stnCd에 매핑
    int direction = 1, // 1: 상행, 2: 하행
    int? dayType, // 1: 평일, 2: 주말/공휴일
  }) async {
    // 1. 사용자 입력값을 API 규격 문자열로 변환
    final String dayStr = (dayType == 1) ? '평일' : '주말';
    final bool isLine2 = (lineName == '2호선');

    final String upDown = isLine2
        ? (direction == 1 ? '내선' : '외선') // 2호선: 1(내선), 2(외선)
        : (direction == 1 ? '상행' : '하행'); // 그 외: 1(상행), 2(하행)
    //
    String updatedLineName = switch (lineName) {
      '경의중앙선' => '경의선',
      '수인분당선' => '수인선',
      '신분당선' => '신분당',
      '공항철도' => '공항선',
      '우이신설경전철' => '우이신설선',
      '신림경전철' => '신림선',
      '의정부경전철' => '의정부선',
      '용인경전철' => '에버라인',
      '서해선' => '서해선', // 변환이 필요 없더라도 명시적으로 작성 가능
      _ => lineName, // 그 외 나머지 호선들 (1~9호선 등)
    };
    final Uri uri = Uri.https(
      'apis.data.go.kr',
      '/B553766/schedule/getTrainSch',
      {
        'serviceKey': _timetableApiKey, // 인코딩되지 않은 원본 키 사용 권장
        'pageNo': '1',
        'numOfRows': '500', // 하루치 시간표를 모두 가져오기 위해 넉넉히 설정
        'dataType': 'JSON',
        'lineNm': updatedLineName, // 변수화 완료
        'stnCd': stationCode, // 명세서의 stnCd와 매핑
        'upbdnbSe': upDown, // 필수: 상행/하행/내선/외선
        'wkndSe': dayStr, // 필수: 평일/주말/공휴일/상시
        'tmprTmtblYn': 'N', // 필수: 임시시간표 여부 (기본 N)
      },
    );

    try {
      final response = await http.get(uri);
      debugPrint(' fetchTimetable[uri]($uri)');
      debugPrint(' fetchTimetable ($response)');
      if (response.statusCode != 200) {
        throw Exception('네트워크 오류: ${response.statusCode}');
      }

      final Map<String, dynamic> decoded = json.decode(response.body);
      final responseData = decoded['response'];

      // 2. API 응답 헤더 및 바디 유효성 검사
      if (responseData == null) throw Exception('API 응답 구조가 올바르지 않습니다.');

      final header = responseData['header'];
      final body = responseData['body'];

      if (header != null && header['resultCode'] != '00') {
        throw Exception(
          'API 에러: [${header['resultCode']}] ${header['resultMsg']}',
        );
      }

      // 데이터가 없는 경우 (items가 빈 문자열 ""로 오는 경우 대응)
      if (body == null || body['items'] == null || body['items'] == '') {
        debugPrint('조회된 시간표 데이터가 없습니다 ($lineName, $stationCode)');
        return [];
      }

      final rawItem = body['items']['item'];

      // 3. 응답 데이터 타입 정규화 (Map인 경우 List로 변환)
      List<dynamic> itemList;
      if (rawItem is List) {
        itemList = rawItem;
      } else if (rawItem is Map) {
        itemList = [rawItem];
      } else {
        return [];
      }

      return itemList
          .map((e) => TrainSchedule.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('fetchTimetable 오류: $e');
      rethrow;
    }
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
          'http://openapi.seoul.go.kr:8088/$_seoulApiKey'
          '/json/SearchSTNBySubwayLineInfo/$start/$end/',
        );
        debugPrint('[fetchAllStations] $uri');
        debugPrint('[fetchAllStations] 페이지 $pageNum 요청: $start~$end');
        final response = await http.get(uri);
        debugPrint('[fetchAllStations] HTTP ${response.statusCode}');

        if (response.statusCode != 200) {
          debugPrint('[fetchAllStations] HTTP 오류로 중단');
          break;
        }

        final data = json.decode(response.body) as Map<String, dynamic>;
        final serviceKey = data.containsKey('SearchSTNBySubwayLineInfo')
            ? 'SearchSTNBySubwayLineInfo'
            : 'SearchSTNBySubwayLineService';

        final service = data[serviceKey] as Map<String, dynamic>?;
        if (service == null) {
          debugPrint(
            '[fetchAllStations] $serviceKey 키 없음 — 응답: ${response.body.substring(0, response.body.length.clamp(0, 200))}',
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
          String code = row['STATION_CD'] as String? ?? '';

          if (name.isEmpty || code.isEmpty) continue;

          // 역 코드 표준화 (4자리 패딩 - 시간표 API 필수 조건)
          if (code.length < 4 && RegExp(r'^\d+$').hasMatch(code)) {
            code = code.padLeft(4, '0');
          }

          // API가 "01호선", "02호선" 형식으로 반환하는 경우 정규화
          String line = rawLine.replaceFirstMapped(
            RegExp(r'^0+(\d)'),
            (m) => m.group(1)!,
          );

          // 노선명 표준화
          const lineNameMap = {
            '김포도시철도': '김포골드라인',
            '용인경전철': '에버라인',
            '우이신설경전철': '우이신설선',
            '인천선': '인천1호선',
            '경의선': '경의중앙선',
          };
          line = lineNameMap[line] ?? line;

          final key = '$name|$line';
          if (!seen.contains(key)) {
            seen.add(key);

            // [Timetable] 전국 지하철 시간표 동기화 완료
            debugPrint('[Timetable] 전국 지하철 시간표 동기화 완료: $name');

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
