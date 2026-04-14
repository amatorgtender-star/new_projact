import '../models/subway_models.dart';

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
