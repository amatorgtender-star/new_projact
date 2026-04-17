import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/subway_models.dart';
import '../data/dummy_data.dart';
import 'timetable_screen.dart';

// --- 1. 메인 화면 ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String weatherTemp = "";
  SubwayStation? departureStation;
  SubwayStation? arrivalStation;
  ArrivalInfo? currentArrivalInfo;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _infoSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    fetchWeather();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  void updateDepartureStation(SubwayStation newStation) {
    setState(() {
      departureStation = newStation;
      currentArrivalInfo = generateArrivalInfo(newStation);
    });
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _infoSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      }
    });
  }

  void updateArrivalStation(SubwayStation newStation) {
    setState(() {
      arrivalStation = newStation;
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Widget _buildArrivalCard({
    required String direction,
    required String destination,
    required String currentStatus,
    required String nextStatus,
    required bool isDelayed,
    String? delayMessage,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  direction,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$destination행',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currentStatus,
                  style: const TextStyle(
                    fontSize: 22,
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
                      nextStatus,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isDelayed) ...[
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
                      delayMessage ?? '',
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '지하철 시간표 만들기',
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
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // 역 검색 및 여정 정보
            Autocomplete<SubwayStation>(
              initialValue: TextEditingValue(text: departureStation?.stationName ?? ''),
              displayStringForOption: (SubwayStation option) =>
                  option.stationName,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<SubwayStation>.empty();
                }
                return sampleStations.where((SubwayStation option) {
                  return option.stationName.contains(textEditingValue.text) ||
                      option.lineName.contains(textEditingValue.text);
                });
              },
              onSelected: updateDepartureStation,
              fieldViewBuilder: (context, textEditingController, focusNode,
                  onFieldSubmitted) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    onSubmitted: (_) => onFieldSubmitted(),
                    decoration: const InputDecoration(
                      hintText: '출발역 검색 (예: 강남, 2호선)',
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
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 32,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final SubwayStation option = options.elementAt(index);
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
            const SizedBox(height: 8),
            const Center(
              child: Icon(Icons.keyboard_double_arrow_down_rounded,
                  color: Colors.grey, size: 20),
            ),
            const SizedBox(height: 8),
            Autocomplete<SubwayStation>(
              initialValue:
                  TextEditingValue(text: arrivalStation?.stationName ?? ''),
              displayStringForOption: (SubwayStation option) =>
                  option.stationName,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<SubwayStation>.empty();
                }
                return sampleStations.where((SubwayStation option) {
                  return option.stationName.contains(textEditingValue.text) ||
                      option.lineName.contains(textEditingValue.text);
                });
              },
              onSelected: updateArrivalStation,
              fieldViewBuilder: (context, textEditingController, focusNode,
                  onFieldSubmitted) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    onSubmitted: (_) => onFieldSubmitted(),
                    decoration: const InputDecoration(
                      hintText: '도착역 검색 (예: 사당, 4호선)',
                      prefixIcon:
                          Icon(Icons.location_on, color: Colors.blueAccent),
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
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 32,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final SubwayStation option = options.elementAt(index);
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

            if (departureStation != null) ...[
              // 환승 및 도착지 연계 정보 (둘 다 선택 시에만 표시)
              if (arrivalStation != null) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.directions_subway, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text(
                      '환승 및 도착지 연계 정보',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: Colors.green.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.green.shade100),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // 환승 정보
                        if (departureStation!.lineName !=
                            arrivalStation!.lineName)
                          () {
                            final transferStationName = getTransferStation(
                                departureStation!, arrivalStation!);
                            final transferStation = sampleStations.firstWhere(
                              (s) => s.stationName == transferStationName,
                              orElse: () => arrivalStation!,
                            );
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                        Icons.transfer_within_a_station,
                                        color: Colors.green,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      '환승역: $transferStationName',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '빠른문: ${getFastExit(transferStation)}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                              ],
                            );
                          }()
                        else
                          const SizedBox.shrink(),

                        // 도착역 연계 버스 정보
                        Row(
                          children: [
                            const Icon(Icons.bus_alert,
                                color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${arrivalStation!.stationName}역 ${getExitForTransit(arrivalStation!)} 연계 버스',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: getConnectedTransit(arrivalStation!)
                              .map((bus) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.grey.shade200),
                                    ),
                                    child: Text(
                                      bus,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: bus.contains('광역')
                                            ? Colors.red
                                            : (bus.contains('지선')
                                                ? Colors.green
                                                : Colors.blue),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // 실시간 정보
              Row(
                key: _infoSectionKey,
                children: [
                  const Icon(Icons.access_time, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    '실시간 도착 정보',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    departureStation!.lineName,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (currentArrivalInfo != null) ...[
                _buildArrivalCard(
                  direction: '상행 ↑',
                  destination: currentArrivalInfo!.upboundDestination,
                  currentStatus: currentArrivalInfo!.upboundCurrentStatus,
                  nextStatus: currentArrivalInfo!.upboundNextStatus,
                  isDelayed: currentArrivalInfo!.isDelayed,
                  delayMessage: currentArrivalInfo!.delayMessage,
                ),
                const SizedBox(height: 8),
                _buildArrivalCard(
                  direction: '하행 ↓',
                  destination: currentArrivalInfo!.downboundDestination,
                  currentStatus: currentArrivalInfo!.downboundCurrentStatus,
                  nextStatus: currentArrivalInfo!.downboundNextStatus,
                  isDelayed: false,
                  delayMessage: null,
                ),
              ],
              const SizedBox(height: 24),

              // 지하철 탑승 위치 정보
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
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('교통약자석은 1-1, 10-4 구역에 위치해 있습니다.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.accessible, color: Colors.blue),
                                  SizedBox(width: 4),
                                  Icon(Icons.pregnant_woman,
                                      color: Colors.blue),
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      color: Colors.cyan.shade50,
                      elevation: 0,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('약냉방칸은 4번, 5번 칸에 위치해 있습니다.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
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
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // 이동 버튼
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
                          TimetableScreen(station: departureStation!),
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
          ],
        ),
      ),
    ),
  );
}
}
