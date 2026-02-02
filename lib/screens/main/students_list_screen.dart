import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/student.dart';
import '../../widgets/bottom_navigation.dart';
import '../../widgets/student_card.dart';

class StudentsListScreen extends StatefulWidget {
  const StudentsListScreen({super.key});

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  List<Student> students = [
    Student(
      id: '1',
      name: 'Mary Mwasuga',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=5',
      status: StudentStatus.picked,
    ),
    Student(
      id: '2',
      name: 'John Mwasuga',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=9',
      status: StudentStatus.absent,
    ),
    Student(
      id: '3',
      name: 'Sarah Mwasuga',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=8',
      status: StudentStatus.picked,
    ),
    Student(
      id: '4',
      name: 'Peter Mwasuga',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=3',
      status: StudentStatus.pending,
    ),
    Student(
      id: '5',
      name: 'Lucy Mwasuga',
      className: 'Class 4 West',
      avatar: 'https://i.pravatar.cc/150?img=12',
      status: StudentStatus.pending,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _updateStudentStatus(String id, StudentStatus status) {
    setState(() {
      final student = students.firstWhere((s) => s.id == id);
      student.status = status;
    });
    HapticFeedback.lightImpact();
  }

  List<Student> _getFilteredStudents() {
    final query = _searchController.text.toLowerCase();
    var filtered = students;
    
    if (query.isNotEmpty) {
      filtered = filtered.where((s) => 
        s.name.toLowerCase().contains(query)
      ).toList();
    }
    
    switch (_tabController.index) {
      case 1:
        return filtered.where((s) => s.status == StudentStatus.picked).toList();
      case 2:
        return filtered.where((s) => s.status == StudentStatus.absent).toList();
      default:
        return filtered;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _getFilteredStudents();
    final pickedCount = students.where((s) => s.status == StudentStatus.picked).length;
    final progress = pickedCount / students.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFFF5F5F0),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF6B9B5B).withValues(alpha: 0.15),
                      const Color(0xFFF5F5F0),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.people_outline,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Students List',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '8:30 AM - South B Route',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6B9B5B).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pickup Progress',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$pickedCount/${students.length}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${(progress * 100).toInt()}% completed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search student...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 15,
                        ),
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B9B5B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.search,
                            color: Color(0xFF6B9B5B),
                            size: 18,
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 56,
                          minHeight: 56,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: const Color(0xFF6B9B5B),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6B9B5B).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: const Color(0xFF666666),
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                      padding: const EdgeInsets.all(4),
                      tabs: [
                        _buildTab('All', students.length),
                        _buildTab('Picked', students.where((s) => s.status == StudentStatus.picked).length),
                        _buildTab('Absent', students.where((s) => s.status == StudentStatus.absent).length),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Students List
                  if (filteredStudents.isEmpty)
                    _buildEmptyState()
                  else
                    ...filteredStudents.map(
                      (student) => StudentCard(
                        student: student,
                        onPick: () => _updateStudentStatus(student.id, StudentStatus.picked),
                        onAbsent: () => _updateStudentStatus(student.id, StudentStatus.absent),
                        onCall: () {},
                      ),
                    ),
                    
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            Navigator.pushNamed(context, '/chat');
          } else if (index == 3) {
            Navigator.pushNamed(context, '/profile');
          }
        },
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.pushReplacementNamed(context, '/landing'),
          backgroundColor: const Color(0xFF6B9B5B),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text(
            'Complete Trip',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _tabController.index == _tabController.animation?.value?.round()
                  ? Colors.white.withValues(alpha: 0.3)
                  : const Color(0xFF6B9B5B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _tabController.index == _tabController.animation?.value?.round()
                    ? Colors.white
                    : const Color(0xFF6B9B5B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF6B9B5B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_outlined,
              size: 48,
              color: Color(0xFF6B9B5B),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No students found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try adjusting your search',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
