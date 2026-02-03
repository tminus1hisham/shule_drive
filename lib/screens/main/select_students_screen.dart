import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/student.dart';
import '../../providers/app_provider.dart';
import '../../widgets/main_scaffold.dart';

class SelectStudentsScreen extends StatefulWidget {
  const SelectStudentsScreen({super.key});

  @override
  State<SelectStudentsScreen> createState() => _SelectStudentsScreenState();
}

class _SelectStudentsScreenState extends State<SelectStudentsScreen> {
  int _currentIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  List<Student> students = [
    Student(
      id: '1',
      name: 'Mary Mwasuga',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=5',
      status: StudentStatus.pending,
    ),
    Student(
      id: '2',
      name: 'Mary Mwasuga',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=9',
      status: StudentStatus.pending,
    ),
    Student(
      id: '3',
      name: 'Mary Mwasuga',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=8',
      status: StudentStatus.pending,
    ),
    Student(
      id: '4',
      name: 'Mary Mwasuga',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=3',
      status: StudentStatus.pending,
    ),
  ];

  List<Student> selectedStudents = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleStudent(Student student) {
    setState(() {
      if (selectedStudents.contains(student)) {
        selectedStudents.remove(student);
      } else {
        selectedStudents.add(student);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return MainScaffold(
      title: 'Select Students',
      showBackButton: true,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Students scheduled for this trip.',
                    style: TextStyle(fontSize: 14, color: provider.textMutedColor),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: provider.cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: provider.textColor),
                      decoration: InputDecoration(
                        hintText: 'Search Students',
                        hintStyle: TextStyle(
                          color: provider.textMutedColor,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: provider.textMutedColor,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Selected Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Students added to the list',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: provider.textColor,
                        ),
                      ),
                      Text(
                        '${selectedStudents.length}/${students.length}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppProvider.primaryGreen,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Students List
                  ...students.map((student) => _buildStudentCard(student, provider)),
                ],
              ),
            ),
          ),

          // Bottom Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: provider.cardColor,
              boxShadow: [
                BoxShadow(
                  color: provider.isDarkMode
                      ? Colors.black.withAlpha(51)
                      : Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: selectedStudents.isNotEmpty
                      ? () => Navigator.pushNamed(context, '/active-trip')
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppProvider.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: provider.isDarkMode
                        ? Colors.grey[800]
                        : const Color(0xFFE0E0E0),
                  ),
                  child: Text(
                    'Start Trip (${selectedStudents.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Student student, AppProvider provider) {
    final isSelected = selectedStudents.contains(student);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: provider.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: AppProvider.primaryGreen, width: 2)
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: NetworkImage(student.avatar),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: provider.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  student.className,
                  style: TextStyle(
                    fontSize: 14,
                    color: provider.textMutedColor,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggleStudent(student),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppProvider.primaryGreen
                    : const Color(0xFFFF9800),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isSelected ? 'Added' : 'Add',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
