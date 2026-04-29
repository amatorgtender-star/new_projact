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
  StationWeather? _departureWeather;
  StationWeather? _arrivalWeather;
  List<ArrivalInfo> _arrivals = [];
  bool _isLoadingArrival = false;
  String? _arrivalError;
  Timer? _refreshTimer;

  List<ArrivalInfo> _arrivalStationArrivals = [];
  bool _isLoadingArrivalStation = false;
  String? _arrivalStationError;
  Timer? _arrivalStationRefreshTimer;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _infoSectionKey = GlobalKey();
  final GlobalKey _journeySectionKey = GlobalKey();
  final TextEditingController _departureController = TextEditingController();
  final TextEditingController _arrivalController = TextEditingController();
  final FocusNode _departureFocusNode = FocusNode();
  final FocusNode _arrivalFocusNode = FocusNode();

  String _stationLabel(SubwayStation station) {
    return '${station.stationName} (${station.lineName})';
  }

  Iterable<SubwayStation> _filterStations(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const Iterable<SubwayStation>.empty();
    }

    // 단어별로 분리 (예: "2호선 강남" -> ["2호선", "강남"])
    final words = normalizedQuery.split(RegExp(r'\s+'));

    final filtered = stations.where((station) {
      final name = station.stationName.toLowerCase();
      final line = station.lineName.toLowerCase();
      final label = _stationLabel(station).toLowerCase();

      // 모든 단어가 역 이름, 호선 또는 전체 레이블 중 하나에 포함되어야 함
      return words.every((word) {
        String wordWithoutYeok = word;
        if (wordWithoutYeok.length > 1 && wordWithoutYeok.endsWith('역')) {
          wordWithoutYeok = wordWithoutYeok.substring(
            0,
            wordWithoutYeok.length - 1,
          );
        }

        // 숫자 앞의 0 제거 (예: "02" -> "2")
        String wordNormalized = word;
        if (RegExp(r'^0+\d').hasMatch(wordNormalized)) {
          wordNormalized = wordNormalized.replaceFirst(RegExp(r'^0+'), '');
        }

        return name.contains(word) ||
            name.contains(wordWithoutYeok) ||
            line.contains(word) ||
            line.contains(wordNormalized) ||
            label.contains(word);
      });
    }).toList();

    // 정렬 우선순위:
    // 1. 역 이름이 검색어와 정확히 일치 (또는 '역'만 뺀 상태와 일치)
    // 2. 가나다순
    filtered.sort((a, b) {
      bool aExact =
          a.stationName == normalizedQuery ||
          (normalizedQuery.endsWith('역') &&
              normalizedQuery.length > 1 &&
              a.stationName ==
                  normalizedQuery.substring(0, normalizedQuery.length - 1));
      bool bExact =
          b.stationName == normalizedQuery ||
          (normalizedQuery.endsWith('역') &&
              normalizedQuery.length > 1 &&
              b.stationName ==
                  normalizedQuery.substring(0, normalizedQuery.length - 1));

      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;

      int nameCompare = a.stationName.compareTo(b.stationName);
      if (nameCompare != 0) return nameCompare;
      return a.lineName.compareTo(b.lineName);
    });

    return filtered;
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
    _fetchWeather();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _arrivalStationRefreshTimer?.cancel();
    _scrollController.dispose();
    _departureController.dispose();
    _arrivalController.dispose();
    _departureFocusNode.dispose();
    _arrivalFocusNode.dispose();
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

  void updateDepartureStation(SubwayStation newStation) {
    _departureController.text = _stationLabel(newStation);
    _departureFocusNode.unfocus();
    setState(() {
      departureStation = newStation;
      _arrivals = [];
      _arrivalError = null;
      _departureWeather = null;
    });
    _refreshTimer?.cancel();
    _loadArrival(newStation);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadArrival(newStation),
    );
    WeatherService.fetchStationWeather(newStation.stationName).then((w) {
      if (mounted && w != null) setState(() => _departureWeather = w);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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

  Future<void> _loadArrivalStationInfo(SubwayStation station) async {
    setState(() {
      _isLoadingArrivalStation = true;
      _arrivalStationError = null;
    });
    try {
      final arrivals = await SubwayApiService.fetchRealtimeArrival(
        station.stationName,
      );
      if (mounted) {
        setState(() {
          _arrivalStationArrivals = arrivals;
          _isLoadingArrivalStation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _arrivalStationError = e.toString();
          _isLoadingArrivalStation = false;
        });
      }
    }
  }

  void updateArrivalStation(SubwayStation newStation) {
    _arrivalController.text = _stationLabel(newStation);
    _arrivalFocusNode.unfocus();
    setState(() {
      arrivalStation = newStation;
      _arrivalStationArrivals = [];
      _arrivalStationError = null;
      _arrivalWeather = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();

    // 도착역 선택 시 환승 정보를 확인하기 위해 아래로 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _journeySectionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });

    _arrivalStationRefreshTimer?.cancel();
    _loadArrivalStationInfo(newStation);
    _arrivalStationRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadArrivalStationInfo(newStation),
    );
    WeatherService.fetchStationWeather(newStation.stationName).then((w) {
      if (mounted && w != null) setState(() => _arrivalWeather = w);
    });
  }

  Widget _buildStationSearch({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData prefixIcon,
    required Color iconColor,
    required void Function(SubwayStation) onSelected,
  }) {
    return RawAutocomplete<SubwayStation>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: _stationLabel,
      optionsBuilder: (value) {
        return _filterStations(value.text);
      },

      onSelected: onSelected,
      fieldViewBuilder:
          (context, fieldController, fieldFocusNode, onSubmitted) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: fieldController,
                focusNode: fieldFocusNode,
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
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 32,
                maxHeight: 240,
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
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
    ArrivalInfo? third,
    Color? color,
  }) {
    final trains = [
      if (current != null) (label: '1번째', info: current),
      if (next != null) (label: '2번째', info: next),
      if (third != null) (label: '3번째', info: third),
    ];

    final themeColor = color ?? Colors.blue;

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: themeColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                direction,
                style: TextStyle(
                  color: themeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (trains.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    '정보 없음',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              )
            else
              ...trains.asMap().entries.map((entry) {
                final i = entry.key;
                final t = entry.value;
                final isFirst = i == 0;
                return Padding(
                  padding: EdgeInsets.only(bottom: isFirst ? 8.0 : 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${t.info.destination}행',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isFirst ? 16 : 13,
                                fontWeight: isFirst
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          Text(
                            t.label,
                            style: TextStyle(
                              fontSize: 10,
                              color: isFirst ? themeColor : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.info.remainingText,
                        style: TextStyle(
                          fontSize: isFirst ? 18 : 14,
                          fontWeight: isFirst
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isFirst
                              ? Colors.black87
                              : Colors.grey.shade700,
                        ),
                      ),
                      if (isFirst)
                        Text(
                          t.info.currentTrainStatus,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                );
              }),
          ],
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
              _buildStationSearch(
                controller: _departureController,
                focusNode: _departureFocusNode,
                hintText: '출발역 검색 (예: 강남, 2호선)',
                prefixIcon: Icons.search,
                iconColor: Colors.grey,
                onSelected: updateDepartureStation,
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
              _buildStationSearch(
                controller: _arrivalController,
                focusNode: _arrivalFocusNode,
                hintText: '도착역 검색 (예: 사당, 4호선)',
                prefixIcon: Icons.location_on,
                iconColor: Colors.blueAccent,
                onSelected: updateArrivalStation,
              ),

              if (departureStation != null) ...[
                const SizedBox(height: 24),
                // --- 출발역 실시간 정보 ---
                Row(
                  key: _infoSectionKey,
                  children: [
                    const Icon(Icons.access_time, color: Colors.blue, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      '실시간 도착 정보 (출발)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      departureStation!.lineName,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    if (_departureWeather != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_departureWeather!.icon} ${_departureWeather!.temp}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
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
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildArrivalCard(
                          direction: '상행 ↑',
                          current: upbound.isNotEmpty ? upbound[0] : null,
                          next: upbound.length > 1 ? upbound[1] : null,
                          third: upbound.length > 2 ? upbound[2] : null,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildArrivalCard(
                          direction: '하행 ↓',
                          current: downbound.isNotEmpty ? downbound[0] : null,
                          next: downbound.length > 1 ? downbound[1] : null,
                          third: downbound.length > 2 ? downbound[2] : null,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],

                // --- 도착역 정보 및 환승/연계 정보 (도착역 선택 시) ---
                if (arrivalStation != null) ...[
                  const SizedBox(height: 32),
                  Row(
                    key: _journeySectionKey,
                    children: [
                      const Icon(
                        Icons.directions_subway,
                        color: Colors.green,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '실시간 도착 정보 (도착지)',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        arrivalStation!.lineName,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      if (_arrivalWeather != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_arrivalWeather!.icon} ${_arrivalWeather!.temp}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingArrivalStation)
                    const Center(child: CircularProgressIndicator())
                  else if (_arrivalStationError != null)
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
                                _arrivalStationError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Builder(
                      builder: (context) {
                        final aUp = _arrivalStationArrivals
                            .where(
                              (a) =>
                                  a.updnLine.contains('상행') ||
                                  a.updnLine.contains('내선'),
                            )
                            .toList();
                        final aDown = _arrivalStationArrivals
                            .where(
                              (a) =>
                                  a.updnLine.contains('하행') ||
                                  a.updnLine.contains('외선'),
                            )
                            .toList();
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildArrivalCard(
                                direction: '상행 ↑',
                                current: aUp.isNotEmpty ? aUp[0] : null,
                                next: aUp.length > 1 ? aUp[1] : null,
                                third: aUp.length > 2 ? aUp[2] : null,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildArrivalCard(
                                direction: '하행 ↓',
                                current: aDown.isNotEmpty ? aDown[0] : null,
                                next: aDown.length > 1 ? aDown[1] : null,
                                third: aDown.length > 2 ? aDown[2] : null,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 32),
                  const Row(
                    children: [
                      Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                      SizedBox(width: 8),
                      Text(
                        '환승 및 하차/연계 정보',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade100),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 환승 정보 (다른 노선일 때만)
                          if (departureStation!.lineName !=
                              arrivalStation!.lineName) ...[
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
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '환승역: $transferStationName',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                      if (transferStationName != '환승역 미확인')
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            '빠른문: ${getFastExit(transferStation)}',
                                            style: TextStyle(
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Divider(height: 32, thickness: 1),
                                ],
                              );
                            }(),
                          ],
                          // 도착역 빠른 하차문
                          Row(
                            children: [
                              const Icon(
                                Icons.exit_to_app,
                                color: Colors.blue,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${arrivalStation!.stationName}역 빠른 하차',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '빠른문: ${getFastExit(arrivalStation!)}',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32, thickness: 1),
                          // 도착역 연계 버스
                          Row(
                            children: [
                              const Icon(
                                Icons.bus_alert,
                                color: Colors.orange,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${arrivalStation!.stationName}역 연계 버스',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Builder(
                            builder: (context) {
                              final busMap = getConnectedTransit(
                                arrivalStation!,
                              );
                              if (busMap.isEmpty) {
                                return const Text(
                                  '연계 버스 정보가 없습니다.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 18,
                                  ),
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: busMap.entries.map((entry) {
                                  final exitName = entry.key;
                                  final buses = entry.value;

                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 16.0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '• $exitName',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: buses.map((bus) {
                                            Color busColor = Colors.blue;
                                            if (bus.contains('광역'))
                                              busColor = Colors.red;
                                            if (bus.contains('지선'))
                                              busColor = Colors.green;
                                            if (bus.contains('마을'))
                                              busColor = Colors.orange;

                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: busColor.withOpacity(
                                                  0.05,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: busColor.withOpacity(
                                                    0.2,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                bus,
                                                style: TextStyle(
                                                  color: busColor,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  Card(
                    color: Colors.grey.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          '도착역을 선택하시면 환승 및 연계 정보를 확인할 수 있습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                // --- 탑승 위치 팁 ---
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 24),
                    SizedBox(width: 8),
                    Text(
                      '지하철 이용 팁',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTipCard(
                        icon: Icons.accessible,
                        title: '교통약자석',
                        subtitle: '1-1, 10-4 구역',
                        color: Colors.blue,
                        onTap: () => _showTipDialog(
                          context,
                          '교통약자석 정보',
                          '휠체어 전용 공간 및 교통약자(고령자, 임산부, 장애인 등)를 위한 지정 좌석입니다.\n\n주요 위치: 1-1, 10-4 구역 부근',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTipCard(
                        icon: Icons.ac_unit,
                        title: '약냉방칸',
                        subtitle: '4, 5번 칸 부근',
                        color: Colors.cyan,
                        onTap: () => _showTipDialog(
                          context,
                          '약냉방칸 정보',
                          '냉방 강도가 일반 칸보다 낮게 설정되어 있어, 추위를 많이 느끼시는 분들이 이용하기 좋은 칸입니다.\n\n주요 위치: 4번, 5번 칸 (노선별 상이)',
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
                // --- 전체 시간표 버튼 ---
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${departureStation!.stationName}역 및 전국 지하철 시간표 데이터를 최신으로 동기화합니다.',
                        ),
                        duration: const Duration(seconds: 2),
                        backgroundColor: Colors.blue.shade700,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TimetableScreen(station: departureStation!),
                      ),
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month),
                      SizedBox(width: 10),
                      Text(
                        '전체 시간표 보기',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: color.withOpacity(0.05),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                '자세히 보기',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTipDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
