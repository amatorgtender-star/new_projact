import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const SubwayApp());
}

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

class DestInfo {
  final String fastExit;
  final String buses;
  DestInfo({required this.fastExit, required this.buses});
}

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
    currentMinutes += (i % 5) + 3;
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

DestInfo generateDestInfo() {
  final random = Random();
  final doors = ['1-1', '2-4', '3-1', '4-2', '5-4', '7-1', '10-4'];
  final buses = [
    '간선 144',
    '간선 360',
    '지선 3412',
    '지선 4312',
    '마을 서초03',
    '마을 강남08',
    '광역 9401',
    '간선 145',
    '지선 7011',
  ];

  buses.shuffle();
  final selectedBuses = buses.take(random.nextInt(3) + 2).join(', ');

  return DestInfo(
    fastExit: '${doors[random.nextInt(doors.length)]}번 문',
    buses: selectedBuses,
  );
}

// --- 메인 앱 ---
class SubwayApp extends StatelessWidget {
  const SubwayApp({super.key});

  Color getThemeColor() {
    int weekday = DateTime.now().weekday;
    if (weekday == DateTime.saturday) return Colors.blue;
    if (weekday == DateTime.sunday) return Colors.red;
    return Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '지하철 시간 안내표',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: getThemeColor(),
        appBarTheme: AppBarTheme(
          backgroundColor: getThemeColor(),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.grey.shade50,
      ),
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: child,
          ),
        );
      },
      home: const MainScreen(),
    );
  }
}

// --- 1. 메인 화면 ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String weatherTemp = "";
  SubwayStation currentStation = sampleStations[0];
  SubwayStation? destStation;
  late ArrivalInfo currentArrivalInfo;
  DestInfo? currentDestInfo;

  @override
  void initState() {
    super.initState();
    fetchWeather();
    currentArrivalInfo = generateArrivalInfo(currentStation);
  }

  Future<void> fetchWeather() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=37.5665&longitude=126.9780&current_weather=true',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          weatherTemp = "${data['current_weather']['temperature']}°C";
        });
      }
    } catch (e) {
      debugPrint("날씨 정보 로드 실패: $e");
    }
  }

  void updateStation(SubwayStation newStation) {
    setState(() {
      currentStation = newStation;
      currentArrivalInfo = generateArrivalInfo(newStation);
    });
  }

  void updateDestStation(SubwayStation newStation) {
    setState(() {
      destStation = newStation;
      currentDestInfo = generateDestInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '지하철 시간 안내표',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (weatherTemp.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: Row(
                  children: [
                    const Icon(Icons.cloud, size: 20),
                    const SizedBox(width: 4),
                    Text(weatherTemp, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 3.1 역 검색창 (출발역)
            Autocomplete<SubwayStation>(
              initialValue: TextEditingValue(text: currentStation.stationName),
              displayStringForOption: (SubwayStation option) =>
                  option.stationName,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '')
                  return const Iterable<SubwayStation>.empty();
                return sampleStations.where(
                  (option) =>
                      option.stationName.contains(textEditingValue.text) ||
                      option.lineName.contains(textEditingValue.text),
                );
              },
              onSelected: updateStation,
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          hintText: '출발역 검색 (예: 강남, 1호선)',
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 468),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            title: Text(
                              option.stationName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                option.lineName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),

            // 도착역 검색창
            Autocomplete<SubwayStation>(
              displayStringForOption: (SubwayStation option) =>
                  option.stationName,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '')
                  return const Iterable<SubwayStation>.empty();
                return sampleStations.where(
                  (option) =>
                      option.stationName.contains(textEditingValue.text) ||
                      option.lineName.contains(textEditingValue.text),
                );
              },
              onSelected: updateDestStation,
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          hintText: '도착역 검색 (선택)',
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 468),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            title: Text(
                              option.stationName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                option.lineName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // 3.1 실시간 정보
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '실시간 도착 정보',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  currentStation.lineName,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${currentArrivalInfo.destination}행',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currentArrivalInfo.currentTrainStatus,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '다음 열차',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              currentArrivalInfo.nextTrainStatus,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (currentArrivalInfo.isDelayed) ...[
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentArrivalInfo.delayMessage ?? '',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 3.2 지하철 탑승 위치 정보
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '탑승 위치 정보',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.blue.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.accessible, color: Colors.blue),
                              SizedBox(width: 4),
                              Icon(Icons.pregnant_woman, color: Colors.blue),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            '교통약자석\n(1-1, 10-4)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    color: Colors.cyan.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.ac_unit, color: Colors.cyan),
                          SizedBox(height: 8),
                          Text(
                            '약냉방칸\n(4, 5번 칸)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.cyan,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // 도착역 하차 정보 (도착역이 선택된 경우에만 표시)
            if (destStation != null && currentDestInfo != null) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.pin_drop, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    '도착역 하차 정보',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${destStation!.stationName}역',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.green.shade50,
                            child: Icon(
                              Icons.door_sliding,
                              color: Colors.green.shade600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '빠른 환승 / 하차 위치',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  currentDestInfo!.fastExit,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.orange.shade50,
                            child: Icon(
                              Icons.directions_bus,
                              color: Colors.orange.shade600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '연계 버스 노선',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  currentDestInfo!.buses,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // 3.3 이동 버튼
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TimetableScreen(station: currentStation),
                  ),
                );
              },
              child: const Text(
                '전체 시간표 보기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// --- 2. 전체 시간표 화면 ---
class TimetableScreen extends StatefulWidget {
  final SubwayStation station;

  const TimetableScreen({super.key, required this.station});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late List<TrainSchedule> upSchedules;
  late List<TrainSchedule> downSchedules;

  @override
  void initState() {
    super.initState();
    upSchedules = generateTimetable(widget.station, 'up');
    downSchedules = generateTimetable(widget.station, 'down');
  }

  Widget _buildScheduleList(List<TrainSchedule> schedules) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: schedules.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 4,
          ),
          leading: Text(
            schedule.time,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          title: Text(
            '${schedule.destination}행',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('${schedule.type}열차'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: schedule.type == '급행'
                  ? Colors.red.shade50
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              schedule.type,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: schedule.type == '급행'
                    ? Colors.red.shade700
                    : Colors.black54,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.station.stationName}역 시간표',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(text: '상행'),
              Tab(text: '하행'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildScheduleList(upSchedules),
            _buildScheduleList(downSchedules),
          ],
        ),
      ),
    );
  }
}
