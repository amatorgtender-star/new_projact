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

        return name.contains(word) ||
            name.contains(wordWithoutYeok) ||
            line.contains(word) ||
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

  SubwayStation? _resolveStationQuery(String query) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return null;
    }

    String searchName = normalizedQuery;
    if (searchName.length > 1 && searchName.endsWith('역')) {
      searchName = searchName.substring(0, searchName.length - 1);
    }

    // 1. 정확히 '역이름 (호선)' 형태와 일치하는지 확인
    for (final station in stations) {
      if (_stationLabel(station) == normalizedQuery) {
        return station;
      }
    }

    // 2. 역 이름만으로 검색 (중복될 경우 첫 번째 반환)
    for (final station in stations) {
      if (station.stationName == normalizedQuery ||
          station.stationName == searchName) {
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
    _departureController.text = newStation.stationName;
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
    _arrivalController.text = newStation.stationName;
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
      displayStringForOption: (s) => s.stationName,
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
  }) {
    final trains = [
      if (current != null) (label: '1번째', info: current),
      if (next != null) (label: '2번째', info: next),
      if (third != null) (label: '3번째', info: third),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                const SizedBox(width: 6),
                Text(
                  '${current?.destination ?? '-'}행',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
            if (trains.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '정보 없음',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              )
            else ...[
              const SizedBox(height: 10),
              ...trains.asMap().entries.map((entry) {
                final i = entry.key;
                final t = entry.value;
                final isFirst = i == 0;
                return Padding(
                  padding: EdgeInsets.only(bottom: isFirst ? 10.0 : 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isFirst
                              ? Colors.blue.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isFirst
                                ? Colors.blue.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.info.remainingText,
                              style: TextStyle(
                                fontSize: isFirst ? 20 : 15,
                                fontWeight: isFirst
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isFirst
                                    ? Colors.black87
                                    : Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.info.currentTrainStatus,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                ],

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
                            fontSize: 13,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
                    third: upbound.length > 2 ? upbound[2] : null,
                  ),
                  const SizedBox(height: 8),
                  _buildArrivalCard(
                    direction: '하행 ↓',
                    current: downbound.isNotEmpty ? downbound[0] : null,
                    next: downbound.length > 1 ? downbound[1] : null,
                    third: downbound.length > 2 ? downbound[2] : null,
                  ),
                ],
                const SizedBox(height: 24),
                // 환승 및 도착지 연계 정보
                if (arrivalStation != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    key: _journeySectionKey,
                    children: [
                      const Icon(
                        Icons.directions_subway,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '환승 및 도착지 연계 정보',
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
                          fontSize: 14,
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
                              fontSize: 13,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
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
                                style: const TextStyle(color: Colors.red),
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
                        return Column(
                          children: [
                            _buildArrivalCard(
                              direction: '상행 ↑',
                              current: aUp.isNotEmpty ? aUp[0] : null,
                              next: aUp.length > 1 ? aUp[1] : null,
                              third: aUp.length > 2 ? aUp[2] : null,
                            ),
                            const SizedBox(height: 8),
                            _buildArrivalCard(
                              direction: '하행 ↓',
                              current: aDown.isNotEmpty ? aDown[0] : null,
                              next: aDown.length > 1 ? aDown[1] : null,
                              third: aDown.length > 2 ? aDown[2] : null,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                ],

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
                  if (arrivalStation != null)
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
                                            fontSize: 20,
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
                                  '${arrivalStation!.stationName}${arrivalStation!.stationName.endsWith('역') ? '' : '역'} 빠른 하차',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
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
                                  '${arrivalStation!.stationName}${arrivalStation!.stationName.endsWith('역') ? '' : '역'} '
                                  '${getExitForTransit(arrivalStation!)} 연계 버스',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
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
                                      fontSize: 20,
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
                                              fontSize: 20,
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
                ] else
                  Card(
                    color: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          '도착역을 선택하시면 환승 및 연계 버스 정보를 확인할 수 있습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

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
