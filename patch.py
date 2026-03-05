import re

with open('active_trip_old.dart', 'r', encoding='utf-8') as f:
    old_code = f.read()

with open('lib/screens/main/active_trip_screen.dart', 'r', encoding='utf-8') as f:
    new_code = f.read()

# Make sure we don't have duplicated _showStudentList and _completeTrip
# First extract the old methods
match_methods = re.search(r'  /// Show student list bottom sheet\n  void _showStudentList\(\) \{.*?(?=^\}\n\n/// Student List Bottom Sheet)', old_code, re.DOTALL | re.MULTILINE)
if not match_methods:
    print("Methods not found")
    exit(1)
old_methods = match_methods.group(0)

# Replace the old completeTrip inside old_methods with the new one but using the dialog check
new_complete_trip = """
  Future<void> _completeTrip() async {
    setState(() => _isEndingTrip = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _CompleteTripDialog(
          tripName: _activeTrip?.routeName ?? 'Trip',
          totalStudents: _totalCount,
          pickedCount: _pickedCount,
          absentCount: _totalCount - _pickedCount,
        ),
      );

      if (confirmed == true && mounted) {
        HapticFeedback.heavyImpact();

        // Show trip summary before navigating away
        await _showTripSummary();

        if (mounted) {
          final authProvider = context.read<AuthProvider>();
          final driverId = authProvider.userData['id']?.toString();
          final driverName = authProvider.userData['name']?.toString();

          final tripProvider = context.read<TripProvider>();
          final success = await tripProvider.endTrip(
            _tripId!,
            driverId: driverId,
            driverName: driverName,
          );

          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trip completed successfully'),
                  backgroundColor: Color(0xFF6B9B5B),
                ),
              );
              Navigator.pushReplacementNamed(context, '/dashboard');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to complete trip: ${tripProvider.errorMessage ?? "Unknown error"}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isEndingTrip = false);
    }
  }
"""

old_methods = re.sub(r'  Future<void> _completeTrip\(\) async \{.*?(?=^\s+/// Navigate to next unprocessed stop)', new_complete_trip, old_methods, flags=re.DOTALL | re.MULTILINE)

# Extract old classes
match_classes = re.search(r'/// Student List Bottom Sheet.*', old_code, re.DOTALL)
old_classes = match_classes.group(0)

# Remove the old completeTrip and _showStudentList from the new_code
# They are at the end of _ActiveTripScreenState
start_idx = new_code.find('  // Helper methods (simplified for brevity)\n  void _showStudentList() {')
if start_idx == -1:
    start_idx = new_code.find('  void _showStudentList() {')

# Find the end of the class
end_idx = new_code.rfind('}')

patched_new_code = new_code[:start_idx] + old_methods + '\n}\n\n' + old_classes

with open('lib/screens/main/active_trip_screen.dart', 'w', encoding='utf-8') as f:
    f.write(patched_new_code)

print("Patched successfully")
