import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:weather_svg_icons/weather_svg_icons.dart';
import 'package:geolocator/geolocator.dart';

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
// Weather Data Model
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
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchWeatherByLocation();
    });
  }

  Future<void> _fetchWeather() async {
    final city = _controller.text.trim();
    if (city.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _weather = null;
    });

    try {
      final uri = Uri.parse('$baseUrl/weather?city=$city');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() => _weather = Weather.fromJson(data));
      } else if (response.statusCode == 404) {
        setState(() => _error = 'City not found');
      } else {
        setState(() => _error = 'Server error (${response.statusCode})');
      }
    } catch (e) {
      setState(() => _error = 'Could not connect. Is the backend running?');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchWeatherByLocation() async {
    setState(() {
      _loading = true;
      _error = null;
      _weather = null;
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

      final uri = Uri.parse(
        '$baseUrl/weather?lat=${position.latitude}&lon=${position.longitude}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() => _weather = Weather.fromJson(data));
      } else {
        setState(() => _error = 'Server error (${response.statusCode})');
      }
    } catch (e) {
      setState(() => _error = 'Could not get location: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pass the dark mode state to the gradient function
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
                const SizedBox(height: 24),

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
                else if (_weather != null)
                  _WeatherCard(weather: _weather!),
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
  if (temp < 0) {
    return isDark
        ? [const Color(0xFF1A2980), const Color(0xFF26D0CE)]
        : [const Color(0xFF6DD5FA), const Color(0xFF2980B9)];
  } else if (temp < 10) {
    return isDark
        ? [const Color(0xFF2C3E50), const Color(0xFF4CA1AF)]
        : [const Color(0xFF83A4D4), const Color(0xFFB6FBFF)];
  } else if (temp < 20) {
    return isDark
        ? [const Color(0xFF134E5E), const Color(0xFF71B280)]
        : [const Color(0xFF4ECDC4), const Color(0xFF44A08D)];
  } else if (temp < 30) {
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
// Weather Card (Updated for Dark Mode Glassmorphism)
// -----------------------------------------------------------
class _WeatherCard extends StatelessWidget {
  final Weather weather;
  const _WeatherCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Text color that adapts (Black for light mode, White for dark mode)
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[700];

    return Container(
      decoration: BoxDecoration(
        // Glassmorphism effect: transparent white in light mode, transparent black in dark mode
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

            Text(
              '${weather.temperature.toStringAsFixed(1)}°C',
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
                  '${weather.tempMax.toStringAsFixed(0)}°C',
                  style: TextStyle(color: subTextColor, fontSize: 14),
                ),
                const SizedBox(width: 12),
                Icon(Icons.arrow_downward, size: 16, color: subTextColor),
                Text(
                  '${weather.tempMin.toStringAsFixed(0)}°C',
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
                  value: '${weather.feelsLike.toStringAsFixed(0)}°C',
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
