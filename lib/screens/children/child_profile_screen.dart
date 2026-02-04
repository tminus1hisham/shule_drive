import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/api.dart' as api;
import '../../providers/app_provider.dart';
import '../../widgets/main_scaffold.dart';

class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({super.key});

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  int _currentIndex = 3;
  String? _childId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get child ID from route arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _childId = args?['childId'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    
    // Find child from API data
    api.Student? child;
    if (_childId != null) {
      child = provider.apiStudents.firstWhere(
        (s) => s.id == _childId,
        orElse: () => provider.apiStudents.first,
      );
    } else {
      child = provider.apiStudents.isNotEmpty ? provider.apiStudents.first : null;
    }
    
    // Show loading if no child data
    if (child == null) {
      return MainScaffold(
        title: 'Child Profile',
        showBackButton: true,
        showBottomNav: true,
        bottomNavIndex: _currentIndex,
        onBottomNavTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/landing');
          }
        },
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6B9B5B),
          ),
        ),
      );
    }

    return MainScaffold(
      title: 'Child Profile',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: _currentIndex,
      onBottomNavTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 0) {
          Navigator.pushReplacementNamed(context, '/landing');
        }
      },
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: provider.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: child.photo != null 
                            ? NetworkImage(child.photo!)
                            : null,
                        backgroundColor: const Color(0xFF6B9B5B).withValues(alpha: 0.2),
                        child: child.photo == null
                            ? const Icon(
                                Icons.person,
                                color: Color(0xFF6B9B5B),
                                size: 40,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B9B5B),
                            shape: BoxShape.circle,
                            border: Border.all(color: provider.cardColor, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Name
                  Text(
                    child.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: provider.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // School
                  Text(
                    child.schoolName ?? 'No School',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B9B5B),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Class
                  Text(
                    child.className,
                    style: TextStyle(
                      fontSize: 14,
                      color: provider.textMutedColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Parent Information
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
                    'Parent Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: provider.textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(context, 'Guardian', provider.userData['name'] ?? 'N/A'),
                  const Divider(height: 24),
                  _buildInfoRow(context, 'Phone', provider.userData['phone'] ?? 'N/A'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // School Information
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
                    'School Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: provider.textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(context, 'School', child.schoolName ?? 'N/A'),
                  const Divider(height: 24),
                  _buildInfoRow(context, 'Class', child.className),
                  const Divider(height: 24),
                  _buildInfoRow(context, 'Student ID', 'STU-${child.id.padLeft(4, '0')}'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save Changes Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B9B5B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final provider = context.watch<AppProvider>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: provider.textMutedColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: provider.textColor,
          ),
        ),
      ],
    );
  }
}
