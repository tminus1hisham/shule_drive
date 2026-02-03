import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/trip.dart';
import '../../widgets/main_scaffold.dart';

class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key});

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final trip = provider.trips.first;

    return MainScaffold(
      title: 'Trip Details',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: provider.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trip Started',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: provider.isDarkMode ? AppProvider.primaryGreen : const Color(0xFF6B9B5B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '12 June 2025, 10:42 AM',
                    style: TextStyle(
                      fontSize: 14,
                      color: provider.textMutedColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Timeline
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: provider.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: trip.stops.map((stop) {
                  final index = trip.stops.indexOf(stop);
                  final isLast = index == trip.stops.length - 1;
                  final isDelay = stop.status == StopStatus.delay;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline line and dot
                      Column(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: isDelay
                                  ? const Color(0xFFFF9800)
                                  : const Color(0xFF6B9B5B),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: provider.cardColor,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDelay
                                          ? const Color(0xFFFF9800)
                                          : const Color(0xFF6B9B5B))
                                      .withAlpha(77),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 60,
                              color: provider.isDarkMode ? Colors.white24 : const Color(0xFFE0E0E0),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // Stop details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stop.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDelay
                                    ? const Color(0xFFFF9800)
                                    : provider.textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stop.address,
                              style: TextStyle(
                                fontSize: 12,
                                color: provider.textMutedColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stop.time,
                              style: TextStyle(
                                fontSize: 11,
                                color: provider.isDarkMode ? Colors.white54 : const Color(0xFF999999),
                              ),
                            ),
                            if (!isLast) const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
