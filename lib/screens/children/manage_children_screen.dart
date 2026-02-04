import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/api.dart' as api;
import '../../providers/app_provider.dart';
import '../../widgets/main_scaffold.dart';

class ManageChildrenScreen extends StatefulWidget {
  const ManageChildrenScreen({super.key});

  @override
  State<ManageChildrenScreen> createState() => _ManageChildrenScreenState();
}

class _ManageChildrenScreenState extends State<ManageChildrenScreen> {
  int _currentIndex = 3;

  @override
  void initState() {
    super.initState();
    // Fetch children when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchGuardianStudents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final children = provider.apiStudents;
    final isLoading = provider.isLoading;
    final errorMessage = provider.errorMessage;

    return MainScaffold(
      title: 'My Children',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: _currentIndex,
      onBottomNavTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 0) {
          Navigator.pushReplacementNamed(context, '/landing');
        }
      },
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddChildDialog(context),
        backgroundColor: const Color(0xFF6B9B5B),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchGuardianStudents(),
        child: _buildBody(context, provider, children, isLoading, errorMessage),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppProvider provider,
    List<api.Student> children,
    bool isLoading,
    String? errorMessage,
  ) {
    // Show loading
    if (isLoading && children.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6B9B5B),
        ),
      );
    }

    // Show error
    if (errorMessage != null && children.isEmpty) {
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
              'Error loading children',
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
              onPressed: () => provider.fetchGuardianStudents(),
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
    if (children.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.child_care,
              size: 80,
              color: provider.textMutedColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No children added yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: provider.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add your first child',
              style: TextStyle(
                fontSize: 14,
                color: provider.textMutedColor,
              ),
            ),
          ],
        ),
      );
    }

    // Show children list
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: children.length,
      itemBuilder: (context, index) {
        final child = children[index];
        return _buildChildCard(context, provider, child);
      },
    );
  }

  Widget _buildChildCard(
    BuildContext context,
    AppProvider provider,
    api.Student child,
  ) {
    return Dismissible(
      key: Key(child.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Child?'),
            content: Text('Are you sure you want to remove ${child.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        final success = await provider.deleteChildAPI(child.id);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${child.name} removed')),
          );
        }
      },
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(
          context,
          '/child-profile',
          arguments: {'childId': child.id},
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: provider.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundImage: child.photo != null
                    ? NetworkImage(child.photo!)
                    : null,
                backgroundColor: const Color(0xFF6B9B5B).withOpacity(0.2),
                child: child.photo == null
                    ? const Icon(
                        Icons.person,
                        color: Color(0xFF6B9B5B),
                        size: 32,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: provider.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      child.schoolName ?? 'No School',
                      style: TextStyle(
                        fontSize: 13,
                        color: provider.textMutedColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      child.className,
                      style: TextStyle(
                        fontSize: 12,
                        color: provider.textMutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: provider.textMutedColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddChildDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddChildForm(),
    );
  }
}

/// Add Child Form with Validation
class AddChildForm extends StatefulWidget {
  const AddChildForm({super.key});

  @override
  State<AddChildForm> createState() => _AddChildFormState();
}

class _AddChildFormState extends State<AddChildForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _classController = TextEditingController();
  final _schoolController = TextEditingController();
  final _pickupController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _classController.dispose();
    _schoolController.dispose();
    _pickupController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDarkMode = provider.isDarkMode;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: provider.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Child',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: provider.textColor,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: provider.textMutedColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your child\'s details below',
                  style: TextStyle(
                    fontSize: 14,
                    color: provider.textMutedColor,
                  ),
                ),
                const SizedBox(height: 24),

                // Name Field
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'e.g. John Doe',
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter child\'s name';
                    }
                    if (value.trim().length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),

                // Class Field
                _buildTextField(
                  controller: _classController,
                  label: 'Class/Grade',
                  hint: 'e.g. Class 4 West',
                  icon: Icons.school,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter class or grade';
                    }
                    return null;
                  },
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),

                // School Field
                _buildTextField(
                  controller: _schoolController,
                  label: 'School (Optional)',
                  hint: 'e.g. Ozone Valley Day School',
                  icon: Icons.account_balance,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),

                // Pickup Location Field
                _buildTextField(
                  controller: _pickupController,
                  label: 'Pickup Location (Optional)',
                  hint: 'e.g. Home Address',
                  icon: Icons.location_on,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),

                // Emergency Contact Section
                Text(
                  'Emergency Contact (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: provider.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _emergencyContactController,
                  label: 'Contact Name',
                  hint: 'e.g. Jane Doe',
                  icon: Icons.contact_phone,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _emergencyPhoneController,
                  label: 'Contact Phone',
                  hint: 'e.g. +254 712 345 678',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      // Simple phone validation
                      final phoneRegex = RegExp(r'^[+\d\s\-\(\)]{10,}$');
                      if (!phoneRegex.hasMatch(value)) {
                        return 'Please enter a valid phone number';
                      }
                    }
                    return null;
                  },
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B9B5B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor:
                          const Color(0xFF6B9B5B).withOpacity(0.5),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Add Child',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDarkMode,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF6B9B5B)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<AppProvider>();

    final student = await provider.addChildAPI(
      name: _nameController.text.trim(),
      className: _classController.text.trim(),
      schoolId: _schoolController.text.trim().isEmpty
          ? null
          : _schoolController.text.trim(),
      pickupLocation: _pickupController.text.trim().isEmpty
          ? null
          : _pickupController.text.trim(),
      emergencyContact: _emergencyContactController.text.trim().isEmpty
          ? null
          : _emergencyContactController.text.trim(),
      emergencyPhone: _emergencyPhoneController.text.trim().isEmpty
          ? null
          : _emergencyPhoneController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (student != null && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${student.name} added successfully!')),
      );
    }
  }
}
