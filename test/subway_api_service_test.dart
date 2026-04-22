import 'package:flutter_test/flutter_test.dart';
import 'package:new_projact/models/subway_models.dart';
import 'package:new_projact/services/subway_api_service.dart';

void main() {
  group('ArrivalInfo.fromJson', () {
    test('정상 JSON 파싱', () {
      final info = ArrivalInfo.fromJson({
        'arvlMsg2': '2분 30초 후',
        'arvlMsg3': '전역 출발',
        'bstatnNm': '당산',
        'trainLineNm': '2호선 당산행',
        'updnLine': '상행',
        'barvlDt': '150',
        'arvlCd': '3',
      });

      expect(info.currentTrainStatus, '2분 30초 후');
      expect(info.positionDetail, '전역 출발');
      expect(info.destination, '당산');
      expect(info.updnLine, '상행');
      expect(info.remainingSeconds, 150);
      expect(info.arvlCd, 3);
    });

    test('누락 필드 기본값 처리', () {
      final info = ArrivalInfo.fromJson({});

      expect(info.currentTrainStatus, '정보 없음');
      expect(info.positionDetail, isNull);
      expect(info.destination, '종착역');
      expect(info.remainingSeconds, 0);
      expect(info.arvlCd, 99);
    });
  });

  group('ArrivalInfo.remainingText', () {
    ArrivalInfo make({required int arvlCd, required int seconds, String status = '운행 중'}) =>
        ArrivalInfo(
          currentTrainStatus: status,
          destination: '당산',
          trainLineName: '2호선',
          updnLine: '상행',
          remainingSeconds: seconds,
          arvlCd: arvlCd,
        );

    test('arvlCd 0/1 → 곧 도착', () {
      expect(make(arvlCd: 0, seconds: 5).remainingText, '곧 도착');
      expect(make(arvlCd: 1, seconds: 5).remainingText, '곧 도착');
    });

    test('분+초 표시', () {
      expect(make(arvlCd: 99, seconds: 150).remainingText, '2분 30초 후');
    });

    test('분만 표시 (초 = 0)', () {
      expect(make(arvlCd: 99, seconds: 120).remainingText, '2분 후');
    });

    test('초만 표시 (분 = 0)', () {
      expect(make(arvlCd: 99, seconds: 45).remainingText, '45초 후');
    });

    test('remainingSeconds = 0 이면 currentTrainStatus 반환', () {
      expect(make(arvlCd: 99, seconds: 0, status: '당역 진입').remainingText, '당역 진입');
    });
  });

  group('fetchRealtimeArrival - 실제 API', () {
    test('강남역 도착 정보 조회', () async {
      final arrivals = await SubwayApiService.fetchRealtimeArrival('강남');

      expect(arrivals, isA<List<ArrivalInfo>>());
      if (arrivals.isNotEmpty) {
        expect(arrivals.first.destination, isNotEmpty);
        expect(arrivals.first.updnLine, isNotEmpty);
      }
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
