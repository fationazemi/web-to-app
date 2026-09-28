import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'canvas_screen.dart';
import 'drawings_screen.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Root scaffold with the four tabs and the docked "new sketch" button.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  void _newSketch() => Navigator.of(context).push(CanvasScreen.route());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onNavigate: _go),
          const DrawingsScreen(),
          const ExploreScreen(),
          const SettingsScreen(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: softShadow(context, blur: 16, y: 6, alpha: 0.22),
        ),
        child: FloatingActionButton(
          onPressed: _newSketch,
          heroTag: 'new-sketch',
          shape: const CircleBorder(),
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          tooltip: 'New sketch',
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: theme.cardColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black26,
        elevation: 12,
        height: 66,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: [
            _NavItem(icon: Icons.home_rounded, label: 'Home', selected: _index == 0, onTap: () => _go(0)),
            _NavItem(icon: Icons.folder_outlined, label: 'My Drawings', selected: _index == 1, onTap: () => _go(1)),
            const Spacer(),
            _NavItem(icon: Icons.explore_outlined, label: 'Explore', selected: _index == 2, onTap: () => _go(2)),
            _NavItem(icon: Icons.settings_outlined, label: 'Settings', selected: _index == 3, onTap: () => _go(3)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.42);
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: const Duration(milliseconds: 200),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
