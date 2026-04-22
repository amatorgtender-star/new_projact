import '../models/subway_models.dart';

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

// 서울 지하철 역 목록
// stationCode: SearchSTNTimeTableByIDService 역코드 (4자리)
// 정확한 코드는 서울 열린데이터광장 > 지하철역 마스터 데이터에서 확인하세요.
const List<SubwayStation> stations = [
  // 1호선
  SubwayStation(stationName: '서울역', lineName: '1호선', stationCode: '0150'),
  SubwayStation(stationName: '시청', lineName: '1호선', stationCode: '0151'),
  SubwayStation(stationName: '종각', lineName: '1호선', stationCode: '0152'),
  SubwayStation(stationName: '종로3가', lineName: '1호선', stationCode: '0153'),
  SubwayStation(stationName: '동대문', lineName: '1호선', stationCode: '0155'),
  SubwayStation(stationName: '신설동', lineName: '1호선', stationCode: '0157'),
  SubwayStation(stationName: '청량리', lineName: '1호선', stationCode: '0162'),
  SubwayStation(stationName: '가능', lineName: '1호선', stationCode: '0165'),
  SubwayStation(stationName: '의정부', lineName: '1호선', stationCode: '0168'),
  SubwayStation(stationName: '안양', lineName: '1호선', stationCode: '0174'),
  SubwayStation(stationName: '수원', lineName: '1호선', stationCode: '0175'),
  SubwayStation(stationName: '오산대', lineName: '1호선', stationCode: '0177'),
  SubwayStation(stationName: '금천구청', lineName: '1호선', stationCode: '0172'),
  SubwayStation(stationName: '가산디지털단지', lineName: '1호선', stationCode: '0171'),
  SubwayStation(stationName: '남영', lineName: '1호선', stationCode: '0149'),
  SubwayStation(stationName: '외대앞', lineName: '1호선', stationCode: '0160'),
  SubwayStation(stationName: '신창', lineName: '1호선', stationCode: '0193'),
  SubwayStation(stationName: '온양온천', lineName: '1호선', stationCode: '0191'),
  SubwayStation(stationName: '성균관대', lineName: '1호선', stationCode: '0176'),
  SubwayStation(stationName: '의왕', lineName: '1호선', stationCode: '0179'),

  // 2호선
  SubwayStation(stationName: '시청', lineName: '2호선', stationCode: '0201'),
  SubwayStation(stationName: '을지로입구', lineName: '2호선', stationCode: '0202'),
  SubwayStation(stationName: '을지로3가', lineName: '2호선', stationCode: '0203'),
  SubwayStation(stationName: '동대문역사문화공원', lineName: '2호선', stationCode: '0212'),
  SubwayStation(stationName: '잠실', lineName: '2호선', stationCode: '0216'),
  SubwayStation(stationName: '종합운동장', lineName: '2호선', stationCode: '0215'),
  SubwayStation(stationName: '선릉', lineName: '2호선', stationCode: '0220'),
  SubwayStation(stationName: '역삼', lineName: '2호선', stationCode: '0221'),
  SubwayStation(stationName: '강남', lineName: '2호선', stationCode: '0222'),
  SubwayStation(stationName: '삼성', lineName: '2호선', stationCode: '0223'),
  SubwayStation(stationName: '성수', lineName: '2호선', stationCode: '0234'),
  SubwayStation(stationName: '홍대입구', lineName: '2호선', stationCode: '0239'),
  SubwayStation(stationName: '신촌', lineName: '2호선', stationCode: '0240'),
  SubwayStation(stationName: '이대', lineName: '2호선', stationCode: '0241'),

  // 3호선
  SubwayStation(stationName: '대화', lineName: '3호선', stationCode: '0301'),
  SubwayStation(stationName: '삼송', lineName: '3호선', stationCode: '0303'),
  SubwayStation(stationName: '화정', lineName: '3호선', stationCode: '0305'),
  SubwayStation(stationName: '원흥', lineName: '3호선', stationCode: '0306'),
  SubwayStation(stationName: '구파발', lineName: '3호선', stationCode: '0309'),
  SubwayStation(stationName: '연신내', lineName: '3호선', stationCode: '0310'),
  SubwayStation(stationName: '불광', lineName: '3호선', stationCode: '0311'),
  SubwayStation(stationName: '독립문', lineName: '3호선', stationCode: '0313'),

  // 4호선
  SubwayStation(stationName: '수유', lineName: '4호선', stationCode: '0414'),
  SubwayStation(stationName: '명동', lineName: '4호선', stationCode: '0424'),
  SubwayStation(stationName: '사당', lineName: '4호선', stationCode: '0433'),
  SubwayStation(stationName: '혜화', lineName: '4호선', stationCode: '0420'),

  // 5호선
  SubwayStation(stationName: '광화문', lineName: '5호선', stationCode: '0533'),
  SubwayStation(stationName: '여의도', lineName: '5호선', stationCode: '0526'),
  SubwayStation(stationName: '김포공항', lineName: '5호선', stationCode: '0512'),

  // 7호선
  SubwayStation(stationName: '건대입구', lineName: '7호선', stationCode: '0727'),
  SubwayStation(stationName: '고속터미널', lineName: '7호선', stationCode: '0734'),
  SubwayStation(stationName: '노원', lineName: '7호선', stationCode: '0713'),

  // 8호선
  SubwayStation(stationName: '문정', lineName: '8호선', stationCode: '0818'),
  SubwayStation(stationName: '장지', lineName: '8호선', stationCode: '0819'),
  SubwayStation(stationName: '복정', lineName: '8호선', stationCode: '0820'),

  // 9호선
  SubwayStation(stationName: '등촌', lineName: '9호선', stationCode: '0911'),
  SubwayStation(stationName: '종합운동장', lineName: '9호선', stationCode: '0920'),
  SubwayStation(stationName: '송파나루', lineName: '9호선', stationCode: '0921'),
  SubwayStation(stationName: '중앙보훈병원', lineName: '9호선', stationCode: '0930'),

  // 공항철도
  SubwayStation(stationName: '공덕', lineName: '공항철도', stationCode: '4106'),
  SubwayStation(stationName: '홍대입구', lineName: '공항철도', stationCode: '4107'),

  // 경의중앙선
  SubwayStation(stationName: '탄현', lineName: '경의중앙선', stationCode: '2004'),
  SubwayStation(stationName: '능곡', lineName: '경의중앙선', stationCode: '2007'),
  SubwayStation(stationName: '운정', lineName: '경의중앙선', stationCode: '2001'),

  // 서해선
  SubwayStation(stationName: '대곡', lineName: '서해선', stationCode: '3101'),
  SubwayStation(stationName: '능곡', lineName: '서해선', stationCode: '3102'),
  SubwayStation(stationName: '원종', lineName: '서해선', stationCode: '3104'),
  SubwayStation(stationName: '소새울', lineName: '서해선', stationCode: '3108'),
  SubwayStation(stationName: '시흥시청', lineName: '서해선', stationCode: '3109'),
  SubwayStation(stationName: '시우', lineName: '서해선', stationCode: '3110'),
  SubwayStation(stationName: '원시', lineName: '서해선', stationCode: '3111'),
];
