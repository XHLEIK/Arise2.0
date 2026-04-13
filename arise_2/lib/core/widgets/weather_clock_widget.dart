import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/arise_colors.dart';
import '../services/weather_service.dart';

/// Live clock + date + weather capsule for the top bar right side.
class WeatherClockWidget extends StatelessWidget {
  const WeatherClockWidget({super.key, required this.service});

  final WeatherService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WeatherData>(
      stream: service.weatherStream,
      builder: (context, snapshot) {
        final weather = snapshot.data ?? WeatherData.zero();
        final now = DateTime.now();
        final dateStr = DateFormat('dd MMM').format(now);
        // Fallback or override local time if weather object isn't active
        final timeStr = weather.city == 'Connecting...'
            ? DateFormat('hh:mm').format(now)
            : weather.localTime;

        IconData weatherIcon = Icons.wb_sunny_rounded;
        String cond = weather.condition.toLowerCase();
        if (cond.contains('cloud') || cond.contains('overcast')) {
          weatherIcon = Icons.cloud_rounded;
        } else if (cond.contains('rain') || cond.contains('drizzle')) {
          weatherIcon = Icons.water_drop_rounded;
        } else if (cond.contains('snow') || cond.contains('ice')) {
          weatherIcon = Icons.ac_unit_rounded;
        } else if (cond.contains('thunder') || cond.contains('storm')) {
          weatherIcon = Icons.thunderstorm_rounded;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Weather capsule
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AriseColors.surfaceContainerHigh.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AriseColors.outlineVariant.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    weatherIcon,
                    size: 13,
                    color: AriseColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    weather.city == 'Connecting...'
                        ? '--°C'
                        : '${weather.city}, ${weather.temperature.toInt()}°C',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AriseColors.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Date + time
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AriseColors.surfaceContainerHigh.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AriseColors.outlineVariant.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateStr.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AriseColors.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: AriseColors.outlineVariant.withValues(alpha: 0.2),
                  ),
                  Text(
                    timeStr,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AriseColors.onSurfaceVariant,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
