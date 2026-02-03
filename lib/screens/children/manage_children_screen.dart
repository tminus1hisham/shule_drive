import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final children = provider.children;

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
        onPressed: () {},
        backgroundColor: const Color(0xFF6B9B5B),
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: children.length,
        itemBuilder: (context, index) {
          final child = children[index];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/child-profile'),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: provider.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: NetworkImage(child.avatar),
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
                          child.school,
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
          );
        },
      ),
    );
  }
}
