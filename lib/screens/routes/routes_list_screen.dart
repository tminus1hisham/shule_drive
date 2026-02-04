import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/api.dart' as api;
import '../../providers/app_provider.dart';
import '../../widgets/main_scaffold.dart';

class RoutesListScreen extends StatefulWidget {
  const RoutesListScreen({super.key});

  @override
  State<RoutesListScreen> createState() => _RoutesListScreenState();
}

class _RoutesListScreenState extends State<RoutesListScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Fetch routes when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchRoutesByUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final routes = provider.routes;
    final isLoading = provider.isLoading;
    final errorMessage = provider.errorMessage;

    return MainScaffold(
      title: 'My Routes',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: _currentIndex,
      onBottomNavTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 0) {
          Navigator.pushReplacementNamed(context, '/landing');
        }
      },
      body: RefreshIndicator(
        onRefresh: () => provider.fetchRoutesByUser(),
        child: _buildBody(context, provider, routes, isLoading, errorMessage),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppProvider provider,
    List<api.BusRoute> routes,
    bool isLoading,
    String? errorMessage,
  ) {
    // Show loading
    if (isLoading && routes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6B9B5B),
        ),
      );
    }

    // Show error
    if (errorMessage != null && routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: provider.textMutedColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading routes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: provider.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(
                fontSize: 14,
                color: provider.textMutedColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => provider.fetchRoutesByUser(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9B5B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Show empty state
    if (routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.route_outlined,
              size: 80,
              color: provider.textMutedColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No routes assigned',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: provider.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You don\'t have any routes assigned yet',
              style: TextStyle(
                fontSize: 14,
                color: provider.textMutedColor,
              ),
            ),
          ],
        ),
      );
    }

    // Show routes list
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: routes.length,
      itemBuilder: (context, index) {
        final route = routes[index];
        return _buildRouteCard(context, provider, route);
      },
    );
  }

  Widget _buildRouteCard(
    BuildContext context,
    AppProvider provider,
    api.BusRoute route,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: provider.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: provider.isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B9B5B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.route_outlined,
                  color: Color(0xFF6B9B5B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: provider.textColor,
                      ),
                    ),
                    if (route.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        route.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: provider.textMutedColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: provider.isDarkMode ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoChip(
                provider,
                Icons.location_on_outlined,
                '${route.stopCount} stops',
              ),
              if (route.schoolName != null)
                _buildInfoChip(
                  provider,
                  Icons.school_outlined,
                  route.schoolName!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(AppProvider provider, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: provider.isDarkMode
              ? const Color(0xFF8BC48B)
              : const Color(0xFF6B9B5B),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: provider.isDarkMode
                ? const Color(0xFF8BC48B)
                : const Color(0xFF6B9B5B),
          ),
        ),
      ],
    );
  }
}
