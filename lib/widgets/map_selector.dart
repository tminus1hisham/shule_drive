import 'package:flutter/material.dart';

/// Map Provider Selector - Choose between Google Maps and OpenStreetMap
enum MapProvider {
  google,
  openStreetMap,
}

/// Map Selector Widget
class MapSelector extends StatelessWidget {
  final MapProvider selectedProvider;
  final Function(MapProvider) onProviderChanged;

  const MapSelector({
    super.key,
    required this.selectedProvider,
    required this.onProviderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Select Map Provider',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Google Maps Option
          _buildOption(
            context,
            provider: MapProvider.google,
            title: 'Google Maps',
            subtitle: 'Best quality, requires API key',
            icon: Icons.map,
            color: const Color(0xFF4285F4),
          ),
          
          const SizedBox(height: 12),
          
          // OpenStreetMap Option
          _buildOption(
            context,
            provider: MapProvider.openStreetMap,
            title: 'OpenStreetMap (Free)',
            subtitle: '100% Free, no API key needed',
            icon: Icons.public,
            color: const Color(0xFF7EBC6F),
            isRecommended: true,
          ),
          
          const SizedBox(height: 16),
          
          // Info text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFF57C00), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'OpenStreetMap is completely free and uses OSRM for routing. No signup required!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFF57C00),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required MapProvider provider,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isRecommended = false,
  }) {
    final isSelected = selectedProvider == provider;
    
    return InkWell(
      onTap: () => onProviderChanged(provider),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(20) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'FREE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4CAF50),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to show map selector
Future<MapProvider?> showMapSelectorDialog(
  BuildContext context, {
  MapProvider initialProvider = MapProvider.openStreetMap,
}) async {
  return showDialog<MapProvider>(
    context: context,
    builder: (context) {
      return AlertDialog(
        contentPadding: const EdgeInsets.all(20),
        content: MapSelector(
          selectedProvider: initialProvider,
          onProviderChanged: (provider) {
            Navigator.of(context).pop(provider);
          },
        ),
      );
    },
  );
}
