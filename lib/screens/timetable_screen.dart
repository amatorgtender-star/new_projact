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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        ),
        SubwayApiService.fetchTimetable(
          widget.station.stationCode,
          direction: 2,
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: s.type == '급행'
                  ? Colors.red.shade50
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              s.type,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: s.type == '급행'
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.station.stationName}역 시간표',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTimetable,
            tooltip: '새로고침',
          ),
        ],
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
      body: isLoading
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
                        Text(
                          '시간표를 불러오지 못했습니다.',
                          style: const TextStyle(
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
    );
  }
}
