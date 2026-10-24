import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/ai_mark.dart';
import '../core/theme.dart';
import 'analysis.dart';
import 'assistant.dart';
import '../services/native_bridge.dart';
import 'dashboard.dart';
import 'more.dart';
import 'transactions.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLaunchAction());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkLaunchAction();
  }

  /// Tombol "+ Catat" di widget layar utama membuka form transaksi baru.
  Future<void> _checkLaunchAction() async {
    final a = await NativeBridge.launchAction();
    if (a == 'quick_add' && mounted) openNewTx(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: [
        DashboardPage(onTab: (v) => setState(() => _i = v)),
        const TransactionsPage(),
        const AssistantPage(),
        const AnalysisPage(),
        const MorePage(),
      ]),
      floatingActionButton: IgnorePointer(
        ignoring: !(_i == 0 || _i == 1),
        child: AnimatedScale(
          scale: (_i == 0 || _i == 1) ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => openNewTx(context),
            icon: const Icon(Icons.add),
            label: const Text('Catat'),
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.soft(.6))),
        ),
        child: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) {
          HapticFeedback.selectionClick();
          setState(() => _i = v);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transaksi'),
          NavigationDestination(icon: AiSparkle(size: 23), selectedIcon: AiSparkle(size: 25), label: 'Asisten'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Analisis'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Lainnya'),
        ],
        ),
      ),
    );
  }
}
