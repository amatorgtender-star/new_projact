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
  final destName = sameLine.isNotEmpty ? sameLine[0].stationName : '종점';
  final statuses = ['전역 도착', '당역 진입', '1정거장 전', '2정거장 전', '3정거장 전'];

  return ArrivalInfo(
    currentTrainStatus: statuses[DateTime.now().second % 2],
    nextTrainStatus: statuses[(DateTime.now().second % 3) + 2],
    destination: destName,
    isDelayed: DateTime.now().second % 2 == 0,
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
