import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = '416d7254536774653131334f41454d51';
  const stationCode = '0158'; // 청량리 1호선
  const dayType = '1'; // 평일
  
  // Test both directions
  for (var direction in ['1', '2']) {
    print('\n--- Direction $direction ---');
    final url = 'http://openapi.seoul.go.kr:8088/$apiKey/json/SearchSTNTimeTableByIDService/1/100/$stationCode/$dayType/$direction';
    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      final service = data['SearchSTNTimeTableByIDService'];
      if (service != null) {
        final rows = service['row'] as List;
        // Filter rows between 10:00 and 11:00 for comparison with screenshot
        final filteredRows = rows.where((row) {
          final arrivalTime = row['ARRIVETIME']?.toString() ?? '';
          final departureTime = row['LEFTTIME']?.toString() ?? '';
          return arrivalTime.startsWith('10:') || departureTime.startsWith('10:');
        }).toList();
        
        for (var row in filteredRows) {
          print('Time: ${row['ARRIVETIME']} / ${row['LEFTTIME']}, Dest: ${row['SUBWAYENAME']}, Express: ${row['EXPRESS_YN']}, Direct: ${row['DIRECT_YN']}');
        }
      } else {
        print('No data for direction $direction');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
