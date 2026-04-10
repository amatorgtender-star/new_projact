// --- 데이터 모델 ---
class SubwayStation {
  final String stationName;
  final String lineName;
  SubwayStation({required this.stationName, required this.lineName});
}

class ArrivalInfo {
  final String currentTrainStatus;
  final String nextTrainStatus;
  final String destination;
  final bool isDelayed;
  final String? delayMessage;

  ArrivalInfo({
    required this.currentTrainStatus,
    required this.nextTrainStatus,
    required this.destination,
    required this.isDelayed,
    this.delayMessage,
  });
}

class TrainSchedule {
  final String time;
  final String destination;
  final String type;
  TrainSchedule({
    required this.time,
    required this.destination,
    required this.type,
  });
}
