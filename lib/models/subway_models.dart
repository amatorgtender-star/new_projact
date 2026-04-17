// --- 데이터 모델 ---
class SubwayStation {
  final String stationName;
  final String lineName;
  SubwayStation({required this.stationName, required this.lineName});
}

class ArrivalInfo {
  final String upboundDestination;
  final String upboundCurrentStatus;
  final String upboundNextStatus;

  final String downboundDestination;
  final String downboundCurrentStatus;
  final String downboundNextStatus;

  final bool isDelayed;
  final String? delayMessage;

  ArrivalInfo({
    required this.upboundDestination,
    required this.upboundCurrentStatus,
    required this.upboundNextStatus,
    required this.downboundDestination,
    required this.downboundCurrentStatus,
    required this.downboundNextStatus,
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
