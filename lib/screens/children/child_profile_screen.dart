import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/api.dart' as api;
import '../../api/services/student_service.dart';
import '../../api/services/user_service.dart';
import '../../models/guardian.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/main_scaffold.dart';

class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({super.key});

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  int _currentIndex = 3;
  String? _childId;
  
  // Student details (may contain more data than the list item)
  api.Student? _studentDetails;
  bool _isLoadingStudent = false;
  
  // Guardians list
  List<Guardian> _guardians = [];
  bool _isLoadingGuardians = false;
  String? _guardiansError;
  
  // User profile for guardian name
  UserProfile? _userProfile;
  bool _isLoadingProfile = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get child ID from route arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final newChildId = args?['childId'] as String?;
    
    // Only fetch if child ID changed
    if (newChildId != _childId) {
      _childId = newChildId;
      _fetchStudentDetails();
      _fetchGuardians();
      _fetchUserProfile();
    }
  }

  /// Fetch full student details from API
  Future<void> _fetchStudentDetails() async {
    if (_childId == null) return;
    
    setState(() {
      _isLoadingStudent = true;
    });

    try {
      final studentService = StudentService();
      final student = await studentService.getStudentById(_childId!);
      
      if (mounted && student != null) {
        setState(() {
          _studentDetails = student;
          _isLoadingStudent = false;
        });
        
        if (kDebugMode) {
          print('📱 ChildProfile: Loaded student details:');
          print('   Name: ${student.name}');
          print('   Guardian ID: ${student.guardianId}');
          print('   Guardian Name: ${student.guardianName}');
          print('   Guardian Phone: ${student.guardianPhone}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStudent = false;
        });
      }
      if (kDebugMode) {
        print('❌ ChildProfile: Error loading student details: $e');
      }
    }
  }

  /// Fetch user profile to get guardian name
  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final userService = UserService();
      final profile = await userService.getProfile();
      
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoadingProfile = false;
        });
        
        if (kDebugMode) {
          print('📱 ChildProfile: Loaded user profile:');
          print('   Name: ${profile.name}');
          print('   Phone: ${profile.phone}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
      if (kDebugMode) {
        print('❌ ChildProfile: Error loading user profile: $e');
      }
    }
  }

  /// Fetch guardians for the current student
  Future<void> _fetchGuardians() async {
    if (_childId == null) return;
    
    setState(() {
      _isLoadingGuardians = true;
      _guardiansError = null;
    });

    try {
      final studentService = StudentService();
      final guardians = await studentService.getStudentGuardians(_childId!);
      
      if (mounted) {
        setState(() {
          _guardians = guardians;
          _isLoadingGuardians = false;
        });
        
        if (kDebugMode) {
          print('📱 ChildProfile: Loaded ${guardians.length} guardians');
          for (final g in guardians) {
            print('   - ${g.name} (${g.phone}) [Primary: ${g.isPrimary}]');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardiansError = e.toString();
          _isLoadingGuardians = false;
        });
      }
      if (kDebugMode) {
        print('❌ ChildProfile: Error loading guardians: $e');
      }
    }
  }

  /// Get the student to display (prefer detailed data from API)
  api.Student? _getDisplayStudent(AppProvider provider) {
    // First try the detailed student data
    if (_studentDetails != null && _studentDetails!.id == _childId) {
      return _studentDetails;
    }
    
    // Fall back to the list data from provider
    if (_childId != null) {
      try {
        return provider.apiStudents.firstWhere(
          (s) => s.id == _childId,
          orElse: () => provider.apiStudents.first,
        );
      } catch (e) {
        return null;
      }
    }
    
    return provider.apiStudents.isNotEmpty ? provider.apiStudents.first : null;
  }

  /// Get guardian name from available sources
  String? _getGuardianName(api.Student child) {
    // 1. Try student data first
    if (child.guardianName != null && child.guardianName!.isNotEmpty) {
      return child.guardianName;
    }
    
    // 2. Try user profile (current logged-in user is the guardian)
    if (_userProfile != null && _userProfile!.name.isNotEmpty) {
      return _userProfile!.name;
    }
    
    // 3. Try AuthProvider
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userName != null && authProvider.userName!.isNotEmpty) {
      return authProvider.userName;
    }
    
    return null;
  }

  /// Get guardian phone from available sources
  String? _getGuardianPhone(api.Student child) {
    // 1. Try student data first
    if (child.guardianPhone != null && child.guardianPhone!.isNotEmpty) {
      return child.guardianPhone;
    }
    
    // 2. Try user profile
    if (_userProfile != null && _userProfile!.phone.isNotEmpty) {
      return _userProfile!.phone;
    }
    
    // 3. Try AuthProvider
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userPhone != null && authProvider.userPhone!.isNotEmpty) {
      return authProvider.userPhone;
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    
    // Get the student to display
    final child = _getDisplayStudent(provider);
    
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
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchStudentDetails();
          await _fetchGuardians();
          await _fetchUserProfile();
        },
        color: const Color(0xFF6B9B5B),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
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
                        _buildAvatar(child.photo),
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

              // Guardians Information
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: provider.cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Guardians',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: provider.textColor,
                          ),
                        ),
                        if (_isLoadingGuardians || _isLoadingStudent || _isLoadingProfile)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF6B9B5B),
                            ),
                          )
                        else if (_guardians.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B9B5B).withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_guardians.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B9B5B),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Display guardians list
                    if (_guardiansError != null)
                      _buildErrorWidget(_guardiansError!)
                    else if (_guardians.isEmpty && !_isLoadingGuardians)
                      _buildGuardianFromUserData(child)
                    else
                      _buildGuardiansList(),
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
      ),
    );
  }

  /// Build the list of guardians
  Widget _buildGuardiansList() {
    return Column(
      children: _guardians.asMap().entries.map((entry) {
        final index = entry.key;
        final guardian = entry.value;
        final isLast = index == _guardians.length - 1;
        
        return Column(
          children: [
            _buildGuardianItem(guardian),
            if (!isLast) const Divider(height: 24),
          ],
        );
      }).toList(),
    );
  }

  /// Build a single guardian item
  Widget _buildGuardianItem(Guardian guardian) {
    final provider = context.read<AppProvider>();
    
    return Row(
      children: [
        // Guardian avatar/icon
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: guardian.isPrimary 
                ? const Color(0xFF6B9B5B).withAlpha(30)
                : Colors.grey.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person,
            color: guardian.isPrimary 
                ? const Color(0xFF6B9B5B)
                : provider.textMutedColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        
        // Guardian info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      guardian.name.isNotEmpty && guardian.name != 'Unknown Guardian'
                          ? guardian.name 
                          : 'Guardian',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: provider.textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (guardian.isPrimary)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B9B5B).withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Primary',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B9B5B),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                guardian.phone ?? 'No phone number',
                style: TextStyle(
                  fontSize: 13,
                  color: guardian.phone != null && guardian.phone!.isNotEmpty
                      ? provider.textMutedColor 
                      : provider.textMutedColor.withAlpha(128),
                ),
              ),
              if (guardian.relationship != null && guardian.relationship!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  guardian.relationship!,
                  style: TextStyle(
                    fontSize: 12,
                    color: provider.textMutedColor.withAlpha(180),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Phone action button
        if (guardian.phone != null && guardian.phone!.isNotEmpty)
          IconButton(
            onPressed: () => _callGuardian(guardian.phone!),
            icon: const Icon(
              Icons.phone,
              color: Color(0xFF6B9B5B),
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
      ],
    );
  }

  /// Build guardian widget using user data (when no extended guardians API data)
  Widget _buildGuardianFromUserData(api.Student child) {
    final provider = context.read<AppProvider>();
    
    // Get guardian info from available sources
    final guardianName = _getGuardianName(child);
    final guardianPhone = _getGuardianPhone(child);
    
    if (kDebugMode) {
      print('📱 ChildProfile: Building guardian from user data:');
      print('   guardianName: $guardianName');
      print('   guardianPhone: $guardianPhone');
    }
    
    // If we have any guardian info, display it
    if ((guardianName != null && guardianName.isNotEmpty) || 
        (guardianPhone != null && guardianPhone.isNotEmpty)) {
      final guardian = Guardian.fromStudentGuardian(
        guardianId: child.guardianId,
        guardianName: guardianName ?? guardianPhone ?? 'Guardian',
        guardianPhone: guardianPhone,
        isPrimary: true,
      );
      return _buildGuardianItem(guardian);
    }
    
    // Fallback to current user data from provider
    final userName = provider.userData['name'];
    final userPhone = provider.userData['phone'];
    
    if (userName != null || userPhone != null) {
      return Column(
        children: [
          _buildInfoRow(context, 'Guardian', userName ?? 'N/A'),
          const Divider(height: 24),
          _buildInfoRow(context, 'Phone', userPhone ?? 'N/A'),
        ],
      );
    }
    
    // No guardian data available at all
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            size: 48,
            color: provider.textMutedColor.withAlpha(128),
          ),
          const SizedBox(height: 8),
          Text(
            'No guardian information available',
            style: TextStyle(
              fontSize: 14,
              color: provider.textMutedColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Build error widget
  Widget _buildErrorWidget(String error) {
    final provider = context.read<AppProvider>();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Failed to load guardians',
              style: TextStyle(
                fontSize: 13,
                color: provider.textMutedColor,
              ),
            ),
          ),
          TextButton(
            onPressed: _fetchGuardians,
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Color(0xFF6B9B5B),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Call guardian
  void _callGuardian(String phone) {
    // TODO: Implement phone call using url_launcher
    if (kDebugMode) {
      print('📞 Calling guardian: $phone');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling $phone...'),
        duration: const Duration(seconds: 2),
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

  Widget _buildAvatar(String? photoUrl) {
    // Check if it's a valid network URL
    if (photoUrl != null &&
        photoUrl.isNotEmpty &&
        (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'))) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: NetworkImage(photoUrl),
        backgroundColor: const Color(0xFF6B9B5B).withAlpha(50),
        onBackgroundImageError: (e, s) {
          if (kDebugMode) print('⚠️ Failed to load photo: $e');
        },
      );
    }

    // Fallback to default avatar
    return CircleAvatar(
      radius: 50,
      backgroundColor: const Color(0xFF6B9B5B).withAlpha(50),
      child: const Icon(
        Icons.person,
        color: Color(0xFF6B9B5B),
        size: 40,
      ),
    );
  }
}
