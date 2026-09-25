import 'package:flutter/material.dart';
import '../api/services/student_service.dart' as api;
import '../theme/app_spacing.dart';
import '../theme/app_theme_extension.dart';
import 'ui/ui.dart';

enum AddStudentAction { pick, drop }

/// Case-insensitive "contains" on name or reg number, skipping students
/// already on the trip. Empty query lists everyone.
List<api.Student> filterAddableStudents(
  List<api.Student> all,
  String query,
  Set<String> excludeIds,
) {
  final q = query.trim().toLowerCase();
  return all.where((s) {
    if (excludeIds.contains(s.id)) return false;
    if (q.isEmpty) return true;
    return s.name.toLowerCase().contains(q) ||
        (s.studentRegNumber ?? '').toLowerCase().contains(q);
  }).toList();
}

/// Search the school's students as you type, pick one, then choose Pick or
/// Drop. Returns null if dismissed.
Future<({api.Student student, AddStudentAction action})?>
showAddTripStudentSheet(
  BuildContext context, {
  required Future<List<api.Student>> students,
  required Set<String> excludeIds,
  required AddStudentAction suggested,
}) {
  return showAppBottomSheet(
    context: context,
    builder: (_) => _AddTripStudentSheet(
      students: students,
      excludeIds: excludeIds,
      suggested: suggested,
    ),
  );
}

class _AddTripStudentSheet extends StatefulWidget {
  const _AddTripStudentSheet({
    required this.students,
    required this.excludeIds,
    required this.suggested,
  });

  final Future<List<api.Student>> students;
  final Set<String> excludeIds;
  final AddStudentAction suggested;

  @override
  State<_AddTripStudentSheet> createState() => _AddTripStudentSheetState();
}

class _AddTripStudentSheetState extends State<_AddTripStudentSheet> {
  String _query = '';
  api.Student? _selected;

  @override
  Widget build(BuildContext context) {
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.4;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Add student to trip', style: context.text.titleLarge),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          hint: 'Type a student name or reg no.',
          prefixIcon: Icons.search_rounded,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() {
            _query = v;
            _selected = null;
          }),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_selected == null)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: FutureBuilder<List<api.Student>>(
              future: widget.students,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return EmptyState(
                    compact: true,
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load students',
                    message: '${snap.error}',
                  );
                }
                final matches = filterAddableStudents(
                  snap.data ?? const [],
                  _query,
                  widget.excludeIds,
                );
                if (matches.isEmpty) {
                  return const EmptyState(
                    compact: true,
                    icon: Icons.person_search_rounded,
                    title: 'No matching students',
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: matches.length,
                  itemBuilder: (context, i) => _StudentRow(
                    student: matches[i],
                    onTap: () => setState(() => _selected = matches[i]),
                  ),
                );
              },
            ),
          )
        else ...[
          _StudentRow(
            student: _selected!,
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Choose another',
              onPressed: () => setState(() => _selected = null),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final action in AddStudentAction.values) ...[
                if (action != AddStudentAction.values.first)
                  const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: action == AddStudentAction.pick
                        ? 'Add & pick'
                        : 'Add & drop',
                    icon: action == AddStudentAction.pick
                        ? Icons.directions_bus_rounded
                        : Icons.home_rounded,
                    variant: action == widget.suggested
                        ? AppButtonVariant.primary
                        : AppButtonVariant.outline,
                    onPressed: () => Navigator.pop(context, (
                      student: _selected!,
                      action: action,
                    )),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student, this.onTap, this.trailing});

  final api.Student student;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      student.className,
      student.studentRegNumber ?? '',
    ].where((s) => s.isNotEmpty).join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AppAvatar(imageUrl: student.photo, name: student.name, size: 40),
      title: Text(student.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
