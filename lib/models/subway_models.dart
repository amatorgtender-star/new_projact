// --- 데이터 모델 ---
class SubwayStation {
  final String stationName;
  final String lineName;
  final String stationCode; // SearchSTNTimeTableByIDService 역코드 (4자리)

  const SubwayStation({
    required this.stationName,
    required this.lineName,
    required this.stationCode,
  });
}

class ArrivalInfo {
  final String currentTrainStatus; // arvlMsg2
  final String? nextTrainStatus;
  final String destination; // bstatnNm
  final bool isDelayed;
  final String? delayMessage;
  final String updnLine; // 상행 / 하행

  const ArrivalInfo({
    required this.currentTrainStatus,
    this.nextTrainStatus,
    required this.destination,
    required this.isDelayed,
    this.delayMessage,
    required this.updnLine,
  });

  factory ArrivalInfo.fromJson(Map<String, dynamic> json) {
    return ArrivalInfo(
      currentTrainStatus: json['arvlMsg2'] as String? ?? '정보 없음',
      destination: json['bstatnNm'] as String? ?? '종착역',
      isDelayed: false,
      updnLine: json['updnLine'] as String? ?? '',
    );
  }
}

class TrainSchedule {
  final String time; // ARRIVETIME (HH:MM)
  final String destination; // SUBWAYNAME
  final String type; // 급행 / 일반

  const TrainSchedule({
    required this.time,
    required this.destination,
    required this.type,
  });

  factory TrainSchedule.fromJson(Map<String, dynamic> json) {
    final raw = json['ARRIVETIME'] as String? ?? '';
    final time = raw.length >= 5 ? raw.substring(0, 5) : raw;
    return TrainSchedule(
      time: time,
      destination: json['SUBWAYNAME'] as String? ?? '',
      type: '일반',
    );
  }
}
