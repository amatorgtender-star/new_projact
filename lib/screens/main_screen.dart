import 'dart:async';
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

  List<ArrivalInfo> arrivals = [];
  bool isLoadingArrival = false;
  String? arrivalError;
  Timer? _refreshTimer;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    fetchWeather();
    _loadArrival(currentStation);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadArrival(currentStation),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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
          _lastUpdated = DateTime.now();
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
    _refreshTimer?.cancel();
    _loadArrival(station);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadArrival(station),
    );
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
                if (_lastUpdated != null)
                  Text(
                    '${_lastUpdated!.hour.toString().padLeft(2, '0')}:'
                    '${_lastUpdated!.minute.toString().padLeft(2, '0')}:'
                    '${_lastUpdated!.second.toString().padLeft(2, '0')} 기준',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                IconButton(
                  icon: isLoadingArrival
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  onPressed:
                      isLoadingArrival ? null : () => _loadArrival(currentStation),
                  tooltip: '새로고침 (30초 자동)',
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildArrivalSection(),
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

  Widget _buildArrivalSection() {
    if (isLoadingArrival && arrivals.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (arrivalError != null && arrivals.isEmpty) {
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

    // 상행/하행별로 그룹화
    final Map<String, List<ArrivalInfo>> grouped = {};
    for (final a in arrivals) {
      final key = a.updnLine.isNotEmpty ? a.updnLine : '기타';
      grouped.putIfAbsent(key, () => []).add(a);
    }

    return Column(
      children: grouped.entries.map((entry) {
        final direction = entry.key;
        final list = entry.value;
        final current = list[0];
        final next = list.length > 1 ? list[1] : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildDirectionCard(direction, current, next),
        );
      }).toList(),
    );
  }

  Widget _buildDirectionCard(
    String direction,
    ArrivalInfo current,
    ArrivalInfo? next,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 방향 뱃지 + 종착역
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: direction.contains('상') || direction.contains('내')
                        ? Colors.blue.shade600
                        : Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    direction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${current.destination}행',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 현재 열차
            _buildTrainRow(
              label: '현재',
              info: current,
              isHighlight: true,
            ),
            if (next != null) ...[
              const Divider(height: 16),
              _buildTrainRow(
                label: '다음',
                info: next,
                isHighlight: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrainRow({
    required String label,
    required ArrivalInfo info,
    required bool isHighlight,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isHighlight ? Colors.blue : Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.currentTrainStatus,
                style: TextStyle(
                  fontSize: isHighlight ? 18 : 14,
                  fontWeight:
                      isHighlight ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (info.positionDetail != null &&
                  info.positionDetail!.isNotEmpty)
                Text(
                  info.positionDetail!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
        ),
        if (info.remainingSeconds > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isHighlight
                  ? Colors.blue.shade50
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              info.remainingText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isHighlight ? Colors.blue.shade700 : Colors.grey.shade600,
              ),
            ),
          ),
      ],
    );
  }
}
