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
    String status = json['arvlMsg2'] as String? ?? '정보 없음';
    String dest = json['bstatnNm'] as String? ?? '종착역';

    // 역명 표준화 (성북 -> 광운대 등)
    const stationNameMap = {'성북': '광운대', '신성북': '광운대'};

    stationNameMap.forEach((old, newName) {
      status = status.replaceAll(old, newName);
      dest = dest.replaceAll(old, newName);
    });

    return ArrivalInfo(
      currentTrainStatus: status,
      positionDetail: json['arvlMsg3'] as String?,
      destination: dest,
      trainLineName: json['trainLineNm'] as String? ?? '',
      updnLine: json['updnLine'] as String? ?? '',
      subwayId: json['subwayId'] as String? ?? '',
      remainingSeconds: int.tryParse(json['barvlDt']?.toString() ?? '0') ?? 0,
      arvlCd: int.tryParse(json['arvlCd']?.toString() ?? '99') ?? 99,
    );
  }

  String get remainingText {
    if (arvlCd == 1 || arvlCd == 0) return '곧 도착';
    if (arvlCd == 4) return '전역 진입';
    if (arvlCd == 5) return '전역 도착';
    if (arvlCd == 3) return '전역 출발';

    if (remainingSeconds > 0) {
      final m = remainingSeconds ~/ 60;
      final s = remainingSeconds % 60;
      if (m == 0) return '$s초 후';
      if (s == 0) return '$m분 후';
      return '$m분 $s초 후';
    }

    // currentTrainStatus (arvlMsg2) 정제
    String msg = currentTrainStatus;

    // "[7]번째 전역 (행신)" -> "7번째 전역 (행신)"
    msg = msg.replaceAll('[', '').replaceAll(']', '');

    // "문산행 7번째 전역 (행신)" -> "7번째 전역 (행신)" (목적지 중복 제거)
    if (msg.contains('행')) {
      final parts = msg.split(' ');
      if (parts.isNotEmpty && parts[0].endsWith('행')) {
        msg = parts.skip(1).join(' ');
      }
    }

    return msg;
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
      '인천1호선': '1069',
      '인천2호선': '1071',
      '의정부경전철': '1079',
      '에버라인': '1078',
      '김포골드라인': '1091',
      'GTX-A': '1032',
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
    // 1. 시간 파싱 (trainDptreTm 우선, 없으면 기존 LEFTTIME 등 사용)
    final dptTm =
        json['trainDptreTm']?.toString() ?? json['LEFTTIME']?.toString() ?? '';
    final arvTm =
        json['trainArvlTm']?.toString() ?? json['ARRIVETIME']?.toString() ?? '';

    final rawTime = (dptTm.isNotEmpty && dptTm != '00:00:00') ? dptTm : arvTm;

    // "06:45:30" 형태에서 앞 5자리 "06:45"만 추출
    final time = rawTime.length >= 5 ? rawTime.substring(0, 5) : rawTime;

    // 2. 종착역 파싱 (arvlStnNm 우선 적용)
    final destination =
        (json['arvlStnNm']?.toString() ?? // 👈 새로운 API의 종착역 필드
                json['SUBWAYENAME']?.toString() ?? // 이하 기존 API 필드들
                json['SUBWAYSTNNAME']?.toString() ??
                json['DESTSTATION_NM']?.toString() ??
                json['SUBWAYSTN_NM']?.toString() ??
                json['SUBWAYNAME']?.toString() ??
                '')
            .trim();

    // 3. 급행 여부 파싱 (trainKnd 우선 적용)
    bool isExpress = (json['etrnYn']?.toString() == 'Y');

    return TrainSchedule(
      time: time,
      destination: destination.isNotEmpty ? destination : '종착역',
      type: isExpress ? '급행' : '일반',
      isExpress: isExpress,
    );
  }
}
