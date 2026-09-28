import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/layout.dart';
import 'canvas_screen.dart';
import 'drawings_screen.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Root scaffold. Phones get a bottom bar with a docked "+" button; wide
/// screens (tablets in landscape, desktops) get a navigation rail.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool? _lockedToPortrait;

  void _go(int index) => setState(() => _index = index);

  void _newSketch() => Navigator.of(context).push(CanvasScreen.route());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Phones stay portrait; tablets may rotate freely.
    final portraitOnly = !Layout.isTablet(context);
    if (_lockedToPortrait != portraitOnly) {
      _lockedToPortrait = portraitOnly;
      SystemChrome.setPreferredOrientations(
        portraitOnly ? const [DeviceOrientation.portraitUp] : const [],
      );
    }
  }

  static const _destinations = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.folder_outlined, Icons.folder_rounded, 'My Drawings'),
    (Icons.explore_outlined, Icons.explore_rounded, 'Explore'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = IndexedStack(
      index: _index,
      children: [
        HomeScreen(onNavigate: _go),
        const DrawingsScreen(),
        const ExploreScreen(),
        const SettingsScreen(),
      ],
    );

    if (Layout.isWide(context)) return _wide(context, pages);
    return _compact(context, pages);
  }

  Widget _wide(BuildContext context, Widget pages) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: theme.cardColor,
            selectedIndex: _index,
            onDestinationSelected: _go,
            labelType: NavigationRailLabelType.all,
            minWidth: 88,
            groupAlignment: -0.6,
            indicatorColor: scheme.primary.withValues(alpha: 0.1),
            selectedIconTheme: IconThemeData(color: scheme.onSurface),
            unselectedIconTheme: IconThemeData(color: scheme.onSurface.withValues(alpha: 0.45)),
            selectedLabelTextStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurface),
            unselectedLabelTextStyle: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.5)),
            leading: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 20),
              child: _NewSketchButton(onPressed: _newSketch),
            ),
            destinations: [
              for (final (icon, selectedIcon, label) in _destinations)
                NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(selectedIcon), label: Text(label)),
            ],
          ),
          VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
          Expanded(child: pages),
        ],
      ),
    );
  }

  Widget _compact(BuildContext context, Widget pages) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBody: true,
      body: pages,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _NewSketchButton(onPressed: _newSketch),
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
            for (var i = 0; i < 2; i++) _NavItem(entry: _destinations[i], selected: _index == i, onTap: () => _go(i)),
            const Spacer(),
            for (var i = 2; i < 4; i++) _NavItem(entry: _destinations[i], selected: _index == i, onTap: () => _go(i)),
          ],
        ),
      ),
    );
  }
}

class _NewSketchButton extends StatelessWidget {
  const _NewSketchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: softShadow(context, blur: 16, y: 6, alpha: 0.22),
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        heroTag: 'new-sketch',
        shape: const CircleBorder(),
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        tooltip: 'New sketch',
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.entry, required this.selected, required this.onTap});

  final (IconData, IconData, String) entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, selectedIcon, label) = entry;
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
              child: Icon(selected ? selectedIcon : icon, color: color, size: 24),
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
