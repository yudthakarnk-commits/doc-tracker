import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
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
  List<Map<String, dynamic>> _announcements = [];
  Set<String> _readAnn = {};

  @override
  void initState() {
    super.initState();
    DataService.instance.loadAll();
    _loadProfile();
    _loadAnnouncements();
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
      // Display name lives in auth user metadata (profiles has no name column)
      final metaName = sb.auth.currentUser?.userMetadata?['name']?.toString();
      final p = await sb.from('profiles').select().eq('id', uid).maybeSingle();
      if (mounted) {
        setState(() {
          _profileName = (metaName != null && metaName.trim().isNotEmpty)
              ? metaName
              : null;
          _profileRole = p?['role']?.toString();
        });
      }
    } catch (_) {}
  }

  // ── Announcements (Supabase `announcements` table; silent if absent) ──
  Future<void> _loadAnnouncements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _readAnn = (prefs.getStringList('readAnnouncements') ?? []).toSet();
      final rows = await Supabase.instance.client
          .from('announcements')
          .select()
          .eq('active', true)
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted) {
        setState(() => _announcements =
            List<Map<String, dynamic>>.from(rows as List));
      }
    } catch (_) {} // table may not exist yet — bell just shows empty state
  }

  int get _unreadCount => _announcements
      .where((a) => !_readAnn.contains(a['id'].toString()))
      .length;

  Future<void> _openAnnouncements() async {
    // Opening the panel marks everything as read
    final prefs = await SharedPreferences.getInstance();
    _readAnn.addAll(_announcements.map((a) => a['id'].toString()));
    await prefs.setStringList('readAnnouncements', _readAnn.toList());
    if (mounted) setState(() {});
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (c, scroll) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text('🔔 ${tr('announcements')}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: _announcements.isEmpty
                  ? Center(
                      child: Text(tr('noAnnouncements'),
                          style: const TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _announcements.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (c, i) {
                        final a = _announcements[i];
                        final date =
                            (a['created_at']?.toString() ?? '').split('T')[0];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(
                                          a['title']?.toString() ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14))),
                                  Text(date,
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                ]),
                                if ((a['body']?.toString() ?? '')
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(a['body'].toString(),
                                      style: const TextStyle(
                                          fontSize: 13, height: 1.5)),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
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
                        // profiles has no name column — store in auth metadata
                        await sb.auth.updateUser(UserAttributes(
                            data: {'name': nameCtl.text.trim()}));
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
            onPressed: () {
              DataService.instance.loadAll(force: true);
              _loadAnnouncements();
            },
          ),
          IconButton(
            tooltip: tr('announcements'),
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text('$_unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: _openAnnouncements,
          ),
          // ── Avatar + submenu (Profile / Theme / Sign out) ──
          Padding(
            padding: const EdgeInsets.only(right: 10, left: 2),
            child: PopupMenuButton<String>(
              tooltip: _displayName,
              offset: const Offset(0, 46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onSelected: (v) {
                if (v == 'profile') _openProfileDialog();
                if (v == 'theme') toggleTheme();
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
                      const Text('v${AppConfig.appVersion}',
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey)),
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
                  value: 'theme',
                  child: Row(children: [
                    Icon(
                        themeMode.value == ThemeMode.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        size: 18),
                    const SizedBox(width: 10),
                    Text(themeMode.value == ThemeMode.dark
                        ? 'Light mode'
                        : 'Dark mode'),
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
