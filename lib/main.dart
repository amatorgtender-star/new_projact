import 'package:flutter/material.dart';

// 우리가 만든 main_screen.dart를 불러옵니다.
import 'screens/main_screen.dart';

void main() {
  runApp(const SubwayApp());
}

// --- 메인 앱 ---
class SubwayApp extends StatelessWidget {
  const SubwayApp({super.key});

  Color getThemeColor() {
    int weekday = DateTime.now().weekday;
    if (weekday == DateTime.saturday) return Colors.blue;
    if (weekday == DateTime.sunday) return Colors.red;
    return Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '지하철 시간표 만들기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: getThemeColor(),
        appBarTheme: AppBarTheme(
          backgroundColor: getThemeColor(),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      // 분리된 파일의 MainScreen 위젯을 사용합니다.
      home: const MainScreen(),
    );
  }
}
