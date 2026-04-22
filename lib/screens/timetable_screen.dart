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

  List<TrainSchedule> upSchedules = [];
  List<TrainSchedule> downSchedules = [];
  bool isLoading = true;
  String? error;
  int _dayType = 1; // 1: 평일, 2: 토요일, 3: 일/공휴일

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 현재 요일에 맞춰 초기 값 설정
    final weekday = DateTime.now().weekday;
    if (weekday == DateTime.saturday) {
      _dayType = 2;
    } else if (weekday == DateTime.sunday) {
      _dayType = 3;
    } else {
      _dayType = 1;
    }
    
    _loadTimetable();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      ]);
      if (mounted) {
        setState(() {
          upSchedules = results[0];
          downSchedules = results[1];
          isLoading = false;
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

  Widget _buildScheduleList(List<TrainSchedule> schedules) {
    if (schedules.isEmpty) {
      return const Center(child: Text('시간표 데이터가 없습니다.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: schedules.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final s = schedules[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 4,
          ),
          leading: Text(
            s.time,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          title: Text(
            '${s.destination}행',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('${s.type}열차'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: s.type == '급행' ? Colors.red.shade50 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              s.type,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: s.type == '급행' ? Colors.red.shade700 : Colors.black54,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayColor = _getDayColor();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: dayColor,
        foregroundColor: Colors.white,
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
          tabs: [
            Tab(text: '상행'),
            Tab(text: '하행'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 요일 선택 바
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 1,
                  label: Text('평일'),
                  icon: Icon(Icons.calendar_today),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('토요일'),
                  icon: Icon(Icons.weekend),
                ),
                ButtonSegment(
                  value: 3,
                  label: Text('일/공휴일'),
                  icon: Icon(Icons.event),
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
                side: WidgetStateProperty.all(BorderSide(color: dayColor)),
                backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                  (states) {
                    if (states.contains(WidgetState.selected)) {
                      return dayColor.withOpacity(0.1);
                    }
                    return null;
                  },
                ),
                foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                  (states) {
                    if (states.contains(WidgetState.selected)) {
                      return dayColor;
                    }
                    return Colors.grey;
                  },
                ),
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
                          _buildScheduleList(upSchedules),
                          _buildScheduleList(downSchedules),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
