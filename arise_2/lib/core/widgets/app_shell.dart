import 'package:flutter/material.dart';
import '../theme/arise_colors.dart';
import '../services/system_metrics_service.dart';
import '../services/model_service.dart';
import '../services/weather_service.dart';
import 'global_top_bar.dart';
import '../../features/dashboard/dashboard_page.dart';

/// The main app shell with a global top bar, sidebar navigation, and content.
/// Layout: Column → [GlobalTopBar, Expanded(Row → [Sidebar, Content])]
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  // Services — owned by the shell so they persist across page changes
  final _metricsService = SystemMetricsService();
  final _weatherService = WeatherService();

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.apps_rounded, label: 'Applications'),
    _NavItem(icon: Icons.bolt_rounded, label: 'Automation'),
    _NavItem(icon: Icons.shield_rounded, label: 'Security'),
    _NavItem(icon: Icons.memory_rounded, label: 'Memory'),
    _NavItem(icon: Icons.extension_rounded, label: 'Plugins'),
    _NavItem(icon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _metricsService.startPolling();
    _weatherService.startPolling();
  }

  @override
  void dispose() {
    _metricsService.dispose();
    _weatherService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AriseColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Global Top Bar ──
          GlobalTopBar(
            metricsService: _metricsService,
            modelService: modelService,
            weatherService: _weatherService,
          ),
          // ── Horizontal glow separator ──
          Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AriseColors.primaryContainer,
                  Colors.transparent,
                ],
                stops: [0.1, 0.5, 0.9],
              ),
            ),
          ),
          // ── Sidebar + Content ──
          Expanded(
            child: Row(
              children: [
                _buildSidebar(),
                // Vertical separator glow line
                Container(
                  width: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AriseColors.primaryContainer,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      color: AriseColors.surfaceContainerLow,
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Nav Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _navItems.length,
              itemBuilder: (context, index) => _buildNavItem(index),
            ),
          ),
          // Logout
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: _buildNavItem(
              -1,
              item: const _NavItem(
                icon: Icons.logout_rounded,
                label: 'Log Out',
              ),
              isLogout: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, {_NavItem? item, bool isLogout = false}) {
    final navItem = item ?? _navItems[index];
    final isSelected = !isLogout && index == _selectedIndex;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (!isLogout) setState(() => _selectedIndex = index);
          },
          hoverColor: AriseColors.surfaceContainer,
          splashColor: AriseColors.primaryContainer.withValues(alpha: 0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? AriseColors.surfaceContainer
                  : Colors.transparent,
              border: isSelected
                  ? Border(
                      left: BorderSide(
                        color: AriseColors.primaryContainer,
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  navItem.icon,
                  size: 20,
                  color: isSelected
                      ? AriseColors.primaryContainer
                      : isLogout
                      ? AriseColors.error
                      : AriseColors.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Text(
                  navItem.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? AriseColors.primary
                        : isLogout
                        ? AriseColors.error
                        : AriseColors.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AriseColors.primaryContainer,
                      boxShadow: [
                        BoxShadow(
                          color: AriseColors.primaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedIndex == 0) {
      return DashboardPage(metricsService: _metricsService);
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _navItems[_selectedIndex].icon,
            size: 48,
            color: AriseColors.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _navItems[_selectedIndex].label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AriseColors.onSurfaceVariant.withValues(alpha: 0.5),
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Module loading...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AriseColors.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
