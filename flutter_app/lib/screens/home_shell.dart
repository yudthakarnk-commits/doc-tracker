import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../i18n.dart';
import '../main.dart';
import '../services/data_service.dart';
import 'dashboard_screen.dart';
import 'entry_screen.dart';
import 'summary_screen.dart';
import 'transport_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  String? _profileName;
  String? _profileRole;

  @override
  void initState() {
    super.initState();
    DataService.instance.loadAll();
    _loadProfile();
    // Rebuild this shell AND its child pages when the language changes —
    // const child instances would otherwise be skipped by the framework.
    lang.addListener(_onLangChanged);
  }

  @override
  void dispose() {
    lang.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProfile() async {
    try {
      final sb = Supabase.instance.client;
      final uid = sb.auth.currentUser?.id;
      if (uid == null) return;
      final p = await sb.from('profiles').select().eq('id', uid).maybeSingle();
      if (mounted && p != null) {
        setState(() {
          _profileName = p['name']?.toString();
          _profileRole = p['role']?.toString();
        });
      }
    } catch (_) {}
  }

  String get _email =>
      Supabase.instance.client.auth.currentUser?.email ?? '';

  String get _displayName =>
      (_profileName != null && _profileName!.trim().isNotEmpty)
          ? _profileName!.trim()
          : _email;

  String get _initials {
    final n = _displayName.trim();
    if (n.isEmpty) return '?';
    final words = n.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    return n.substring(0, n.length >= 2 ? 2 : 1).toUpperCase();
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('signOutConfirm')),
        content: Text(_email),
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
  }

  Future<void> _openProfileDialog() async {
    final nameCtl = TextEditingController(text: _profileName ?? '');
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDlg) => AlertDialog(
          title: Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF2563EB),
              child: Text(_initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(tr('profile'),
                    style: const TextStyle(fontSize: 18))),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameCtl,
                decoration: InputDecoration(labelText: tr('nameLbl')),
              ),
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.mail_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_email,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey))),
              ]),
              if (_profileRole != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.verified_user_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: _profileRole == 'admin'
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(_profileRole!.toUpperCase(),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _profileRole == 'admin'
                                ? const Color(0xFF92400E)
                                : const Color(0xFF3730A3))),
                  ),
                ]),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(tr('cancel'))),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDlg(() => saving = true);
                      try {
                        final sb = Supabase.instance.client;
                        await sb.from('profiles').update(
                            {'name': nameCtl.text.trim()}).eq(
                            'id', sb.auth.currentUser!.id);
                        if (mounted) {
                          setState(() =>
                              _profileName = nameCtl.text.trim());
                        }
                        if (c.mounted) Navigator.pop(c);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(tr('profileSaved'))));
                        }
                      } catch (e) {
                        setDlg(() => saving = false);
                        if (c.mounted) {
                          ScaffoldMessenger.of(c).showSnackBar(
                              SnackBar(content: Text('❌ $e')));
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      tr('dashboard'),
      tr('entry'),
      tr('summary'),
      tr('transport')
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset('assets/icon.png',
                width: 26, height: 26, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(titles[_index],
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          TextButton.icon(
            onPressed: () => setLang(lang.value == 'th' ? 'en' : 'th'),
            icon: const Icon(Icons.translate, size: 17),
            label: Text(lang.value == 'th' ? 'TH' : 'EN',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800)),
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
          // ── Avatar + submenu (Profile / Sign out) ──
          Padding(
            padding: const EdgeInsets.only(right: 10, left: 2),
            child: PopupMenuButton<String>(
              tooltip: _displayName,
              offset: const Offset(0, 46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onSelected: (v) {
                if (v == 'profile') _openProfileDialog();
                if (v == 'signout') _confirmSignOut();
              },
              itemBuilder: (c) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(_email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(children: [
                    const Icon(Icons.person_outline, size: 18),
                    const SizedBox(width: 10),
                    Text(tr('profile')),
                  ]),
                ),
                PopupMenuItem<String>(
                  value: 'signout',
                  child: Row(children: [
                    const Icon(Icons.logout, size: 18, color: Colors.red),
                    const SizedBox(width: 10),
                    Text(tr('signOut'),
                        style: const TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
              child: CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFF2563EB),
                child: Text(_initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        // NOT const — fresh (non-identical) instances make the framework
        // re-run each page's build() with the new language strings, while
        // State (search text, selected week) is preserved.
        children: [
          DashboardScreen(),
          EntryScreen(),
          SummaryScreen(),
          TransportScreen(),
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
          NavigationDestination(
              icon: const Icon(Icons.local_shipping_outlined),
              selectedIcon: const Icon(Icons.local_shipping),
              label: tr('transport')),
        ],
      ),
    );
  }
}
