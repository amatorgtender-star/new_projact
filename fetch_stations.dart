import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

void main() async {
  final url = Uri.parse('http://openapi.seoul.go.kr:8088/416d7254536774653131334f41454d51/json/SearchSTNBySubwayLineInfo/1/1000/');
  final response = await http.get(url);
  final data = json.decode(response.body);
  final rows = data['SearchSTNBySubwayLineInfo']['row'] as List;

  final Map<String, List<Map<String, String>>> stationsByLine = {};

  for (var row in rows) {
    String lineNum = row['LINE_NUM'] as String;
    // Remove leading '0' from line name like '01호선' -> '1호선'
    if (lineNum.startsWith('0') && lineNum.length > 2) {
      lineNum = lineNum.substring(1);
    }
    String stationName = row['STATION_NM'] as String;
    String stationCd = row['STATION_CD'] as String;
    
    stationsByLine.putIfAbsent(lineNum, () => []);
    stationsByLine[lineNum]!.add({
      'name': stationName,
      'code': stationCd,
    });
  }

  // Generate Dart code
  final buffer = StringBuffer();
  buffer.writeln('// Auto-generated stations list');
  buffer.writeln('const List<SubwayStation> stations = [');
  
  for (var entry in stationsByLine.entries) {
    buffer.writeln('  // ${entry.key}');
    for (var station in entry.value) {
      buffer.writeln('  SubwayStation(stationName: \'${station['name']}\', lineName: \'${entry.key}\', stationCode: \'${station['code']}\'),');
    }
    buffer.writeln('');
  }
  
  buffer.writeln('];');
  
  await File('generated_stations.dart').writeAsString(buffer.toString());
  print('Done! Generated ${rows.length} stations in generated_stations.dart');
}
