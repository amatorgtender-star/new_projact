import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final String apiKey = '416d7254536774653131334f41454d51';
  int start = 1;
  int pageSize = 1000;
  
  final url = Uri.parse('http://openapi.seoul.go.kr:8088/$apiKey/json/SearchSTNBySubwayLineInfo/$start/${start + pageSize - 1}/');
  
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final service = data['SearchSTNBySubwayLineInfo'];
      if (service != null) {
        final rows = service['row'] as List?;
        if (rows != null) {
          final Set<String> lines = {};
          for (var row in rows) {
            lines.add(row['LINE_NUM']);
          }
          print('Lines found: ${lines.toList()}');
          print('Total stations: ${rows.length}');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
