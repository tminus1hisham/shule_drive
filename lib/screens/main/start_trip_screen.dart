import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/main_scaffold.dart';

class StartTripScreen extends StatefulWidget {
  const StartTripScreen({super.key});

  @override
  State<StartTripScreen> createState() => _StartTripScreenState();
}

class _StartTripScreenState extends State<StartTripScreen> {
  int _currentIndex = 0;
  String? _selectedVehicle;
  String? _selectedRoute;
  String? _selectedAttendant;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Fetch routes and buses when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final provider = context.read<AppProvider>();
    
    // Fetch routes and buses in parallel
    await Future.wait([
      provider.fetchRoutesByUser(),
      provider.fetchBusesByUser(),
    ]);
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final routes = provider.routes;
    final buses = provider.buses;
    
    // Build vehicle items from API data
    final vehicleItems = buses.map((bus) => bus.registrationNumber).toList();
    
    // Build route items from API data
    final routeItems = routes.map((route) => route.name).toList();
    
    // Attendant items (could be fetched from API if needed)
    final attendantItems = ['James Kadere', 'John Doe', 'Jane Smith'];
    
    return MainScaffold(
      title: 'Start Trip',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: _currentIndex,
      onBottomNavTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 3) {
          Navigator.pushNamed(context, '/profile');
        }
      },
      body: SafeArea(
        child: Column(
          children: [
            // Map Area (Placeholder)
            Expanded(
              flex: 2,
              child: Container(
                color: provider.isDarkMode 
                    ? const Color(0xFF1A2E1A) 
                    : const Color(0xFFE8F5E9),
                child: Stack(
                  children: [
                    // Map Background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: provider.isDarkMode
                              ? [const Color(0xFF1A2E1A), const Color(0xFF0D1F0D)]
                              : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
                        ),
                      ),
                    ),
                    // Route Line
                    CustomPaint(
                      size: Size.infinite, 
                      painter: RoutePainter(isDarkMode: provider.isDarkMode),
                    ),
                    // Location Markers
                    Positioned(
                      left: 50,
                      top: 100,
                      child: _buildLocationMarker(true, provider.isDarkMode),
                    ),
                    Positioned(
                      right: 80,
                      top: 150,
                      child: _buildLocationMarker(false, provider.isDarkMode),
                    ),
                    Positioned(
                      left: 120,
                      bottom: 120,
                      child: _buildLocationMarker(false, provider.isDarkMode),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Sheet
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: provider.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Start Your Trip',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: provider.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select your assigned vehicle, route, and attendant to begin your trip.',
                    style: TextStyle(fontSize: 14, color: provider.textMutedColor),
                  ),
                  const SizedBox(height: 20),
                  
                  // Show loading indicator while fetching data
                  if (_isLoading || provider.isLoading)
                    Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B9B5B)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Loading routes and vehicles...',
                            style: TextStyle(
                              color: provider.textMutedColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Route Dropdown
                    _buildDropdown(
                      'Route',
                      _selectedRoute,
                      routeItems,
                      (value) => setState(() => _selectedRoute = value),
                      provider,
                      hint: 'Select Route',
                      emptyMessage: routeItems.isEmpty ? 'No routes available' : null,
                    ),
                    const SizedBox(height: 16),

                    // Vehicle Registration Dropdown
                    _buildDropdown(
                      'Vehicle Registration No.',
                      _selectedVehicle,
                      vehicleItems,
                      (value) => setState(() => _selectedVehicle = value),
                      provider,
                      hint: 'Select Vehicle',
                      emptyMessage: vehicleItems.isEmpty ? 'No vehicles available' : null,
                    ),
                    const SizedBox(height: 16),

                    // Attendant Dropdown
                    _buildDropdown(
                      'Attendant',
                      _selectedAttendant,
                      attendantItems,
                      (value) => setState(() => _selectedAttendant = value),
                      provider,
                      hint: 'Select Attendant',
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: provider.textMutedColor,
                            side: BorderSide(
                              color: provider.isDarkMode 
                                  ? Colors.white24 
                                  : const Color(0xFFE0E0E0),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (_isLoading || provider.isLoading || 
                                     _selectedRoute == null || 
                                     _selectedVehicle == null)
                              ? null 
                              : () {
                                  Navigator.pushNamed(context, '/select-students');
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B9B5B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            disabledBackgroundColor: const Color(0xFF6B9B5B).withValues(alpha: 0.5),
                          ),
                          child: const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationMarker(bool isStart, bool isDarkMode) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isStart ? const Color(0xFF6B9B5B) : const Color(0xFFFF9800),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white, 
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.4 : 0.2), 
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(
        isStart ? Icons.directions_bus : Icons.location_on,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
    AppProvider provider, {
    required String hint,
    String? emptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: provider.textMutedColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: provider.isDarkMode 
                ? const Color(0xFF2C2C2C) 
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: emptyMessage != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: provider.textMutedColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        emptyMessage,
                        style: TextStyle(
                          color: provider.textMutedColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    hint: Text(
                      hint,
                      style: TextStyle(color: provider.textMutedColor),
                    ),
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down, color: provider.textMutedColor),
                    dropdownColor: provider.cardColor,
                    style: TextStyle(color: provider.textColor),
                    items: items.map((String item) {
                      return DropdownMenuItem<String>(
                        value: item, 
                        child: Text(
                          item,
                          style: TextStyle(color: provider.textColor),
                        ),
                      );
                    }).toList(),
                    onChanged: onChanged,
                  ),
                ),
        ),
      ],
    );
  }
}

class RoutePainter extends CustomPainter {
  final bool isDarkMode;
  
  RoutePainter({required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6B9B5B)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(70, 120)
      ..lineTo(size.width - 100, 170)
      ..lineTo(140, size.height - 140);

    canvas.drawPath(path, paint);

    // Draw dashed line effect
    final dashPaint = Paint()
      ..color = isDarkMode 
          ? const Color(0xFF6B9B5B).withAlpha(128)
          : const Color(0xFF6B9B5B).withAlpha(77)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dashPath = Path()
      ..moveTo(70, 120)
      ..lineTo(size.width - 100, 170)
      ..lineTo(140, size.height - 140);

    canvas.drawPath(dashPath, dashPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
