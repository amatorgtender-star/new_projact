import '../models/subway_models.dart';

// --- 샘플 데이터 ---
final List<SubwayStation> sampleStations = [
  SubwayStation(stationName: '강남', lineName: '2호선'),
  SubwayStation(stationName: '성수', lineName: '2호선'),
  SubwayStation(stationName: '원흥', lineName: '3호선'),
  SubwayStation(stationName: '탄현', lineName: '경의중앙선'),
  SubwayStation(stationName: '가능', lineName: '1호선'),
  SubwayStation(stationName: '의정부', lineName: '1호선'),
  SubwayStation(stationName: '파주', lineName: '경의중앙선'),
  SubwayStation(stationName: '금천', lineName: '1호선'),
  SubwayStation(stationName: '운정', lineName: '경의중앙선'),
  SubwayStation(stationName: '등촌', lineName: '9호선'),
  SubwayStation(stationName: '종합운동장', lineName: '9호선'),
  SubwayStation(stationName: '송파나루', lineName: '9호선'),
  SubwayStation(stationName: '중앙보훈병원', lineName: '9호선'),
  SubwayStation(stationName: '공덕', lineName: '공항철도'),
  SubwayStation(stationName: '가산디지털단지', lineName: '1호선'),
  SubwayStation(stationName: '의왕', lineName: '1호선'),
  SubwayStation(stationName: '성균관대', lineName: '1호선'),
  SubwayStation(stationName: '오산대', lineName: '1호선'),
  SubwayStation(stationName: '신설동', lineName: '1호선'),
  SubwayStation(stationName: '남영', lineName: '1호선'),
  SubwayStation(stationName: '외대앞', lineName: '1호선'),
  SubwayStation(stationName: '신창', lineName: '1호선'),
  SubwayStation(stationName: '온양온천', lineName: '1호선'),
  SubwayStation(stationName: '안양', lineName: '1호선'),
  SubwayStation(stationName: '연신내', lineName: '3호선'),
  SubwayStation(stationName: '구파발', lineName: '3호선'),
  SubwayStation(stationName: '불광', lineName: '3호선'),
  SubwayStation(stationName: '원종', lineName: '서해선'),
  SubwayStation(stationName: '능곡', lineName: '서해선'),
  SubwayStation(stationName: '대곡', lineName: '서해선'),
  SubwayStation(stationName: '원시', lineName: '서해선'),
  SubwayStation(stationName: '시우', lineName: '서해선'),
  SubwayStation(stationName: '시흥시청', lineName: '서해선'),
  SubwayStation(stationName: '소새울', lineName: '서해선'),
  SubwayStation(stationName: '화정', lineName: '3호선'),
  SubwayStation(stationName: '삼송', lineName: '3호선'),
  SubwayStation(stationName: '대화', lineName: '3호선'),
  // --- 환승역 보강 데이터 ---
  SubwayStation(stationName: '강남', lineName: '신분당선'),
  SubwayStation(stationName: '교대', lineName: '2호선'),
  SubwayStation(stationName: '교대', lineName: '3호선'),
  SubwayStation(stationName: '신도림', lineName: '1호선'),
  SubwayStation(stationName: '신도림', lineName: '2호선'),
  SubwayStation(stationName: '왕십리', lineName: '2호선'),
  SubwayStation(stationName: '왕십리', lineName: '5호선'),
  SubwayStation(stationName: '왕십리', lineName: '수인분당선'),
  SubwayStation(stationName: '왕십리', lineName: '경의중앙선'),
  SubwayStation(stationName: '공덕', lineName: '5호선'),
  SubwayStation(stationName: '공덕', lineName: '6호선'),
  SubwayStation(stationName: '공덕', lineName: '경의중앙선'),
  SubwayStation(stationName: '가산디지털단지', lineName: '7호선'),
  SubwayStation(stationName: '대곡', lineName: '경의중앙선'),
  SubwayStation(stationName: '고속터미널', lineName: '3호선'),
  SubwayStation(stationName: '고속터미널', lineName: '7호선'),
  SubwayStation(stationName: '고속터미널', lineName: '9호선'),
  SubwayStation(stationName: '사당', lineName: '2호선'),
  SubwayStation(stationName: '사당', lineName: '4호선'),

];

// --- 가상 데이터 생성 로직 ---
ArrivalInfo generateArrivalInfo(SubwayStation station) {
  final sameLine = sampleStations
      .where(
        (s) =>
            s.lineName == station.lineName &&
            s.stationName != station.stationName,
      )
      .toList();

  final destName1 = sameLine.isNotEmpty ? sameLine[0].stationName : '상행종점';
  final destName2 = sameLine.length > 1 ? sameLine[1].stationName : '하행종점';

  final second = DateTime.now().second;
  // 상행 데이터 계산
  final upMins = (second % 5) + 1;
  final upStops = (upMins / 2).ceil();
  final upNextMins = upMins + (second % 4) + 4;
  final upNextStops = (upNextMins / 2).ceil();

  // 하행 데이터 계산 (약간 다르게)
  final downMins = ((second + 15) % 6) + 1;
  final downStops = (downMins / 2).ceil();
  final downNextMins = downMins + ((second + 5) % 3) + 3;
  final downNextStops = (downNextMins / 2).ceil();

  return ArrivalInfo(
    upboundDestination: destName1,
    upboundCurrentStatus: '$upMins분 후 ($upStops역 전)',
    upboundNextStatus: '$upNextMins분 후 ($upNextStops역 전)',
    downboundDestination: destName2,
    downboundCurrentStatus: '$downMins분 후 ($downStops역 전)',
    downboundNextStatus: '$downNextMins분 후 ($downNextStops역 전)',
    isDelayed: DateTime.now().second % 10 == 0,
    delayMessage: '앞 열차와의 간격 조정으로 지연 운행중입니다.',
  );
}

List<TrainSchedule> generateTimetable(SubwayStation station, String direction) {
  final sameLine = sampleStations
      .where(
        (s) =>
            s.lineName == station.lineName &&
            s.stationName != station.stationName,
      )
      .toList();
  String destName = '종점';
  if (sameLine.length > 1) {
    destName = direction == 'up'
        ? sameLine[0].stationName
        : sameLine[1].stationName;
  } else if (sameLine.isNotEmpty) {
    destName = sameLine[0].stationName;
  }

  List<TrainSchedule> schedules = [];
  DateTime now = DateTime.now();
  int currentMinutes = now.minute;
  int currentHours = now.hour;

  for (int i = 0; i < 15; i++) {
    currentMinutes += (i % 5) + 3; // 3~7분 간격
    if (currentMinutes >= 60) {
      currentMinutes -= 60;
      currentHours = (currentHours + 1) % 24;
    }
    String timeStr =
        '${currentHours.toString().padLeft(2, '0')}:${currentMinutes.toString().padLeft(2, '0')}';
    schedules.add(
      TrainSchedule(
        time: timeStr,
        destination: destName,
        type: (i % 4 == 0) ? '급행' : '일반',
      ),
    );
  }
  return schedules;
}

// --- 추가 정보 (빠른 하차 및 환승) ---
List<String> getTransferLines(SubwayStation station) {
  return sampleStations
      .where(
        (s) =>
            s.stationName == station.stationName &&
            s.lineName != station.lineName,
      )
      .map((s) => s.lineName)
      .toList();
}

String getFastExit(SubwayStation station) {
  final hash = station.stationName.hashCode.abs();
  final car = (hash % 10) + 1; // 1 to 10
  final door = (hash % 4) + 1; // 1 to 4
  return '$car-$door 번 문';
}

int getEstimatedTravelTime(SubwayStation departure, SubwayStation arrival) {
  final diff = (departure.stationName.hashCode - arrival.stationName.hashCode)
      .abs();
  return (diff % 40) + 10; // 10~50분 사이
}

int getStationCount(SubwayStation departure, SubwayStation arrival) {
  final diff = (departure.stationName.hashCode - arrival.stationName.hashCode)
      .abs();
  return (diff % 15) + 3; // 3~18개 역 사이
}

String? getTransferStation(SubwayStation departure, SubwayStation arrival) {
  if (departure.lineName == arrival.lineName) return null;

  // 1. 공통으로 정차하는 역이 있는지 확인 (실제 데이터 기반 환승역 찾기)
  final depLineStations =
      sampleStations.where((s) => s.lineName == departure.lineName).map((s) => s.stationName).toSet();
  final arrLineStations =
      sampleStations.where((s) => s.lineName == arrival.lineName).map((s) => s.stationName).toSet();

  final commonStations = depLineStations.intersection(arrLineStations);

  if (commonStations.isNotEmpty) {
    return commonStations.first;
  }

  // 2. 공통 역이 없을 경우, 데이터셋 내의 주요 환승 거점역 중 하나를 반환 (폴백 로직)
  final hash = (departure.stationName.hashCode ^ arrival.stationName.hashCode).abs();
  final transferStops = [
    '사당',
    '강남',
    '종로3가',
    '신도림',
    '왕십리',
    '동대문역사문화공원',
    '건대입구',
    '교대',
    '공덕',
    '합정',
    '고속터미널',
  ];
  return transferStops[hash % transferStops.length];
}

// --- 연계 교통 정보 ---
List<String> getConnectedTransit(SubwayStation station) {
  final hash = station.stationName.hashCode.abs();
  final busCount = (hash % 4) + 1; // 1~4개의 버스 노선으로 확장
  List<String> buses = [];
  for (int i = 0; i < busCount; i++) {
    int busNum = (hash % 800) + (i * 150) + 11;
    if (i == 0)
      buses.add('간선 $busNum');
    else if (i == 1)
      buses.add('지선 $busNum');
    else if (i == 2)
      buses.add('광역 $busNum'); // 광역버스 추가
    else if (i == 3)
      buses.add('마을 버스 ${(busNum % 15) + 1}');
  }
  return buses;
}

String getExitForTransit(SubwayStation station) {
  final hash = station.stationName.hashCode.abs();
  return '${(hash % 10) + 1}번 출구';
}