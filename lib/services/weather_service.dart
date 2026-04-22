import 'dart:convert';
import 'package:http/http.dart' as http;

class StationWeather {
  final String temp;
  final String icon;
  final String description;

  const StationWeather({
    required this.temp,
    required this.icon,
    required this.description,
  });

  @override
  String toString() => '$icon $temp';
}

class WeatherService {
  static final Map<String, StationWeather> _cache = {};

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

  static Future<StationWeather?> fetchStationWeather(String stationName) async {
    if (_cache.containsKey(stationName)) return _cache[stationName];

    try {
      final geoUri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent("$stationName역 서울 지하철")}'
        '&format=json&limit=1',
      );
      final geoRes = await http.get(
        geoUri,
        headers: {'User-Agent': 'SubwayApp/1.0'},
      );
      if (geoRes.statusCode != 200) return null;
      final geoList = json.decode(geoRes.body) as List;
      if (geoList.isEmpty) return null;

      final lat = geoList[0]['lat'] as String;
      final lon = geoList[0]['lon'] as String;

      final weatherUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current_weather=true',
      );
      final weatherRes = await http.get(weatherUri);
      if (weatherRes.statusCode != 200) return null;

      final data = json.decode(weatherRes.body) as Map<String, dynamic>;
      final cw = data['current_weather'] as Map<String, dynamic>;
      final temp = cw['temperature'];
      final code = (cw['weathercode'] as num).toInt();

      final weather = StationWeather(
        temp: '$temp°C',
        icon: _weatherIcon(code),
        description: _weatherDescription(code),
      );
      _cache[stationName] = weather;
      return weather;
    } catch (_) {
      return null;
    }
  }

  static String _weatherIcon(int code) {
    if (code == 0) return '☀️';
    if (code <= 3) return '⛅';
    if (code <= 48) return '🌫️';
    if (code <= 55) return '🌦️';
    if (code <= 65) return '🌧️';
    if (code <= 77) return '❄️';
    if (code <= 82) return '🌧️';
    if (code <= 86) return '🌨️';
    return '⛈️';
  }

  static String _weatherDescription(int code) {
    if (code == 0) return '맑음';
    if (code <= 2) return '구름 조금';
    if (code == 3) return '흐림';
    if (code <= 48) return '안개';
    if (code <= 55) return '이슬비';
    if (code <= 65) return '비';
    if (code <= 77) return '눈';
    if (code <= 82) return '소나기';
    if (code <= 86) return '눈보라';
    return '뇌우';
  }
}
