import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static Future<String> fetchTemperature() async {
    final response = await http.get(
      Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=37.5665&longitude=126.9780&current_weather=true',
      ),
    );
    if (response.statusCode != 200) return '';
    final data = json.decode(response.body);
    return "${data['current_weather']['temperature']}°C";
  }
}
