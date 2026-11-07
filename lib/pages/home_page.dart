import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/draft_service.dart';
import '../services/session.dart';
import '../services/token_service.dart';
import '../services/toaster_service.dart';
import '../ui/nv.dart';
import 'account_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.draft});

  /// An unfinished entry to reopen on top (Android closed the app while writing)
  final JournalDraft? draft;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _pageSize = 20;

  // Entries
  final List<Map<String, dynamic>> _journals = [];
  bool _isLoading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;

  // Search
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;
  String _query = '';

  // Overview
  Map<String, dynamic>? _stats;
  Map<String, DayInfo>? _activity;
  bool _activityLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAll();
    final draft = widget.draft;
    if (draft != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open('/journal-entry', arguments: draft);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocus.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAll(quiet: true);
  }

  Future<void> _refreshAll({bool quiet = false}) => Future.wait([
    _fetchJournals(quiet: quiet),
    _fetchOverview(),
  ]);

  Future<void> _fetchOverview() async {
    final token = await TokenService.getCurrentToken();
    if (token.isEmpty) return;
    final results = await Future.wait([
      ApiService.getDashboard(token),
      loadActivity(token).then<Object?>((v) => v),
    ]);
    if (!mounted) return;
    final dash = results[0] as Map<String, dynamic>;
    setState(() {
      if (dash['success'] == true && dash['data'] is Map) {
        _stats = Map<String, dynamic>.from(dash['data']);
      }
      _activity = results[1] as Map<String, DayInfo>?;
      _activityLoading = false;
    });
  }

  Future<void> _fetchJournals({bool quiet = false, bool more = false}) async {
    if (more) {
      if (_loadingMore || _page >= _totalPages) return;
      setState(() => _loadingMore = true);
    } else if (!quiet) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final token = await TokenService.getCurrentToken();
      if (token.isEmpty) throw Exception('signed out');
      final query = _query;
      final result = await ApiService.getJournals(
        token,
        page: more ? _page + 1 : 1,
        limit: _pageSize,
        search: query.isEmpty ? null : query,
      );
      if (!mounted || query != _query) return;

      if (result['success'] == true) {
        final data = (result['data'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final pagination = result['pagination'] as Map? ?? const {};
        setState(() {
          if (!more) _journals.clear();
          _journals.addAll(data);
          _page = (pagination['page'] as num?)?.toInt() ?? (more ? _page + 1 : 1);
          _totalPages = (pagination['totalPages'] as num?)?.toInt() ?? 1;
          _total = (pagination['total'] as num?)?.toInt() ?? _journals.length;
          _error = null;
        });
      } else if (result['requires_auth_redirect'] == true) {
        final authToken = await TokenService.getAuthToken();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/pin-verification', (r) => false, arguments: authToken);
        }
        return;
      } else if (!quiet) {
        setState(() => _error = (result['message'] ?? 'Couldn’t load your entries').toString());
      }
    } catch (_) {
      if (mounted && !quiet) setState(() => _error = 'Couldn’t reach Notevia. Check your connection.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || value.trim() == _query) return;
      setState(() => _query = value.trim());
      _fetchJournals();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchDebounce?.cancel();
    setState(() => _query = '');
    _fetchJournals();
  }

  Future<void> _open(String route, {Object? arguments}) async {
    _searchFocus.unfocus();
    final changed = await Navigator.of(context).pushNamed(route, arguments: arguments);
    if (changed == true && mounted) _refreshAll(quiet: true);
  }

  Future<void> _delete(Map<String, dynamic> journal) async {
    final id = journal['id'] as int?;
    if (id == null) return;
    final title = (journal['title'] ?? 'this entry').toString();
    final ok = await showNvConfirm(
      context,
      title: 'Delete entry?',
      message: '“$title” and its photos will be deleted. This can’t be undone.',
      confirmLabel: 'Delete entry',
    );
    if (!ok || !mounted) return;
    final token = await TokenService.getCurrentToken();
    final result = await ApiService.deleteJournal(token, id);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _journals.removeWhere((j) => j['id'] == id);
        _total = (_total - 1).clamp(0, 1 << 30);
      });
      ToasterService.showSuccess(context, 'Entry deleted');
      _fetchOverview();
    } else {
      ToasterService.showError(context, (result['message'] ?? 'Couldn’t delete the entry').toString());
    }
  }

  void _entryActions(Map<String, dynamic> journal) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(NvSpace.md, 0, NvSpace.md, NvSpace.md),
        child: NvBox(
          children: [
            NvRow(
              title: 'Edit',
              leading: Icons.edit_outlined,
              onTap: () {
                Navigator.pop(sheet);
                _open('/journal-entry', arguments: journal);
              },
            ),
            NvRow(
              title: 'Delete',
              leading: Icons.delete_outline,
              destructive: true,
              onTap: () {
                Navigator.pop(sheet);
                _delete(journal);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _menu() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(NvSpace.md, 0, NvSpace.md, NvSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NvBox(
              children: [
                NvRow(
                  title: 'Profile',
                  leading: Icons.person_outline,
                  showChevron: true,
                  onTap: () {
                    Navigator.pop(sheet);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountPage()));
                  },
                ),
                NvRow(
                  title: 'Settings',
                  leading: Icons.settings_outlined,
                  showChevron: true,
                  onTap: () {
                    Navigator.pop(sheet);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
                  },
                ),
              ],
            ),
            const SizedBox(height: NvSpace.sm),
            NvBox(
              children: [
                NvRow(
                  title: 'Sign out',
                  leading: Icons.logout,
                  destructive: true,
                  onTap: () async {
                    Navigator.pop(sheet);
                    final ok = await showNvConfirm(
                      context,
                      title: 'Sign out?',
                      message: 'You’ll need your email, password and PIN to sign back in. Phone unlock will be turned off.',
                      confirmLabel: 'Sign out',
                    );
                    if (ok && mounted) Session.signOut(Navigator.of(context));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: NvSpace.gutter,
        title: const NvLogo(size: 26),
        shape: Border(bottom: BorderSide(color: c.lineMuted)),
        actions: [
          NvIconButton(icon: Icons.lock_outline, label: 'Lock now', onPressed: Session.lock),
          NvIconButton(icon: Icons.more_horiz, label: 'Menu', onPressed: _menu),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open('/journal-entry'),
        icon: const Icon(Icons.edit_outlined, size: 20),
        label: const Text('New entry'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _searchFocus.unfocus(),
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          color: c.accent,
          backgroundColor: c.surface2,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(NvSpace.gutter, NvSpace.md, NvSpace.gutter, 0),
                sliver: SliverList.list(
                  children: [
                    _overview(c),
                    const NvSectionHeader('Activity'),
                    NvBox(
                      padding: const EdgeInsets.all(NvSpace.sm),
                      children: [
                        NvActivityCalendar(
                          days: _activity,
                          loading: _activityLoading,
                          onRetry: () {
                            setState(() => _activityLoading = true);
                            _fetchOverview();
                          },
                        ),
                      ],
                    ),
                    NvSectionHeader(
                      'Entries',
                      trailing: _isLoading
                          ? null
                          : Text(
                              _query.isEmpty ? '$_total' : '$_total found',
                              style: NvText.meta.copyWith(color: c.muted),
                            ),
                    ),
                    _searchField(c),
                    const SizedBox(height: NvSpace.sm),
                  ],
                ),
              ),
              ..._entries(c),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overview(NvColors c) {
    String figure(String key) {
      final v = _stats?[key];
      return v is num ? '${v.toInt()}' : '–';
    }

    final streak = (_stats?['writingStreak'] as num?)?.toInt() ?? 0;
    Widget stat(String value, String label, {Widget? icon}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: NvSpace.sm, vertical: NvSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[icon, const SizedBox(width: 4)],
                Flexible(
                  child: Text(
                    _stats == null ? '–' : value,
                    style: NvText.figure.copyWith(color: c.fg),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: NvText.meta.copyWith(color: c.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );

    Widget split() => Container(width: 1, height: 40, color: c.lineMuted);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NvRadius.control),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          stat(
            figure('writingStreak'),
            'Day streak',
            icon: Icon(
              Icons.local_fire_department,
              size: 18,
              color: streak > 0 ? c.attention : c.subtle,
            ),
          ),
          split(),
          stat(figure('totalJournals'), 'Entries'),
          split(),
          stat(figure('journalsThisWeek'), 'This week'),
        ],
      ),
    );
  }

  Widget _searchField(NvColors c) => SizedBox(
    height: NvSize.control,
    child: TextField(
      controller: _searchController,
      focusNode: _searchFocus,
      onChanged: _onSearchChanged,
      textInputAction: TextInputAction.search,
      style: NvText.small.copyWith(color: c.fg),
      decoration: InputDecoration(
        hintText: 'Search entries',
        hintStyle: NvText.small.copyWith(color: c.subtle),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        prefixIcon: Icon(Icons.search, size: 18, color: c.muted),
        prefixIconConstraints: const BoxConstraints(minWidth: 38),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (_, v, _) => v.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: _clearSearch,
                  icon: Icon(Icons.close, size: 18, color: c.muted),
                ),
        ),
      ),
    ),
  );

  List<Widget> _entries(NvColors c) {
    Widget pad(Widget child) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: NvSpace.gutter),
      sliver: child,
    );

    if (_isLoading) {
      return [
        pad(SliverList.builder(
          itemCount: 5,
          itemBuilder: (_, i) => _EntryFrame(first: i == 0, last: i == 4, child: const _EntrySkeleton()),
        )),
      ];
    }
    if (_error != null) {
      return [
        SliverToBoxAdapter(
          child: NvEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Couldn’t load your entries',
            message: _error,
            actionLabel: 'Try again',
            secondary: true,
            onAction: _fetchJournals,
          ),
        ),
      ];
    }
    if (_journals.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _query.isNotEmpty
              ? NvEmptyState(
                  icon: Icons.search_off,
                  title: 'No entries match “$_query”',
                  message: 'Try a different word, or clear the search.',
                  actionLabel: 'Clear search',
                  secondary: true,
                  onAction: _clearSearch,
                )
              : NvEmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No entries yet',
                  message: 'What happened today? Your first entry starts your streak.',
                  actionLabel: 'Write your first entry',
                  onAction: () => _open('/journal-entry'),
                ),
        ),
      ];
    }

    final hasMore = _page < _totalPages;
    return [
      pad(SliverList.builder(
        itemCount: _journals.length,
        itemBuilder: (context, i) {
          if (hasMore && i == _journals.length - 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _fetchJournals(more: true));
          }
          final j = _journals[i];
          return _EntryFrame(
            first: i == 0,
            last: i == _journals.length - 1,
            child: _EntryRow(
              journal: j,
              onTap: () => _open('/journal-detail', arguments: j['id']),
              onLongPress: () => _entryActions(j),
            ),
          );
        },
      )),
      if (_loadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(NvSpace.lg),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        ),
    ];
  }
}

/// One continuous bordered list: rows share borders, only the ends are rounded.
class _EntryFrame extends StatelessWidget {
  const _EntryFrame({required this.first, required this.last, required this.child});
  final bool first;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    const r = Radius.circular(NvRadius.control);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          left: BorderSide(color: c.line),
          right: BorderSide(color: c.line),
          top: first ? BorderSide(color: c.line) : BorderSide.none,
          bottom: BorderSide(color: last ? c.line : c.lineMuted),
        ),
        borderRadius: BorderRadius.vertical(top: first ? r : Radius.zero, bottom: last ? r : Radius.zero),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

const _monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String shortDate(Object? raw) {
  final d = DateTime.tryParse(raw?.toString() ?? '');
  if (d == null) return '';
  final now = DateTime.now();
  final base = '${_monthsShort[d.month - 1]} ${d.day}';
  return d.year == now.year ? base : '$base, ${d.year}';
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.journal, required this.onTap, required this.onLongPress});
  final Map<String, dynamic> journal;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    final title = (journal['title'] ?? '').toString().trim();
    final preview = plainPreview((journal['content'] ?? '').toString());
    final mood = MoodX.parse(journal['mood']);
    final media = journal['media'] is List ? (journal['media'] as List) : const [];
    final firstImage = media.isNotEmpty && media.first is Map ? (media.first['url'] ?? '').toString() : '';

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(NvSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            title.isEmpty ? 'Untitled' : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NvText.bodyStrong.copyWith(color: c.fg),
                          ),
                        ),
                        const SizedBox(width: NvSpace.xs),
                        Text(shortDate(journal['journal_date']), style: NvText.meta.copyWith(color: c.muted)),
                      ],
                    ),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: NvText.small.copyWith(color: c.muted),
                      ),
                    ],
                    if (mood != null || media.isNotEmpty) ...[
                      const SizedBox(height: NvSpace.xs),
                      Row(
                        children: [
                          if (mood != null) NvMoodTag(mood),
                          if (mood != null && media.isNotEmpty) const SizedBox(width: NvSpace.md),
                          if (media.isNotEmpty) ...[
                            Icon(Icons.image_outlined, size: 15, color: c.muted),
                            const SizedBox(width: 4),
                            Text(
                              media.length == 1 ? '1 photo' : '${media.length} photos',
                              style: NvText.meta.copyWith(color: c.muted),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (firstImage.isNotEmpty) ...[
                const SizedBox(width: NvSpace.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    firstImage,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    cacheWidth: 168,
                    errorBuilder: (_, _, _) => Container(width: 56, height: 56, color: c.surface2),
                    loadingBuilder: (_, child, p) =>
                        p == null ? child : Container(width: 56, height: 56, color: c.surface2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EntrySkeleton extends StatelessWidget {
  const _EntrySkeleton();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(NvSpace.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [NvSkeleton(width: 160, height: 14), Spacer(), NvSkeleton(width: 40, height: 12)]),
        SizedBox(height: 10),
        NvSkeleton(height: 12),
        SizedBox(height: 6),
        NvSkeleton(width: 220, height: 12),
      ],
    ),
  );
}
