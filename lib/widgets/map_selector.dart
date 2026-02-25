import 'package:flutter/material.dart';
import '../config/map_config.dart';

/// Map Provider - Now Mapbox Only
enum MapProvider {
  mapbox,
}

/// Map Selector Widget - Shows Mapbox as the configured provider
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
            'Map Provider',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Mapbox Option (Only Option)
          _buildOption(
            context,
            provider: MapProvider.mapbox,
            title: 'Mapbox',
            subtitle: 'High-quality maps and routing',
            icon: Icons.map,
            color: const Color(0xFF4264FB),
            isConfigured: MapConfig.hasAccessToken,
          ),
          
          const SizedBox(height: 16),
          
          // Info text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MapConfig.hasAccessToken 
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  MapConfig.hasAccessToken ? Icons.check_circle : Icons.warning,
                  color: MapConfig.hasAccessToken 
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE53935),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    MapConfig.hasAccessToken
                        ? 'Mapbox is configured and ready to use.'
                        : 'Mapbox token not found. Please configure ACCESS_TOKEN.',
                    style: TextStyle(
                      fontSize: 12,
                      color: MapConfig.hasAccessToken 
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
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
    required bool isConfigured,
  }) {
    final isSelected = selectedProvider == provider;
    
    return InkWell(
      onTap: isConfigured ? () => onProviderChanged(provider) : null,
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
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isConfigured 
                              ? const Color(0xFF4CAF50)
                              : Colors.grey,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isConfigured ? 'ACTIVE' : 'NOT CONFIGURED',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
  MapProvider initialProvider = MapProvider.mapbox,
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
