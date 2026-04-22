import 'dart:async';
import 'package:flutter/material.dart';
import '../models/subway_models.dart';
import '../services/subway_api_service.dart';

class TimetableScreen extends StatefulWidget {
  final SubwayStation station;

  const TimetableScreen({super.key, required this.station});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _upScrollController = ScrollController();
  final ScrollController _downScrollController = ScrollController();

  List<TrainSchedule> upSchedules = [];
  List<TrainSchedule> downSchedules = [];
  List<ArrivalInfo> realtimeArrivals = [];
  bool isLoading = true;
  bool isRefreshingRealtime = false;
  String? error;
  int _dayType = 1; // 1: 평일, 2: 토요일, 3: 일/공휴일

  // 현재 시간 기반 다음 열차 인덱스
  int? upNextIndex;
  int? downNextIndex;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 현재 요일에 맞춰 초기 값 설정
    final now = DateTime.now();
    final weekday = now.weekday;
    if (weekday == DateTime.saturday) {
      _dayType = 2;
    } else if (weekday == DateTime.sunday) {
      _dayType = 3;
    } else {
      _dayType = 1;
    }

    _loadTimetable();

    // 30초마다 실시간 정보 및 다음 열차 위치 갱신
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _updateRealtimeAndIndices();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _upScrollController.dispose();
    _downScrollController.dispose();
    super.dispose();
  }

  Future<void> _updateRealtimeAndIndices() async {
    if (isRefreshingRealtime) return;

    try {
      setState(() => isRefreshingRealtime = true);

      final arrivals = await SubwayApiService.fetchRealtimeArrival(
        widget.station.stationName,
      );

      if (mounted) {
        setState(() {
          realtimeArrivals = arrivals;
          _calculateNextIndices();
          isRefreshingRealtime = false;
        });
      }
    } catch (e) {
      debugPrint('실시간 정보 갱신 실패: $e');
      if (mounted) {
        setState(() {
          _calculateNextIndices();
          isRefreshingRealtime = false;
        });
      }
    }
  }

  Future<void> _loadTimetable() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        SubwayApiService.fetchTimetable(
          widget.station.stationCode,
          direction: 1,
          dayType: _dayType,
        ),
        SubwayApiService.fetchTimetable(
          widget.station.stationCode,
          direction: 2,
          dayType: _dayType,
        ),
        SubwayApiService.fetchTimetable(
          widget.station.stationCode,
          direction: 3,
          dayType: _dayType,
        ),
        SubwayApiService.fetchRealtimeArrival(widget.station.stationName),
      ]);

      if (mounted) {
        setState(() {
          upSchedules = results[0] as List<TrainSchedule>;
          downSchedules = results[1] as List<TrainSchedule>;
          realtimeArrivals = results[2] as List<ArrivalInfo>;
          _calculateNextIndices();
          isLoading = false;
        });

        // 데이터 로드 후 현재 시간으로 스크롤 (약간의 딜레이 필요)
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToCurrentTime();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  void _calculateNextIndices() {
    final now = DateTime.now();
    final currentTimeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // 오늘 요일과 선택된 요일이 같을 때만 다음 열차 계산
    final todayWeekday = now.weekday;
    int todayDayType = 1;
    if (todayWeekday == DateTime.saturday) {
      todayDayType = 2;
    } else if (todayWeekday == DateTime.sunday) {
      todayDayType = 3;
    }

    if (_dayType == todayDayType) {
      upNextIndex = upSchedules.indexWhere(
        (s) => s.time.compareTo(currentTimeStr) >= 0,
      );
      downNextIndex = downSchedules.indexWhere(
        (s) => s.time.compareTo(currentTimeStr) >= 0,
      );

      if (upNextIndex == -1 && upSchedules.isNotEmpty) {
        upNextIndex = null;
      }
      if (downNextIndex == -1 && downSchedules.isNotEmpty) {
        downNextIndex = null;
      }
    } else {
      upNextIndex = null;
      downNextIndex = null;
    }
  }

  void _scrollToCurrentTime() {
    const double itemHeight = 84.0; // ListTile 대략적 높이

    if (upNextIndex != null &&
        upNextIndex! > 2 &&
        _upScrollController.hasClients) {
      _upScrollController.animateTo(
        (upNextIndex! - 1) * itemHeight,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }

    if (downNextIndex != null &&
        downNextIndex! > 2 &&
        _downScrollController.hasClients) {
      _downScrollController.animateTo(
        (downNextIndex! - 1) * itemHeight,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Color _getDayColor() {
    switch (_dayType) {
      case 2:
        return Colors.blue.shade700;
      case 3:
        return Colors.red.shade700;
      default:
        return Colors.black87;
    }
  }

  String _getDayText() {
    switch (_dayType) {
      case 2:
        return '토요일';
      case 3:
        return '일/공휴일';
      default:
        return '평일';
    }
  }

  Widget _buildScheduleList(
    List<TrainSchedule> schedules,
    int? nextIndex,
    ScrollController controller,
    String direction,
  ) {
    if (schedules.isEmpty) {
      return const Center(child: Text('시간표 데이터가 없습니다.'));
    }

    // 현재 방향에 맞는 실시간 정보 필터링
    final relevantArrivals = realtimeArrivals.where((a) {
      // API의 updnLine이 '상행', '하행', '내선', '외선' 등을 포함하는지 확인
      return a.updnLine.contains(direction) ||
          (direction == '상행' && a.updnLine.contains('내선')) ||
          (direction == '하행' && a.updnLine.contains('외선'));
    }).toList();

    return Column(
      children: [
        if (relevantArrivals.isNotEmpty &&
            _dayType == SubwayApiService.currentDayType())
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '실시간 열차 위치',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const Spacer(),
                    if (isRefreshingRealtime)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: relevantArrivals.map((arrival) {
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${arrival.destination}행',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              arrival.currentTrainStatus,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            controller: controller,
            padding: const EdgeInsets.all(16),
            itemCount: schedules.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final s = schedules[index];
              final isNext = index == nextIndex;

              return Container(
                decoration: isNext
                    ? BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 1.5,
                        ),
                      )
                    : null,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  leading: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        s.time,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isNext ? Colors.blue.shade800 : Colors.black87,
                        ),
                      ),
                      if (isNext)
                        const Text(
                          '다음 열차',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    '${s.destination}행',
                    style: TextStyle(
                      fontWeight: isNext ? FontWeight.bold : FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text('${s.type}열차'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: s.isExpress
                          ? Colors.red.shade50
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s.type,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: s.isExpress
                            ? Colors.red.shade700
                            : Colors.black54,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayColor = _getDayColor();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: dayColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.station.stationName}역 시간표',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              _getDayText(),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTimetable,
            tooltip: '새로고침',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: '상행'),
            Tab(text: '하행'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 요일 선택 바
          Container(
            color: dayColor,
            padding: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 1,
                  label: Text('평일'),
                  icon: Icon(Icons.calendar_today, size: 16),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('토요일'),
                  icon: Icon(Icons.weekend, size: 16),
                ),
                ButtonSegment(
                  value: 3,
                  label: Text('일/공휴일'),
                  icon: Icon(Icons.event, size: 16),
                ),
              ],
              selected: {_dayType},
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _dayType = newSelection.first;
                });
                _loadTimetable();
              },
              style: ButtonStyle(
                side: WidgetStateProperty.all(
                  const BorderSide(color: Colors.white24),
                ),
                backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                  states,
                ) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.white.withValues(alpha: 0.1);
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color?>((
                  states,
                ) {
                  if (states.contains(WidgetState.selected)) {
                    return dayColor;
                  }
                  return Colors.white;
                }),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '시간표를 불러오지 못했습니다.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error!,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _loadTimetable,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildScheduleList(
                        upSchedules,
                        upNextIndex,
                        _upScrollController,
                        '상행',
                      ),
                      _buildScheduleList(
                        downSchedules,
                        downNextIndex,
                        _downScrollController,
                        '하행',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
