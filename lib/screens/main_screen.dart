import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/subway_models.dart';
import '../data/station_data.dart';
import '../services/subway_api_service.dart';
import 'timetable_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String weatherTemp = '';
  SubwayStation currentStation = stations[0];

  // 실시간 도착 정보 (현재 열차, 다음 열차)
  List<ArrivalInfo> arrivals = [];
  bool isLoadingArrival = false;
  String? arrivalError;

  @override
  void initState() {
    super.initState();
    fetchWeather();
    _loadArrival(currentStation);
  }

  Future<void> fetchWeather() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.open-meteo.com/v1/forecast'
          '?latitude=37.5665&longitude=126.9780&current_weather=true',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            weatherTemp = "${data['current_weather']['temperature']}°C";
          });
        }
      }
    } catch (e) {
      debugPrint('날씨 정보 로드 실패: $e');
    }
  }

  Future<void> _loadArrival(SubwayStation station) async {
    setState(() {
      isLoadingArrival = true;
      arrivalError = null;
      arrivals = [];
    });
    try {
      final result =
          await SubwayApiService.fetchRealtimeArrival(station.stationName);
      if (mounted) {
        setState(() {
          arrivals = result;
          isLoadingArrival = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          arrivalError = e.toString();
          isLoadingArrival = false;
        });
      }
    }
  }

  void _onStationSelected(SubwayStation station) {
    setState(() => currentStation = station);
    _loadArrival(station);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '지하철 시간표',
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 역 검색창
            Autocomplete<SubwayStation>(
              initialValue: TextEditingValue(text: currentStation.stationName),
              displayStringForOption: (s) => s.stationName,
              optionsBuilder: (TextEditingValue value) {
                if (value.text.isEmpty) {
                  return const Iterable<SubwayStation>.empty();
                }
                return stations.where(
                  (s) =>
                      s.stationName.contains(value.text) ||
                      s.lineName.contains(value.text),
                );
              },
              onSelected: _onStationSelected,
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
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
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final s = options.elementAt(index);
                          return ListTile(
                            title: Text(
                              s.stationName,
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
                                s.lineName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                            onTap: () => onSelected(s),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // 실시간 도착 정보 헤더
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
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => _loadArrival(currentStation),
                  tooltip: '새로고침',
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildArrivalCard(),
            const SizedBox(height: 24),

            // 탑승 위치 정보
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

            const Spacer(),

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
                    builder: (_) =>
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

  Widget _buildArrivalCard() {
    if (isLoadingArrival) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (arrivalError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '도착 정보를 불러오지 못했습니다.\n$arrivalError',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (arrivals.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('도착 예정 열차 정보가 없습니다.'),
        ),
      );
    }

    final current = arrivals[0];
    final next = arrivals.length > 1 ? arrivals[1] : null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${current.destination}행  ·  ${current.updnLine}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    current.currentTrainStatus,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (next != null)
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
                        next.currentTrainStatus,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
