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
  String weatherTemp = "";
  SubwayStation? departureStation;
  SubwayStation? arrivalStation;
  List<ArrivalInfo> _arrivals = [];
  bool _isLoadingArrival = false;
  String? _arrivalError;
  Timer? _refreshTimer;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _infoSectionKey = GlobalKey();
  bool _departureJustSelected = false;
  bool _arrivalJustSelected = false;

  String _stationLabel(SubwayStation station) {
    return '${station.stationName} (${station.lineName})';
  }

  Iterable<SubwayStation> _filterStations(String query) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const Iterable<SubwayStation>.empty();
    }

    return stations.where(
      (station) =>
          station.stationName.contains(normalizedQuery) ||
          station.lineName.contains(normalizedQuery),
    );
  }

  SubwayStation? _resolveStationQuery(String query) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return null;
    }

    // 1. 정확히 '역이름 (호선)' 형태와 일치하는지 확인
    for (final station in stations) {
      if (_stationLabel(station) == normalizedQuery) {
        return station;
      }
    }

    // 2. 역 이름만으로 검색 (중복될 경우 첫 번째 반환)
    for (final station in stations) {
      if (station.stationName == normalizedQuery) {
        return station;
      }
    }

    // 3. 필터 결과가 하나뿐이면 그것을 반환
    final matches = _filterStations(normalizedQuery).toList();
    if (matches.length == 1) {
      return matches.first;
    }

    return null;
  }

  void _showStationSearchMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _submitDepartureQuery(String query) {
    final station = _resolveStationQuery(query);
    if (station == null) {
      _showStationSearchMessage('출발역을 목록에서 선택하거나 역 이름을 정확히 입력해 주세요.');
      return;
    }

    updateDepartureStation(station);
  }

  void _submitArrivalQuery(String query) {
    final station = _resolveStationQuery(query);
    if (station == null) {
      _showStationSearchMessage('도착역을 목록에서 선택하거나 역 이름을 정확히 입력해 주세요.');
      return;
    }

    updateArrivalStation(station);
  }

  bool _isUpboundArrival(ArrivalInfo arrival) {
    final directionText = '${arrival.updnLine} ${arrival.trainLineName}';
    // 2호선 외선은 하행으로 간주하고, 내선은 상행으로 간주하는 일반적 규칙 적용
    if (directionText.contains('외선')) return false;
    if (directionText.contains('내선')) return true;
    return directionText.contains('상행');
  }

  bool _isDownboundArrival(ArrivalInfo arrival) {
    final directionText = '${arrival.updnLine} ${arrival.trainLineName}';
    if (directionText.contains('내선')) return false;
    if (directionText.contains('외선')) return true;
    return directionText.contains('하행');
  }

  List<ArrivalInfo> _fallbackDirectionArrivals(bool upbound) {
    return _arrivals.indexed
        .where((entry) => entry.$1.isEven == upbound)
        .map((entry) => entry.$2)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    fetchWeather();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadArrival(SubwayStation station) async {
    setState(() {
      _isLoadingArrival = true;
      _arrivalError = null;
    });
    try {
      final arrivals = await SubwayApiService.fetchRealtimeArrival(
        station.stationName,
      );
      if (departureStation != station) {
        return;
      }
      final filteredArrivals = arrivals
          .where((arrival) => arrival.matchesLine(station.lineName))
          .toList();

      if (mounted) {
        setState(() {
          _arrivals = filteredArrivals.isNotEmpty ? filteredArrivals : arrivals;
          _isLoadingArrival = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _arrivalError = e.toString();
          _isLoadingArrival = false;
        });
      }
    }
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

  void updateDepartureStation(SubwayStation newStation) {
    _departureJustSelected = true;
    setState(() {
      departureStation = newStation;
      _arrivals = [];
      _arrivalError = null;
    });
    _refreshTimer?.cancel();
    _loadArrival(newStation);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadArrival(newStation),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _infoSectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void updateArrivalStation(SubwayStation newStation) {
    _arrivalJustSelected = true;
    setState(() {
      arrivalStation = newStation;
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Widget _buildArrivalCard({
    required String direction,
    required ArrivalInfo? current,
    ArrivalInfo? next,
  }) {
    final currentStatus = current?.remainingText ?? '정보 없음';
    final nextStatus = next?.remainingText ?? '-';
    final destination = current?.destination ?? '-';

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
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsList(
    BuildContext context,
    AutocompleteOnSelected<SubwayStation> onSelected,
    Iterable<SubwayStation> options,
  ) {
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
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final option = options.elementAt(index);
              return ListTile(
                title: Text(
                  option.stationName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                onTap: () => onSelected(option),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matchedUpbound = _arrivals.where(_isUpboundArrival).toList();
    final matchedDownbound = _arrivals.where(_isDownboundArrival).toList();
    final hasDirectionMetadata =
        matchedUpbound.isNotEmpty || matchedDownbound.isNotEmpty;
    final upbound = hasDirectionMetadata
        ? matchedUpbound
        : _fallbackDirectionArrivals(true);
    final downbound = hasDirectionMetadata
        ? matchedDownbound
        : _fallbackDirectionArrivals(false);

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
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 출발역 검색
              Autocomplete<SubwayStation>(
                initialValue: TextEditingValue(
                  text: departureStation == null
                      ? ''
                      : _stationLabel(departureStation!),
                ),
                displayStringForOption: _stationLabel,
                optionsBuilder: (textEditingValue) {
                  if (_departureJustSelected) {
                    _departureJustSelected = false;
                    return const Iterable<SubwayStation>.empty();
                  }
                  return _filterStations(textEditingValue.text);
                },
                onSelected: updateDepartureStation,
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
                          onSubmitted: (value) {
                            _submitDepartureQuery(value);
                            onFieldSubmitted();
                          },
                          decoration: InputDecoration(
                            hintText: '출발역 검색 (예: 강남, 2호선)',
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            suffixIcon: controller.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      controller.clear();
                                      setState(() {
                                        departureStation = null;
                                        _arrivals = [];
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      );
                    },
                optionsViewBuilder: _buildOptionsList,
              ),
              const SizedBox(height: 8),
              const Center(
                child: Icon(
                  Icons.keyboard_double_arrow_down_rounded,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              // 도착역 검색
              Autocomplete<SubwayStation>(
                initialValue: TextEditingValue(
                  text: arrivalStation == null
                      ? ''
                      : _stationLabel(arrivalStation!),
                ),
                displayStringForOption: _stationLabel,
                optionsBuilder: (textEditingValue) {
                  if (_arrivalJustSelected) {
                    _arrivalJustSelected = false;
                    return const Iterable<SubwayStation>.empty();
                  }
                  return _filterStations(textEditingValue.text);
                },
                onSelected: updateArrivalStation,
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
                          onSubmitted: (value) {
                            _submitArrivalQuery(value);
                            onFieldSubmitted();
                          },
                          decoration: InputDecoration(
                            hintText: '도착역 검색 (예: 사당, 4호선)',
                            prefixIcon: const Icon(
                              Icons.location_on,
                              color: Colors.blueAccent,
                            ),
                            suffixIcon: controller.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      controller.clear();
                                      setState(() {
                                        arrivalStation = null;
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      );
                    },
                optionsViewBuilder: _buildOptionsList,
              ),

              if (departureStation != null) ...[
                // 실시간 도착 정보
                const SizedBox(height: 24),
                Row(
                  key: _infoSectionKey,
                  children: [
                    const Icon(Icons.access_time, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      '실시간 도착 정보',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      departureStation!.lineName,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isLoadingArrival)
                  const Center(child: CircularProgressIndicator())
                else if (_arrivalError != null)
                  Card(
                    color: Colors.red.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _arrivalError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  _buildArrivalCard(
                    direction: '상행 ↑',
                    current: upbound.isNotEmpty ? upbound[0] : null,
                    next: upbound.length > 1 ? upbound[1] : null,
                  ),
                  const SizedBox(height: 8),
                  _buildArrivalCard(
                    direction: '하행 ↓',
                    current: downbound.isNotEmpty ? downbound[0] : null,
                    next: downbound.length > 1 ? downbound[1] : null,
                  ),
                ],
                const SizedBox(height: 24),

                // 환승 및 도착지 연계 정보 (도착역 선택 시)
                if (arrivalStation != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.directions_subway, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        '환승 및 도착지 연계 정보',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                          // 환승 정보 (다른 노선일 때만)
                          if (departureStation!.lineName !=
                              arrivalStation!.lineName)
                            () {
                              final transferStationName = getTransferStation(
                                departureStation!,
                                arrivalStation!,
                              );
                              final transferStation = stations.firstWhere(
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
                                        size: 20,
                                      ),
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
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '빠른문: ${getFastExit(transferStation)}',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                ],
                              );
                            }(),
                          // 도착역 빠른 하차문
                          Row(
                            children: [
                              const Icon(
                                Icons.exit_to_app,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${arrivalStation!.stationName}역 빠른 하차',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '빠른문: ${getFastExit(arrivalStation!)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          // 도착역 연계 버스
                          Row(
                            children: [
                              const Icon(
                                Icons.bus_alert,
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${arrivalStation!.stationName}역 '
                                '${getExitForTransit(arrivalStation!)} 연계 버스',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final buses = getConnectedTransit(
                                arrivalStation!,
                              );
                              if (buses.isEmpty) {
                                return Text(
                                  '연계 버스 정보가 없습니다.',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                );
                              }
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: buses
                                    .map(
                                      (bus) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
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
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 탑승 위치 정보
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      '탑승 위치 정보',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.accessible, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text(
                                    '교통약자석',
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                ],
                              ),
                              content: const Text(
                                '• 위치: 1번 칸 1번 문, 10번 칸 4번 문\n'
                                '• 대상: 임산부, 노약자, 장애인\n'
                                '• 일반 승객은 이용을 자제해 주세요.',
                                style: TextStyle(fontSize: 14, height: 1.8),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('확인'),
                                ),
                              ],
                            ),
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
                                    Icon(
                                      Icons.pregnant_woman,
                                      color: Colors.blue,
                                    ),
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
                                SizedBox(height: 4),
                                Text(
                                  '탭하여 상세보기',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 11,
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
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.ac_unit, color: Colors.cyan),
                                  SizedBox(width: 8),
                                  Text(
                                    '약냉방칸',
                                    style: TextStyle(color: Colors.cyan),
                                  ),
                                ],
                              ),
                              content: const Text(
                                '• 위치: 4번 칸, 5번 칸\n'
                                '• 일반 칸보다 냉방을 약하게 운영\n'
                                '• 더위를 잘 타는 승객에게 비추천',
                                style: TextStyle(fontSize: 14, height: 1.8),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('확인'),
                                ),
                              ],
                            ),
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
                                SizedBox(height: 4),
                                Text(
                                  '탭하여 상세보기',
                                  style: TextStyle(
                                    color: Colors.cyan,
                                    fontSize: 11,
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

                // 전체 시간표 버튼
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
