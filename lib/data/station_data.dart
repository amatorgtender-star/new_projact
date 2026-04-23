import 'package:flutter/foundation.dart';
import '../models/subway_models.dart';
import '../services/subway_api_service.dart';

String getTransferStation(SubwayStation from, SubwayStation to) {
  if (from.lineName == to.lineName) return '환승 불필요';

  // 특정 노선 조합별 주요 환승역 매핑
  final transferMap = {
    '1호선-2호선': '시청',
    '2호선-1호선': '시청',
    '1호선-3호선': '종로3가',
    '3호선-1호선': '종로3가',
    '2호선-3호선': '을지로3가',
    '3호선-2호선': '을지로3가',
    '2호선-9호선': '종합운동장',
    '9호선-2호선': '종합운동장',
    '3호선-9호선': '고속터미널',
    '9호선-3호선': '고속터미널',
    '3호선-경의중앙선': '옥수',
    '경의중앙선-3호선': '옥수',
    '1호선-공항철도': '서울역',
    '공항철도-1호선': '서울역',
    '2호선-공항철도': '홍대입구',
    '공항철도-2호선': '홍대입구',
  };

  final key = '${from.lineName}-${to.lineName}';
  if (transferMap.containsKey(key)) {
    return transferMap[key]!;
  }

  // 기본 환승역 (목록에 없는 경우 중복역 검색)
  for (var s1 in stations) {
    if (s1.lineName == from.lineName) {
      for (var s2 in stations) {
        if (s2.lineName == to.lineName && s1.stationName == s2.stationName) {
          return s1.stationName;
        }
      }
    }
  }

  return '환승역 미확인';
}

String getFastExit(SubwayStation station) {
  final data = {
    '강남': '2-3, 8-2',
    '홍대입구': '1-1, 10-4',
    '시청': '4-1, 7-4',
    '서울역': '1-1, 10-4',
    '종로3가': '4-2, 7-1',
    '잠실': '2-3, 9-4',
    '을지로입구': '3-4, 8-1',
    '동대문역사문화공원': '1-1, 10-1',
    '대화': '1-1, 4-2',
  };
  return data[station.stationName] ?? '4-1, 10-4';
}

String getExitForTransit(SubwayStation station) {
  final data = {
    '강남': '10번 출구',
    '홍대입구': '9번 출구',
    '시청': '1번 출구',
    '서울역': '1번 출구',
    '종로3가': '15번 출구',
    '잠실': '8번 출구',
    '역삼': '4번 출구',
    '삼성': '5번 출구',
    '대화': '1, 2, 3번 출구',
  };
  return data[station.stationName] ?? '1번 출구';
}

List<String> getConnectedTransit(SubwayStation station) {
  final data = {
    '강남': ['지선 3412', '간선 140', '광역 9404', '마을 서초03'],
    '홍대입구': ['지선 7016', '간선 271', '광역 M6117', '공항 6002'],
    '서울역': ['간선 150', '간선 400', '광역 9701', '순환 01'],
    '시청': ['간선 101', '간선 103', '지선 7019'],
    '잠실': ['간선 303', '지선 2415', '광역 9403'],
    '역삼': ['간선 147', '지선 4432'],
    '삼성': ['간선 143', '지선 2413', '광역 M6450'],
    '대화': ['마을 010', '지선 7727', '간선 707'],
  };
  return data[station.stationName] ?? [];
}

// 전역 변수 (앱 시작 시 API로 교체됨. API 실패 시 아래 fallback 사용)
List<SubwayStation> stations = [
  SubwayStation(stationName: '서울역', lineName: '1호선', stationCode: '0150'),
  SubwayStation(stationName: '시청', lineName: '1호선', stationCode: '0151'),
  SubwayStation(stationName: '종로3가', lineName: '1호선', stationCode: '0130'),
  SubwayStation(stationName: '강남', lineName: '2호선', stationCode: '0222'),
  SubwayStation(stationName: '홍대입구', lineName: '2호선', stationCode: '0239'),
  SubwayStation(stationName: '잠실', lineName: '2호선', stationCode: '0216'),
  SubwayStation(stationName: '고속터미널', lineName: '3호선', stationCode: '0337'),
  SubwayStation(stationName: '대화', lineName: '3호선', stationCode: '0301'),
  SubwayStation(stationName: '사당', lineName: '4호선', stationCode: '0425'),
  SubwayStation(stationName: '여의도', lineName: '5호선', stationCode: '0527'),
  SubwayStation(stationName: '뚝섬유원지', lineName: '7호선', stationCode: '0727'),
  SubwayStation(stationName: '김포공항', lineName: '공항철도', stationCode: '4101'),
];

/// 앱 시작 시 호출하여 API로부터 최신 역 목록을 받아오는 함수
Future<void> initializeStations() async {
  try {
    final fetched = await SubwayApiService.fetchAllStations();
    if (fetched.isNotEmpty) {
      stations = fetched;
      debugPrint('역 목록 로드 완료: ${fetched.length}개');
    } else {
      debugPrint('역 목록 API 응답 없음 — fallback 사용 (${stations.length}개)');
    }
  } catch (e) {
    debugPrint('역 목록 로드 실패: $e — fallback 사용 (${stations.length}개)');
  }
}
