import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/api.dart' as api;
import '../../api/services/student_service.dart';
import '../../api/services/user_service.dart';
import '../../models/guardian.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/ui/ui.dart';

class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({super.key});

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
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
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
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
    final child = _getDisplayStudent(provider);

    return MainScaffold(
      title: 'Child Profile',
      showBackButton: true,
      showBottomNav: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          AsyncBody(
            loading: child == null,
            skeleton: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: const [
                AppSkeleton(height: 220, borderRadius: AppRadius.brXl),
                AppSpacing.vMd,
                AppSkeleton(height: 140, borderRadius: AppRadius.brLg),
                AppSpacing.vMd,
                AppSkeleton(height: 160, borderRadius: AppRadius.brLg),
              ],
            ),
            onRefresh: () async {
              await _fetchStudentDetails();
              await _fetchGuardians();
              await _fetchUserProfile();
            },
            child: child == null
                ? const SizedBox.shrink()
                : _buildContent(child),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(api.Student child) {
    final c = context.colors;
    final busy = _isLoadingGuardians || _isLoadingStudent || _isLoadingProfile;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Profile hero
        GradientHeroCard(
          child: Column(
            children: [
              Stack(
                children: [
                  Hero(
                    tag: 'child-avatar-${child.id}',
                    child: AppAvatar(
                      imageUrl: _validPhoto(child.photo),
                      name: child.name,
                      size: 100,
                      borderColor: Colors.white,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.vMd,
              Text(
                child.name,
                textAlign: TextAlign.center,
                style: context.text.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              AppSpacing.vXs,
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                children: [
                  StatusPill(
                    label: child.schoolName ?? 'No School',
                    color: Colors.white,
                    icon: Icons.school_rounded,
                    dense: true,
                  ),
                  if (child.className.isNotEmpty)
                    StatusPill(
                      label: child.className,
                      color: Colors.white,
                      showDot: false,
                      dense: true,
                    ),
                ],
              ),
            ],
          ),
        ).enter(),
        AppSpacing.vMd,

        // Guardians
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: SectionHeader(title: 'Guardians')),
                  AnimatedSwitcher(
                    duration: AppDuration.medium,
                    child: busy
                        ? SizedBox.square(
                            key: const ValueKey('busy'),
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.brand,
                            ),
                          )
                        : _guardians.isNotEmpty
                        ? StatusPill(
                            key: const ValueKey('count'),
                            label: '${_guardians.length}',
                            color: c.brand,
                            showDot: false,
                            dense: true,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              AppSpacing.vMd,
              AnimatedSize(
                duration: AppDuration.medium,
                curve: AppCurves.easeOut,
                alignment: Alignment.topCenter,
                child: _guardiansError != null
                    ? _buildErrorWidget()
                    : _guardians.isEmpty && !_isLoadingGuardians
                    ? _buildGuardianFromUserData(child)
                    : _buildGuardiansList(),
              ),
            ],
          ),
        ).enterList(1),
        AppSpacing.vMd,

        // School information
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'School Information'),
              AppSpacing.vMd,
              _buildInfoRow('School', child.schoolName ?? 'N/A'),
              const Divider(height: AppSpacing.xl),
              _buildInfoRow('Class', child.className),
              const Divider(height: AppSpacing.xl),
              _buildInfoRow('Student ID', 'STU-${child.id.padLeft(4, '0')}'),
            ],
          ),
        ).enterList(2),
        AppSpacing.vLg,
      ],
    );
  }

  /// Only real network URLs are loaded; anything else shows initials.
  String? _validPhoto(String? url) =>
      url != null && (url.startsWith('http://') || url.startsWith('https://'))
      ? url
      : null;

  Widget _buildGuardiansList() {
    return Column(
      children: [
        for (final (i, guardian) in _guardians.indexed) ...[
          _buildGuardianItem(guardian).enterList(i),
          if (i < _guardians.length - 1) const Divider(height: AppSpacing.xl),
        ],
      ],
    );
  }

  Widget _buildGuardianItem(Guardian guardian) {
    final c = context.colors;
    final name = guardian.name.isNotEmpty && guardian.name != 'Unknown Guardian'
        ? guardian.name
        : 'Guardian';
    final hasPhone = guardian.phone != null && guardian.phone!.isNotEmpty;

    return Row(
      children: [
        AppAvatar(
          name: name,
          size: 44,
          borderColor: guardian.isPrimary ? c.brand : null,
        ),
        AppSpacing.hSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (guardian.isPrimary) ...[
                    AppSpacing.hXs,
                    StatusPill(
                      label: 'Primary',
                      color: c.brand,
                      showDot: false,
                      dense: true,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                guardian.phone ?? 'No phone number',
                style: context.text.bodySmall?.copyWith(
                  color: hasPhone ? c.textSecondary : c.textMuted,
                ),
              ),
              if (guardian.relationship != null &&
                  guardian.relationship!.isNotEmpty)
                Text(
                  guardian.relationship!,
                  style: context.text.labelSmall?.copyWith(
                    color: c.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        if (hasPhone)
          IconButton(
            onPressed: () => _callGuardian(guardian.phone!),
            tooltip: 'Call',
            icon: const Icon(Icons.phone_rounded, size: 20),
            color: c.brand,
            style: IconButton.styleFrom(backgroundColor: c.brandSoft),
          ),
      ],
    );
  }

  /// Guardian row built from student / profile / auth data when the
  /// guardians API returned nothing.
  Widget _buildGuardianFromUserData(api.Student child) {
    final provider = context.read<AppProvider>();
    final guardianName = _getGuardianName(child);
    final guardianPhone = _getGuardianPhone(child);

    if ((guardianName != null && guardianName.isNotEmpty) ||
        (guardianPhone != null && guardianPhone.isNotEmpty)) {
      return _buildGuardianItem(
        Guardian.fromStudentGuardian(
          guardianId: child.guardianId,
          guardianName: guardianName ?? guardianPhone ?? 'Guardian',
          guardianPhone: guardianPhone,
          isPrimary: true,
        ),
      );
    }

    // Fallback to current user data from provider
    final userName = provider.userData['name'];
    final userPhone = provider.userData['phone'];
    if (userName != null || userPhone != null) {
      return Column(
        children: [
          _buildInfoRow('Guardian', userName ?? 'N/A'),
          const Divider(height: AppSpacing.xl),
          _buildInfoRow('Phone', userPhone ?? 'N/A'),
        ],
      );
    }

    return const EmptyState(
      icon: Icons.people_outline_rounded,
      title: 'No guardian information available',
      compact: true,
    );
  }

  Widget _buildErrorWidget() {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.error.withValues(alpha: 0.08),
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: c.error, size: 20),
          AppSpacing.hXs,
          Expanded(
            child: Text(
              'Failed to load guardians',
              style: context.text.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ),
          TextButton(onPressed: _fetchGuardians, child: const Text('Retry')),
        ],
      ),
    );
  }

  /// Call guardian
  void _callGuardian(String phone) {
    // TODO: Implement phone call using url_launcher
    if (kDebugMode) debugPrint('📞 Calling guardian: $phone');
    AppSnackbar.info(context, 'Calling $phone...');
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: context.text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
