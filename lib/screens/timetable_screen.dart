import 'package:flutter/material.dart';
import '../models/subway_models.dart';
import '../data/dummy_data.dart';

// --- 2. 전체 시간표 화면 ---
class TimetableScreen extends StatefulWidget {
  final SubwayStation station;

  const TimetableScreen({super.key, required this.station});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late List<TrainSchedule> upSchedules;
  late List<TrainSchedule> downSchedules;

  @override
  void initState() {
    super.initState();
    upSchedules = generateTimetable(widget.station, 'up');
    downSchedules = generateTimetable(widget.station, 'down');
  }

  Widget _buildScheduleList(List<TrainSchedule> schedules) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: schedules.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 4,
          ),
          leading: Text(
            schedule.time,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          title: Text(
            '${schedule.destination}행',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('${schedule.type}열차'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: schedule.type == '급행'
                  ? Colors.red.shade50
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              schedule.type,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: schedule.type == '급행'
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.station.stationName}역 시간표',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
        body: TabBarView(
          children: [
            _buildScheduleList(upSchedules),
            _buildScheduleList(downSchedules),
          ],
        ),
      ),
    );
  }
}
