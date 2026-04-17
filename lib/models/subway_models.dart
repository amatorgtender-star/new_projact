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
  final String currentTrainStatus; // arvlMsg2 - 현재 위치 (예: "당역 진입", "2분 30초 후")
  final String? positionDetail;    // arvlMsg3 - 이전역 출발 정보
  final String destination;        // bstatnNm - 종착역명
  final String trainLineName;      // trainLineNm - 방면 (예: "상행 - 당산방면")
  final String updnLine;           // 상행 / 하행
  final int remainingSeconds;      // barvlDt - 도착까지 남은 초
  final int arvlCd;                // 도착코드: 0=진입,1=도착,2=출발,3=전역출발,4=전역진입,5=전역도착,99=운행중

  const ArrivalInfo({
    required this.currentTrainStatus,
    this.positionDetail,
    required this.destination,
    required this.trainLineName,
    required this.updnLine,
    required this.remainingSeconds,
    required this.arvlCd,
  });

  factory ArrivalInfo.fromJson(Map<String, dynamic> json) {
    return ArrivalInfo(
      currentTrainStatus: json['arvlMsg2'] as String? ?? '정보 없음',
      positionDetail: json['arvlMsg3'] as String?,
      destination: json['bstatnNm'] as String? ?? '종착역',
      trainLineName: json['trainLineNm'] as String? ?? '',
      updnLine: json['updnLine'] as String? ?? '',
      remainingSeconds:
          int.tryParse(json['barvlDt']?.toString() ?? '0') ?? 0,
      arvlCd: int.tryParse(json['arvlCd']?.toString() ?? '99') ?? 99,
    );
  }

  String get remainingText {
    if (arvlCd == 1 || arvlCd == 0) return '곧 도착';
    if (remainingSeconds <= 0) return currentTrainStatus;
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    if (m == 0) return '$s초 후';
    if (s == 0) return '$m분 후';
    return '$m분 $s초 후';
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
