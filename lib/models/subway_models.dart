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
  final String? positionDetail; // arvlMsg3 - 이전역 출발 정보
  final String destination; // bstatnNm - 종착역명
  final String trainLineName; // trainLineNm - 방면 (예: "상행 - 당산방면")
  final String updnLine; // 상행 / 하행
  final String subwayId; // 서울 열린데이터 API 노선 ID
  final int remainingSeconds; // barvlDt - 도착까지 남은 초
  final int arvlCd; // 도착코드: 0=진입,1=도착,2=출발,3=전역출발,4=전역진입,5=전역도착,99=운행중

  const ArrivalInfo({
    required this.currentTrainStatus,
    this.positionDetail,
    required this.destination,
    required this.trainLineName,
    required this.updnLine,
    required this.subwayId,
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
      subwayId: json['subwayId'] as String? ?? '',
      remainingSeconds: int.tryParse(json['barvlDt']?.toString() ?? '0') ?? 0,
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

  bool matchesLine(String lineName) {
    final normalizedLineName = lineName.trim();
    if (normalizedLineName.isEmpty) {
      return true;
    }

    const subwayIdByLineName = {
      '1호선': '1001',
      '2호선': '1002',
      '3호선': '1003',
      '4호선': '1004',
      '5호선': '1005',
      '6호선': '1006',
      '7호선': '1007',
      '8호선': '1008',
      '9호선': '1009',
      '공항철도': '1065',
      '경의중앙선': '1063',
      '서해선': '1093',
      '수인분당선': '1075',
      '신분당선': '1077',
      '우이신설선': '1092',
      '신림선': '1094',
      '경춘선': '1067',
      '경강선': '1081',
      '중앙선': '1061',
    };

    final expectedSubwayId = subwayIdByLineName[normalizedLineName];
    if (expectedSubwayId != null && subwayId.isNotEmpty) {
      return subwayId == expectedSubwayId;
    }

    return trainLineName.contains(normalizedLineName);
  }
}

class TrainSchedule {
  final String time; // HH:MM
  final String destination;
  final String type; // 급행 / 일반
  final bool isExpress;

  const TrainSchedule({
    required this.time,
    required this.destination,
    required this.type,
    this.isExpress = false,
  });

  factory TrainSchedule.fromJson(Map<String, dynamic> json) {
    // LEFTTIME이 있으면 사용, 없으면 ARRIVETIME 사용
    final leftTime = json['LEFTTIME']?.toString() ?? '';
    final arriveTime = json['ARRIVETIME']?.toString() ?? '';
    final rawTime = (leftTime.isNotEmpty && leftTime != '00:00:00')
        ? leftTime
        : arriveTime;

    final time = rawTime.length >= 5 ? rawTime.substring(0, 5) : rawTime;

    // 종착역명: API 실제 필드는 SUBWAYENAME (SUBWAYNAME과 다름)
    final destination =
        (json['SUBWAYENAME']?.toString() ??
                json['SUBWAYSTNNAME']?.toString() ??
                json['DESTSTATION_NM']?.toString() ??
                json['SUBWAYSTN_NM']?.toString() ??
                json['SUBWAYNAME']?.toString() ??
                '')
            .trim();

    // EXPRESS_YN: G(급행), Y(급행), N(일반), D(직통/일반)
    // DIRECT_YN: 1(급행), 2(특급), 0(일반)
    final directYn = (json['DIRECT_YN']?.toString() ?? '').trim();
    final expressYn = (json['EXPRESS_YN']?.toString() ?? '').trim();

    bool isExpress = false;
    if (directYn.isNotEmpty) {
      isExpress = directYn == '1' || directYn == '2';
    } else if (expressYn.isNotEmpty) {
      isExpress = expressYn == 'G' || expressYn == 'Y' || expressYn == '1';
    }

    return TrainSchedule(
      time: time,
      destination: destination.isNotEmpty ? destination : '종착역',
      type: isExpress ? '급행' : '일반',
      isExpress: isExpress,
    );
  }
}
