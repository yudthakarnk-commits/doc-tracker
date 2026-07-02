import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../i18n.dart';
import '../main.dart';
import '../services/data_service.dart';
import 'dashboard_screen.dart';
import 'entry_screen.dart';
import 'summary_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    DataService.instance.loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final titles = [tr('dashboard'), tr('entry'), tr('summary')];
    return Scaffold(
      appBar: AppBar(
        title: Text('🐣 ${titles[_index]}'),
        actions: [
          IconButton(
            tooltip: 'TH/EN',
            icon: Text(lang.value == 'th' ? 'EN' : 'ไทย',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800)),
            onPressed: () => setLang(lang.value == 'th' ? 'en' : 'th'),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => DataService.instance.loadAll(force: true),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeMode,
            builder: (context, mode, _) => IconButton(
              tooltip: mode == ThemeMode.dark ? 'Light mode' : 'Dark mode',
              icon: Icon(mode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined),
              onPressed: toggleTheme,
            ),
          ),
          IconButton(
            tooltip: tr('signOut'),
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(tr('signOutConfirm')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text(tr('cancel'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(tr('signOut'))),
                  ],
                ),
              );
              if (ok == true) {
                await Supabase.instance.client.auth.signOut();
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          EntryScreen(),
          SummaryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: tr('dashboard')),
          NavigationDestination(
              icon: const Icon(Icons.list_alt_outlined),
              selectedIcon: const Icon(Icons.list_alt),
              label: tr('entry')),
          NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: const Icon(Icons.bar_chart),
              label: tr('summary')),
        ],
      ),
    );
  }
}
