import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/audio_service.dart';
import '../../core/theme/neo_colors.dart';
import '../../shared/widgets/neo_app_bar.dart';
import '../ai_advisor/screens/ai_advisor_screen.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../reports/screens/reports_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../transactions/screens/transactions_screen.dart';

/// Indeks tab aktif di MainScreen (dipakai juga oleh deep-link Widget Beranda)
final mainTabIndexProvider = StateProvider<int>((ref) => 0);

class MainScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<String> _titles = [
    'Beranda',
    'Transaksi',
    'Penasihat AI',
    'Laporan',
    'Pengaturan',
  ];

  final List<Widget> _screens = const [
    DashboardScreen(),
    TransactionsScreen(),
    AiAdvisorScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(mainTabIndexProvider.notifier).state = widget.initialIndex;
        }
      });
    }
  }

  void _onTabSelected(int index) {
    final currentIndex = ref.read(mainTabIndexProvider);
    if (currentIndex == index) return;
    AudioService().playClickSound();
    ref.read(mainTabIndexProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainTabIndexProvider);

    return Scaffold(
      appBar: NeoAppBar(
        title: _titles[currentIndex],
        onAvatarTap: () => _onTabSelected(4), // Buka Pengaturan saat avatar ditekan
      ),
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: NeoColors.surface(context),
          border: Border(
            top: BorderSide(color: NeoColors.border(context), width: 4.0),
          ),
          boxShadow: const [
            BoxShadow(
              color: NeoColors.black,
              offset: Offset(0, -2),
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              _buildNavItem(currentIndex, 0, Icons.home_outlined, Icons.home, 'Beranda'),
              _buildNavItem(currentIndex, 1, Icons.swap_horiz, Icons.swap_horiz, 'Transaksi'),
              _buildNavItem(currentIndex, 2, Icons.smart_toy_outlined, Icons.smart_toy, 'Mentor AI'),
              _buildNavItem(currentIndex, 3, Icons.bar_chart_outlined, Icons.bar_chart, 'Laporan'),
              _buildNavItem(currentIndex, 4, Icons.settings_outlined, Icons.settings, 'Pengaturan'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int currentIndex,
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isSelected = currentIndex == index;
    final mutedCol = NeoColors.mutedText(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabSelected(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: isSelected ? NeoColors.primaryBlueLight : Colors.transparent,
              border: Border.all(
                color: isSelected ? NeoColors.black : Colors.transparent,
                width: 2.0,
              ),
              boxShadow: isSelected ? NeoColors.hardShadow(offset: 2.0) : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 22,
                  color: isSelected ? NeoColors.black : mutedCol,
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? NeoColors.textDark : mutedCol,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

