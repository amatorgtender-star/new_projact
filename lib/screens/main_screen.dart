import 'dart:async';
import 'package:flutter/material.dart';

import '../models/subway_models.dart';
import '../data/station_data.dart';
import '../services/subway_api_service.dart';
import '../services/weather_service.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    try {
      final temp = await WeatherService.fetchTemperature();
      if (mounted) setState(() => weatherTemp = temp);
    } catch (e) {
      debugPrint('날씨 정보 로드 실패: $e');
    }
  }

  Future<void> _loadArrival(SubwayStation station) async {
    setState(() {
      _isLoadingArrival = true;
      _arrivalError = null;
    });
    try {
      final arrivals = await SubwayApiService.fetchRealtimeArrival(station.stationName);
      if (mounted) {
        setState(() {
          _arrivals = arrivals;
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
<<<<<<< HEAD
    _arrivalJustSelected = true;
    setState(() {
      arrivalStation = newStation;
    });
=======
    setState(() => arrivalStation = newStation);
>>>>>>> claude/reverent-noether-810420
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Widget _buildStationSearch({
    required SubwayStation? currentStation,
    required String hintText,
    required IconData prefixIcon,
    required Color iconColor,
    required void Function(SubwayStation) onSelected,
  }) {
    return Autocomplete<SubwayStation>(
      initialValue: TextEditingValue(text: currentStation?.stationName ?? ''),
      displayStringForOption: (s) => s.stationName,
      optionsBuilder: (value) {
        if (value.text.isEmpty) return const Iterable<SubwayStation>.empty();
        return stations.where(
          (s) =>
              s.stationName.contains(value.text) ||
              s.lineName.contains(value.text),
        );
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onSubmitted: (_) => onSubmitted(),
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(prefixIcon, color: iconColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelect, options) {
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
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final s = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      s.stationName,
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
                        s.lineName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    onTap: () => onSelect(s),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildArrivalCard({
    required String direction,
    required ArrivalInfo? current,
    ArrivalInfo? next,
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
                  '${current?.destination ?? '-'}행',
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
<<<<<<< HEAD
                  currentStatus,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
=======
                  current?.remainingText ?? '정보 없음',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
>>>>>>> claude/reverent-noether-810420
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '다음 열차',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    Text(
<<<<<<< HEAD
                      nextStatus,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
=======
                      next?.remainingText ?? '-',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
>>>>>>> claude/reverent-noether-810420
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    final upbound = _arrivals
        .where((a) => a.updnLine.contains('상행') || a.updnLine.contains('내선'))
        .toList();
    final downbound = _arrivals
        .where((a) => a.updnLine.contains('하행') || a.updnLine.contains('외선'))
        .toList();

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
<<<<<<< HEAD
              // 출발역 검색
              Autocomplete<SubwayStation>(
                initialValue: TextEditingValue(text: departureStation?.stationName ?? ''),
                displayStringForOption: (option) => option.stationName,
                optionsBuilder: (textEditingValue) {
                  if (_departureJustSelected) {
                    _departureJustSelected = false;
                    return const Iterable<SubwayStation>.empty();
                  }
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<SubwayStation>.empty();
                  }
                  return stations.where((s) =>
                      s.stationName.contains(textEditingValue.text) ||
                      s.lineName.contains(textEditingValue.text));
                },
                onSelected: updateDepartureStation,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: controller,
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
                optionsViewBuilder: _buildOptionsList,
=======
              _buildStationSearch(
                currentStation: departureStation,
                hintText: '출발역 검색 (예: 강남, 2호선)',
                prefixIcon: Icons.search,
                iconColor: Colors.grey,
                onSelected: updateDepartureStation,
>>>>>>> claude/reverent-noether-810420
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
<<<<<<< HEAD
              // 도착역 검색
              Autocomplete<SubwayStation>(
                initialValue: TextEditingValue(text: arrivalStation?.stationName ?? ''),
                displayStringForOption: (option) => option.stationName,
                optionsBuilder: (textEditingValue) {
                  if (_arrivalJustSelected) {
                    _arrivalJustSelected = false;
                    return const Iterable<SubwayStation>.empty();
                  }
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<SubwayStation>.empty();
                  }
                  return stations.where((s) =>
                      s.stationName.contains(textEditingValue.text) ||
                      s.lineName.contains(textEditingValue.text));
                },
                onSelected: updateArrivalStation,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onSubmitted: (_) => onFieldSubmitted(),
                      decoration: const InputDecoration(
                        hintText: '도착역 검색 (예: 사당, 4호선)',
                        prefixIcon: Icon(Icons.location_on, color: Colors.blueAccent),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  );
                },
                optionsViewBuilder: _buildOptionsList,
              ),

              if (departureStation != null) ...[
                // 실시간 도착 정보
                const SizedBox(height: 24),
=======
              _buildStationSearch(
                currentStation: arrivalStation,
                hintText: '도착역 검색 (예: 사당, 4호선)',
                prefixIcon: Icons.location_on,
                iconColor: Colors.blueAccent,
                onSelected: updateArrivalStation,
              ),

              if (departureStation != null) ...[
                if (arrivalStation != null) ...[
                  const SizedBox(height: 24),
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
                                          borderRadius:
                                              BorderRadius.circular(8),
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

                          Row(
                            children: [
                              const Icon(
                                Icons.bus_alert,
                                color: Colors.orange,
                                size: 20,
                              ),
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
                          Builder(
                            builder: (context) {
                              final buses = getConnectedTransit(arrivalStation!);
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
                                          borderRadius:
                                              BorderRadius.circular(20),
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
                ],

                const SizedBox(height: 24),

>>>>>>> claude/reverent-noether-810420
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
                if (_isLoadingArrival)
                  const Center(child: CircularProgressIndicator())
                else if (_arrivalError != null)
                  Card(
                    color: Colors.red.shade50,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_arrivalError!,
                                style: const TextStyle(color: Colors.red)),
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

<<<<<<< HEAD
                // 환승 및 도착지 연계 정보 (도착역 선택 시)
                if (arrivalStation != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.directions_subway, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        '환승 및 도착지 연계 정보',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          if (departureStation!.lineName != arrivalStation!.lineName)
                            () {
                              final transferStationName = getTransferStation(
                                  departureStation!, arrivalStation!);
                              final transferStation = stations.firstWhere(
                                (s) => s.stationName == transferStationName,
                                orElse: () => arrivalStation!,
                              );
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.transfer_within_a_station,
                                          color: Colors.green, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        '환승역: $transferStationName',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 15),
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
                                              fontSize: 12),
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
                              const Icon(Icons.exit_to_app,
                                  color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${arrivalStation!.stationName}역 빠른 하차',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
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
                                  '빠른문: ${getFastExit(arrivalStation!)}',
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          // 도착역 연계 버스
                          Row(
                            children: [
                              const Icon(Icons.bus_alert,
                                  color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${arrivalStation!.stationName}역 '
                                '${getExitForTransit(arrivalStation!)} 연계 버스',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final buses = getConnectedTransit(arrivalStation!);
                              if (buses.isEmpty) {
                                return Text(
                                  '연계 버스 정보가 없습니다.',
                                  style: TextStyle(
                                      color: Colors.grey.shade600, fontSize: 13),
                                );
                              }
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: buses
                                    .map((bus) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(20),
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
=======
>>>>>>> claude/reverent-noether-810420
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.blue.shade50,
                        elevation: 0,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
<<<<<<< HEAD
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.accessible, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('교통약자석',
                                      style: TextStyle(color: Colors.blue)),
                                ],
=======
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '교통약자석은 1-1, 10-4 구역에 위치해 있습니다.',
                                ),
                                duration: Duration(seconds: 2),
>>>>>>> claude/reverent-noether-810420
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
                                      fontSize: 13),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '탭하여 상세보기',
                                  style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 11),
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
                            borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
<<<<<<< HEAD
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.ac_unit, color: Colors.cyan),
                                  SizedBox(width: 8),
                                  Text('약냉방칸',
                                      style: TextStyle(color: Colors.cyan)),
                                ],
=======
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('약냉방칸은 4번, 5번 칸에 위치해 있습니다.'),
                                duration: Duration(seconds: 2),
>>>>>>> claude/reverent-noether-810420
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
                                      fontSize: 13),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '탭하여 상세보기',
                                  style: TextStyle(
                                      color: Colors.cyan,
                                      fontSize: 11),
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

<<<<<<< HEAD
                // 전체 시간표 버튼
=======
>>>>>>> claude/reverent-noether-810420
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
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
                        color: Colors.white),
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
