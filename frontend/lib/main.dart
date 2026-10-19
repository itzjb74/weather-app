import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:weather_svg_icons/weather_svg_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const WeatherApp());

String get baseUrl {
  return 'https://weather-app-umber-delta-52.vercel.app';
}

// -----------------------------------------------------------
// App Root (Handles Theme State)
// -----------------------------------------------------------
class WeatherApp extends StatefulWidget {
  const WeatherApp({super.key});

  @override
  State<WeatherApp> createState() => _WeatherAppState();
}

class _WeatherAppState extends State<WeatherApp> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: WeatherScreen(
        isDarkMode: _isDarkMode,
        onThemeChanged: (bool isDark) {
          setState(() {
            _isDarkMode = isDark;
          });
        },
      ),
    );
  }
}

// -----------------------------------------------------------
// Weather Data Models
// -----------------------------------------------------------
class Weather {
  final String city;
  final String country;
  final double temperature;
  final double feelsLike;
  final double tempMin;
  final double tempMax;
  final int humidity;
  final int pressure;
  final String description;
  final double windSpeed;
  final int windDeg;
  final int visibility;
  final int sunrise;
  final int sunset;
  final int timezone;
  final String icon;

  Weather({
    required this.city,
    required this.country,
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.pressure,
    required this.description,
    required this.windSpeed,
    required this.windDeg,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
    required this.timezone,
    required this.icon,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      city: json['city'],
      country: json['country'],
      temperature: (json['temperature'] as num).toDouble(),
      feelsLike: (json['feels_like'] as num).toDouble(),
      tempMin: (json['temp_min'] as num).toDouble(),
      tempMax: (json['temp_max'] as num).toDouble(),
      humidity: json['humidity'],
      pressure: json['pressure'],
      description: json['description'],
      windSpeed: (json['wind_speed'] as num).toDouble(),
      windDeg: json['wind_deg'] ?? 0,
      visibility: json['visibility'] ?? 10000,
      sunrise: json['sunrise'],
      sunset: json['sunset'],
      timezone: json['timezone'] ?? 0,
      icon: json['icon'],
    );
  }
}

class ForecastDay {
  final String date;
  final double tempMin;
  final double tempMax;
  final String icon;
  final String description;

  ForecastDay({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.icon,
    required this.description,
  });

  factory ForecastDay.fromJson(Map<String, dynamic> json) {
    return ForecastDay(
      date: json['date'],
      tempMin: (json['temp_min'] as num).toDouble(),
      tempMax: (json['temp_max'] as num).toDouble(),
      icon: json['icon'],
      description: json['description'],
    );
  }
}

// -----------------------------------------------------------
// Main Screen
// -----------------------------------------------------------
class WeatherScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const WeatherScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final TextEditingController _controller = TextEditingController();
  Weather? _weather;
  List<ForecastDay>? _forecast;
  List<String> _searchHistory = [];
  bool _loading = false;
  String? _error;
  bool _isCelsius = true; // 👈 NEW: Celsius / Fahrenheit state

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchWeatherByLocation();
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _saveToHistory(String city) async {
    final formattedCity = city.trim().isNotEmpty
        ? city.trim()[0].toUpperCase() + city.trim().substring(1).toLowerCase()
        : city;

    if (_searchHistory.contains(formattedCity)) return;

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory.insert(0, formattedCity);
      if (_searchHistory.length > 5) {
        _searchHistory = _searchHistory.sublist(0, 5);
      }
    });
    await prefs.setStringList('search_history', _searchHistory);
  }

  Future<void> _fetchWeather() async {
    final city = _controller.text.trim();
    if (city.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _weather = null;
      _forecast = null;
    });

    try {
      final units = _isCelsius ? 'metric' : 'imperial'; // 👈 NEW
      final weatherUri = Uri.parse('$baseUrl/weather?city=$city&units=$units');
      final forecastUri = Uri.parse(
        '$baseUrl/forecast?city=$city&units=$units',
      );

      final responses = await Future.wait([
        http.get(weatherUri),
        http.get(forecastUri),
      ]);

      final weatherRes = responses[0];
      final forecastRes = responses[1];

      if (weatherRes.statusCode == 200 && forecastRes.statusCode == 200) {
        _saveToHistory(city);
        final weatherData = jsonDecode(weatherRes.body) as Map<String, dynamic>;
        final forecastData = jsonDecode(forecastRes.body) as List<dynamic>;

        setState(() {
          _weather = Weather.fromJson(weatherData);
          _forecast = forecastData.map((e) => ForecastDay.fromJson(e)).toList();
        });
      } else if (weatherRes.statusCode == 404) {
        setState(() => _error = 'City not found');
      } else {
        setState(() => _error = 'Failed to load weather data');
      }
    } catch (e) {
      setState(() => _error = 'Could not connect to server.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchWeatherByLocation() async {
    setState(() {
      _loading = true;
      _error = null;
      _weather = null;
      _forecast = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Location services are disabled.';
          _loading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission denied.';
          _loading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      final units = _isCelsius ? 'metric' : 'imperial'; // 👈 NEW
      final weatherUri = Uri.parse(
        '$baseUrl/weather?lat=${position.latitude}&lon=${position.longitude}&units=$units',
      );
      final forecastUri = Uri.parse(
        '$baseUrl/forecast?lat=${position.latitude}&lon=${position.longitude}&units=$units',
      );

      final responses = await Future.wait([
        http.get(weatherUri),
        http.get(forecastUri),
      ]);

      final weatherRes = responses[0];
      final forecastRes = responses[1];

      if (weatherRes.statusCode == 200 && forecastRes.statusCode == 200) {
        final weatherData = jsonDecode(weatherRes.body) as Map<String, dynamic>;
        final forecastData = jsonDecode(forecastRes.body) as List<dynamic>;

        setState(() {
          _weather = Weather.fromJson(weatherData);
          _forecast = forecastData.map((e) => ForecastDay.fromJson(e)).toList();
        });
      } else {
        setState(() => _error = 'Failed to load weather data');
      }
    } catch (e) {
      setState(() => _error = 'Could not get location: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _weather != null
        ? _gradientForTemp(_weather!.temperature, widget.isDarkMode)
        : widget.isDarkMode
        ? [Colors.blueGrey.shade900, Colors.black]
        : [Colors.blue.shade100, Colors.blue.shade300];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 👇 NEW: Celsius / Fahrenheit Toggle
          TextButton(
            onPressed: () {
              setState(() {
                _isCelsius = !_isCelsius;
              });
              if (_controller.text.isNotEmpty) {
                _fetchWeather();
              } else {
                _fetchWeatherByLocation();
              }
            },
            child: Text(
              _isCelsius ? '°C' : '°F',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          // Existing Dark Mode Toggle
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              widget.onThemeChanged(!widget.isDarkMode);
            },
            tooltip: 'Toggle Dark Mode',
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ---- Search Bar ----
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Enter city (e.g., London)',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onSubmitted: (_) => _fetchWeather(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _loading ? null : _fetchWeather,
                      icon: const Icon(Icons.search),
                      tooltip: 'Search by city',
                    ),
                    const SizedBox(width: 4),
                    IconButton.filled(
                      onPressed: _loading ? null : _fetchWeatherByLocation,
                      icon: const Icon(Icons.my_location),
                      tooltip: 'Use my location',
                    ),
                  ],
                ),

                // ---- Search History Chips ----
                if (_searchHistory.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 35,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _searchHistory.length,
                      itemBuilder: (context, index) {
                        final city = _searchHistory[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(city),
                            backgroundColor: widget.isDarkMode
                                ? Colors.white12
                                : Colors.white54,
                            side: BorderSide(
                              color: widget.isDarkMode
                                  ? Colors.white24
                                  : Colors.white,
                            ),
                            labelStyle: TextStyle(
                              color: widget.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            onPressed: () {
                              _controller.text = city;
                              _fetchWeather();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ---- Content Area ----
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (_weather != null && _forecast != null)
                  Column(
                    children: [
                      _WeatherCard(weather: _weather!),
                      const SizedBox(height: 16),
                      _ForecastList(forecast: _forecast!),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// Map OpenWeatherMap code -> WMO code
// -----------------------------------------------------------
int _mapToWmoCode(String owmCode) {
  switch (owmCode) {
    case '01d':
    case '01n':
      return 0;
    case '02d':
    case '02n':
      return 2;
    case '03d':
    case '03n':
      return 3;
    case '04d':
    case '04n':
      return 3;
    case '09d':
    case '09n':
      return 80;
    case '10d':
    case '10n':
      return 61;
    case '11d':
    case '11n':
      return 95;
    case '13d':
    case '13n':
      return 71;
    case '50d':
    case '50n':
      return 45;
    default:
      return 3;
  }
}

// -----------------------------------------------------------
// Pick gradient colors based on temperature AND dark mode
// -----------------------------------------------------------
List<Color> _gradientForTemp(double temp, bool isDark) {
  // Note: If the user selects Fahrenheit, a "hot" day will be around 90.
  // To keep the gradients working correctly regardless of units,
  // we convert the temp back to Celsius for the gradient check.
  // (This is a smart trick to avoid breaking the colors).
  final double tempC = (temp - 32) / 1.8; // Convert to C to check limits

  // If tempC is still very high (because temp was actually Celsius), we keep it.
  final double checkTemp = tempC > 50 ? temp : tempC;

  if (checkTemp < 0) {
    return isDark
        ? [const Color(0xFF1A2980), const Color(0xFF26D0CE)]
        : [const Color(0xFF6DD5FA), const Color(0xFF2980B9)];
  } else if (checkTemp < 10) {
    return isDark
        ? [const Color(0xFF2C3E50), const Color(0xFF4CA1AF)]
        : [const Color(0xFF83A4D4), const Color(0xFFB6FBFF)];
  } else if (checkTemp < 20) {
    return isDark
        ? [const Color(0xFF134E5E), const Color(0xFF71B280)]
        : [const Color(0xFF4ECDC4), const Color(0xFF44A08D)];
  } else if (checkTemp < 30) {
    return isDark
        ? [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)]
        : [const Color(0xFFFFB75E), const Color(0xFFED8F03)];
  } else {
    return isDark
        ? [const Color(0xFF870000), const Color(0xFF190A05)]
        : [const Color(0xFFFF512F), const Color(0xFFDD2476)];
  }
}

// -----------------------------------------------------------
// Format Time
// -----------------------------------------------------------
String _formatTime(int unixSeconds, int timezoneOffsetSeconds) {
  final int adjustedSeconds = unixSeconds + timezoneOffsetSeconds;
  final dt = DateTime.fromMillisecondsSinceEpoch(
    adjustedSeconds * 1000,
    isUtc: true,
  );
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

// -----------------------------------------------------------
// Wind Direction
// -----------------------------------------------------------
String _windDirection(int degrees) {
  const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final index = ((degrees + 22.5) / 45).floor() % 8;
  return directions[index];
}

// -----------------------------------------------------------
// Visibility
// -----------------------------------------------------------
String _formatVisibility(int meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '$meters m';
}

// -----------------------------------------------------------
// Weather Card
// -----------------------------------------------------------
class _WeatherCard extends StatelessWidget {
  final Weather weather;
  const _WeatherCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[700];

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              '${weather.city}, ${weather.country}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),

            WeatherSvgIcon.byCode(
              _mapToWmoCode(weather.icon),
              isDay: weather.icon.endsWith('d'),
              size: 100,
            ),
            const SizedBox(height: 8),

            // 👈 CHANGED: Just '°', since the toggle at the top tells them the unit
            Text(
              '${weather.temperature.toStringAsFixed(1)}°',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w300,
                color: textColor,
              ),
            ),

            Text(
              weather.description.toUpperCase(),
              style: TextStyle(
                fontSize: 16,
                letterSpacing: 1.5,
                color: textColor,
              ),
            ),

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_upward, size: 16, color: subTextColor),
                Text(
                  '${weather.tempMax.toStringAsFixed(0)}°',
                  style: TextStyle(color: subTextColor, fontSize: 14),
                ),
                const SizedBox(width: 12),
                Icon(Icons.arrow_downward, size: 16, color: subTextColor),
                Text(
                  '${weather.tempMin.toStringAsFixed(0)}°',
                  style: TextStyle(color: subTextColor, fontSize: 14),
                ),
              ],
            ),

            Divider(
              height: 40,
              color: isDark ? Colors.white24 : Colors.black12,
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Stat(
                  label: 'Feels like',
                  value: '${weather.feelsLike.toStringAsFixed(0)}°',
                ),
                _Stat(label: 'Humidity', value: '${weather.humidity}%'),
                _Stat(
                  label: 'Wind',
                  value:
                      '${weather.windSpeed.toStringAsFixed(1)} m/s ${_windDirection(weather.windDeg)}',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Stat(label: 'Pressure', value: '${weather.pressure} hPa'),
                _Stat(
                  label: 'Visibility',
                  value: _formatVisibility(weather.visibility),
                ),
                _Stat(label: 'Wind Dir.', value: '${weather.windDeg}°'),
              ],
            ),

            Divider(
              height: 40,
              color: isDark ? Colors.white24 : Colors.black12,
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatWithIcon(
                  icon: Icons.wb_twilight,
                  label: 'Sunrise',
                  value: _formatTime(weather.sunrise, weather.timezone),
                ),
                _StatWithIcon(
                  icon: Icons.nights_stay_outlined,
                  label: 'Sunset',
                  value: _formatTime(weather.sunset, weather.timezone),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// Forecast List Widget
// -----------------------------------------------------------
class _ForecastList extends StatelessWidget {
  final List<ForecastDay> forecast;
  const _ForecastList({required this.forecast});

  String _getDayName(String dateStr) {
    final date = DateTime.parse(dateStr);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: forecast.length,
        itemBuilder: (context, index) {
          final day = forecast[index];
          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getDayName(day.date),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                WeatherSvgIcon.byCode(
                  _mapToWmoCode(day.icon),
                  isDay: day.icon.endsWith('d'),
                  size: 40,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${day.tempMax.toStringAsFixed(0)}°',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      ' ${day.tempMin.toStringAsFixed(0)}°',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------
// Stat with Icon
// -----------------------------------------------------------
class _StatWithIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatWithIcon({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Column(
      children: [
        Icon(icon, color: Colors.orange[400], size: 24),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: subTextColor, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------
// Basic Stat
// -----------------------------------------------------------
class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Column(
      children: [
        Text(label, style: TextStyle(color: subTextColor, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
