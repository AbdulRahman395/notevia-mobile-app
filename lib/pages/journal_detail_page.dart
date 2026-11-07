import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/toaster_service.dart';
import '../ui/nv.dart';
import '../widgets/full_screen_image_viewer.dart';

class JournalDetailPage extends StatefulWidget {
  final int journalId;

  const JournalDetailPage({super.key, required this.journalId});

  @override
  State<JournalDetailPage> createState() => _JournalDetailPageState();
}

class _JournalDetailPageState extends State<JournalDetailPage> {
  Map<String, dynamic>? _journal;
  bool _isLoading = true;
  String? _error;

  /// Tells the list to refresh when we go back (after an edit or delete)
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _fetchJournal();
  }

  Future<void> _fetchJournal() async {
    setState(() {
      _isLoading = _journal == null;
      _error = null;
    });
    try {
      final token = await TokenService.getCurrentToken();
      final result = await ApiService.getJournalById(token, widget.journalId);
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() => _journal = Map<String, dynamic>.from(result['data']));
      } else if (result['requires_auth_redirect'] == true) {
        final authToken = await TokenService.getAuthToken();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/pin-verification', (r) => false, arguments: authToken);
        }
      } else {
        setState(() => _error = (result['message'] ?? 'Couldn’t load this entry').toString());
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn’t reach Notevia. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).pushNamed('/journal-entry', arguments: _journal);
    if (updated == true && mounted) {
      _changed = true;
      _fetchJournal();
    }
  }

  Future<void> _delete() async {
    final ok = await showNvConfirm(
      context,
      title: 'Delete entry?',
      message: 'This entry and its photos will be deleted. This can’t be undone.',
      confirmLabel: 'Delete entry',
    );
    if (!ok || !mounted) return;
    final token = await TokenService.getCurrentToken();
    final result = await ApiService.deleteJournal(token, widget.journalId);
    if (!mounted) return;
    if (result['success'] == true) {
      ToasterService.showSuccess(context, 'Entry deleted');
      Navigator.of(context).pop(true);
    } else {
      ToasterService.showError(context, (result['message'] ?? 'Couldn’t delete the entry').toString());
    }
  }

  Future<void> _copy() async {
    final j = _journal!;
    final text = '${j['title'] ?? ''}\n${_longDate(j['journal_date'])}\n\n${normalizeContent((j['content'] ?? '').toString())}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) ToasterService.showSuccess(context, 'Entry copied');
  }

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  String _longDate(Object? raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '';
    return '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _stamp(Object? raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '${_months[d.month - 1]} ${d.day}, ${d.year} at $h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          shape: Border(bottom: BorderSide(color: c.lineMuted)),
          actions: _journal == null
              ? null
              : [
                  NvIconButton(icon: Icons.edit_outlined, label: 'Edit entry', onPressed: _edit),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_horiz, size: 22),
                    position: PopupMenuPosition.under,
                    onSelected: (v) => v == 'copy' ? _copy() : _delete(),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'copy', child: Text('Copy text')),
                      PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: c.danger))),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
        ),
        body: _body(c),
      ),
    );
  }

  Widget _body(NvColors c) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(NvSpace.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NvSkeleton(width: 180, height: 12),
            SizedBox(height: 14),
            NvSkeleton(width: 260, height: 22),
            SizedBox(height: 28),
            NvSkeleton(height: 12),
            SizedBox(height: 8),
            NvSkeleton(height: 12),
            SizedBox(height: 8),
            NvSkeleton(width: 200, height: 12),
          ],
        ),
      );
    }
    if (_error != null || _journal == null) {
      return Center(
        child: NvEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Couldn’t load this entry',
          message: _error,
          actionLabel: 'Try again',
          secondary: true,
          onAction: _fetchJournal,
        ),
      );
    }

    final j = _journal!;
    final mood = MoodX.parse(j['mood']);
    final media = j['media'] is List ? (j['media'] as List).whereType<Map>().toList() : const <Map>[];
    final created = _stamp(j['created_at']);
    final updated = j['updated_at'] != null && j['updated_at'] != j['created_at'] ? _stamp(j['updated_at']) : '';
    final title = (j['title'] ?? '').toString().trim();

    return RefreshIndicator(
      onRefresh: _fetchJournal,
      color: c.accent,
      backgroundColor: c.surface2,
      child: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(NvSpace.gutter, NvSpace.lg, NvSpace.gutter, NvSpace.xxl),
          children: [
            Text(_longDate(j['journal_date'] ?? j['created_at']), style: NvText.meta.copyWith(color: c.muted)),
            const SizedBox(height: NvSpace.xs),
            Text(title.isEmpty ? 'Untitled' : title, style: NvText.display.copyWith(color: c.fg)),
            if (mood != null) ...[
              const SizedBox(height: NvSpace.sm),
              Align(alignment: Alignment.centerLeft, child: NvMoodTag(mood)),
            ],
            const SizedBox(height: NvSpace.lg),
            Divider(height: 1, color: c.lineMuted),
            const SizedBox(height: NvSpace.lg),
            NvMarkdownView((j['content'] ?? '').toString()),
            if (media.isNotEmpty) ...[
              const SizedBox(height: NvSpace.xl),
              Text(media.length == 1 ? '1 photo' : '${media.length} photos', style: NvText.label.copyWith(color: c.fg)),
              const SizedBox(height: NvSpace.sm),
              SelectionContainer.disabled(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: NvSpace.xs,
                    mainAxisSpacing: NvSpace.xs,
                  ),
                  itemCount: media.length,
                  itemBuilder: (context, i) {
                    final url = (media[i]['url'] ?? '').toString();
                    final tag = 'journal_image_${media[i]['id']}_$i';
                    return Semantics(
                      button: true,
                      label: 'Open photo ${i + 1}',
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: url, heroTag: tag)),
                        ),
                        child: Hero(
                          tag: tag,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(NvRadius.control),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              cacheWidth: 600,
                              errorBuilder: (_, _, _) => Container(
                                color: c.surface2,
                                child: Icon(Icons.broken_image_outlined, color: c.subtle),
                              ),
                              loadingBuilder: (_, child, p) => p == null ? child : Container(color: c.surface2),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (created.isNotEmpty) ...[
              const SizedBox(height: NvSpace.xl),
              Divider(height: 1, color: c.lineMuted),
              const SizedBox(height: NvSpace.md),
              Text('Written $created', style: NvText.meta.copyWith(color: c.muted)),
              if (updated.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Edited $updated', style: NvText.meta.copyWith(color: c.muted)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
