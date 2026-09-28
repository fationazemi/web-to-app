import 'package:flutter/material.dart';

import 'canvas_screen.dart';
import 'drawings_screen.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Root scaffold with the four tabs and the central "new sketch" button.
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
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onNavigate: _go),
          const DrawingsScreen(),
          const ExploreScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Home', selected: _index == 0, onTap: () => _go(0)),
                _NavItem(icon: Icons.folder_outlined, label: 'My Drawings', selected: _index == 1, onTap: () => _go(1)),
                Expanded(
                  child: Center(
                    child: Material(
                      color: scheme.primary,
                      shape: const CircleBorder(),
                      elevation: 4,
                      shadowColor: Colors.black38,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _newSketch,
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: Icon(Icons.add, color: scheme.onPrimary, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
                _NavItem(icon: Icons.explore_outlined, label: 'Explore', selected: _index == 2, onTap: () => _go(2)),
                _NavItem(icon: Icons.settings_outlined, label: 'Settings', selected: _index == 3, onTap: () => _go(3)),
              ],
            ),
          ),
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
    final color = selected ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.45);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
