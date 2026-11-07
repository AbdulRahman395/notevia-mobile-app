import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/app_lock_service.dart';
import '../services/draft_service.dart';
import '../services/token_service.dart';
import '../services/toaster_service.dart';
import '../ui/nv.dart';

/// Write or edit an entry. A plain writing surface: one scroll, no boxes.
///
/// Text selection is reliable because the body field grows with its text
/// (the page is the only thing that scrolls) and nothing rewrites the text
/// while you type.
class JournalEntryPage extends StatefulWidget {
  final Map<String, dynamic>? journalData;

  /// Unfinished text to restore (Android closed the app while writing)
  final JournalDraft? draft;

  const JournalEntryPage({super.key, this.journalData, this.draft});

  @override
  State<JournalEntryPage> createState() => _JournalEntryPageState();
}

class _JournalEntryPageState extends State<JournalEntryPage> with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _bodyController = MarkdownEditingController();
  final _undo = UndoHistoryController();
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();
  final _picker = ImagePicker();

  late DateTime _date;
  Mood? _mood;
  final List<File> _newImages = [];
  List<String> _existingImages = [];
  final List<String> _imagesToDelete = [];
  bool _saving = false;

  // The draft kept on the phone while writing
  Timer? _draftTimer;
  bool _closed = false;

  // What the entry looked like when the page opened, to know if anything changed
  late final String _initialTitle;
  late final String _initialBody;
  late final DateTime _initialDate;
  Mood? _initialMood;

  bool get _isEdit => widget.journalData != null;

  @override
  void initState() {
    super.initState();
    final j = widget.journalData;
    _date = _dateOnly(DateTime.now());
    if (j != null) {
      _titleController.text = (j['title'] ?? '').toString();
      _bodyController.text = normalizeContent((j['content'] ?? '').toString());
      final parsed = DateTime.tryParse((j['journal_date'] ?? '').toString());
      if (parsed != null) _date = _dateOnly(parsed);
      _mood = MoodX.parse(j['mood']);
      if (j['media'] is List) {
        _existingImages = (j['media'] as List)
            .whereType<Map>()
            .map((m) => (m['url'] ?? '').toString())
            .where((u) => u.isNotEmpty)
            .toList();
      }
    }
    _initialTitle = _titleController.text;
    _initialBody = _bodyController.text;
    _initialDate = _date;
    _initialMood = _mood;

    // Put back what was being written when Android closed the app
    final d = widget.draft;
    if (d != null) {
      _titleController.text = d.title;
      _bodyController.text = d.body;
      _date = _dateOnly(d.date);
      _mood = d.mood == null ? null : MoodX.parse(d.mood);
      _newImages.addAll(d.newImagePaths.map(File.new));
      for (final url in d.imagesToDelete) {
        if (_existingImages.remove(url)) _imagesToDelete.add(url);
      }
      _bodyController.selection = TextSelection.collapsed(offset: _bodyController.text.length);
    }
    WidgetsBinding.instance.addObserver(this);
    // The formatting toolbar shows while writing the body
    _bodyFocus.addListener(() {
      if (mounted) super.setState(() {});
    });

    // Rebuild for the word count and the Save state, on text changes only
    _titleController.addListener(_onText);
    _bodyController.addListener(_onText);
    if (d != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bodyFocus.requestFocus());
    } else if (!_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _titleFocus.requestFocus());
    }
  }

  String _lastTitle = '';
  String _lastBody = '';
  void _onText() {
    // Controllers also notify on cursor moves; only rebuild when text changed
    if (_titleController.text == _lastTitle && _bodyController.text == _lastBody) return;
    _lastTitle = _titleController.text;
    _lastBody = _bodyController.text;
    setState(() {});
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _scheduleDraft();
  }

  // Keep the draft a moment after each change, and at once when the app leaves
  // the screen: Android may close it in the background without warning.
  void _scheduleDraft() {
    if (_closed) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 800), _writeDraft);
  }

  void _writeDraft() {
    _draftTimer?.cancel();
    if (_closed) return;
    if (!_dirty) {
      DraftService.clear();
      return;
    }
    DraftService.save(
      JournalDraft(
        title: _titleController.text,
        body: _bodyController.markdown,
        date: _date,
        mood: _mood?.label,
        journal: widget.journalData,
        newImagePaths: _newImages.map((f) => f.path).toList(),
        imagesToDelete: List.of(_imagesToDelete),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _writeDraft();
  }

  /// The entry was saved or discarded: forget the draft.
  void _close() {
    _closed = true;
    _draftTimer?.cancel();
    DraftService.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    _undo.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _dirty =>
      _titleController.text != _initialTitle ||
      _bodyController.text != _initialBody ||
      _date != _initialDate ||
      _mood != _initialMood ||
      _newImages.isNotEmpty ||
      _imagesToDelete.isNotEmpty;

  int get _words => RegExp(r'\S+').allMatches(_bodyController.text).length;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String get _dateLabel {
    final today = _dateOnly(DateTime.now());
    if (_date == today) return 'Today';
    if (_date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    final base = '${_weekdays[_date.weekday - 1]}, ${_months[_date.month - 1]} ${_date.day}';
    return _date.year == today.year ? base : '$base, ${_date.year}';
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: _dateOnly(DateTime.now()),
      helpText: 'Entry date',
    );
    if (picked != null) setState(() => _date = _dateOnly(picked));
  }

  Future<void> _pickImage() async {
    try {
      // The picker sends the app to the background; don't lock for that
      final image = await AppLockService().runExcused(
        () => _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 82),
      );
      if (image != null && mounted) setState(() => _newImages.add(File(image.path)));
    } catch (_) {
      if (mounted) {
        ToasterService.showError(context, 'Couldn’t open your photos. Check Notevia’s photo permission in Settings.');
      }
    }
  }

  String _toApiContent(String text) => text.trim().replaceAll('\n', '\r\n');

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    final body = _bodyController.markdown.trim();
    String? problem;
    if (title.isEmpty) {
      problem = 'Add a title';
      _titleFocus.requestFocus();
    } else if (body.isEmpty) {
      problem = 'Write something first';
      _bodyFocus.requestFocus();
    } else if (_mood == null) {
      problem = 'Pick a mood';
    }
    if (problem != null) {
      ToasterService.showError(context, problem);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final token = await TokenService.getCurrentToken();
      final apiDate =
          '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

      final Map<String, dynamic> result;
      if (_isEdit) {
        final j = widget.journalData!;
        result = await ApiService.updateJournal(
          token,
          j['id'] as int,
          title: title != _initialTitle.trim() ? title : null,
          content: _bodyController.markdown != _initialBody ? _toApiContent(body) : null,
          journalDate: _date != _initialDate ? apiDate : null,
          mood: _mood != _initialMood ? _mood!.label : null,
          newImageFiles: _newImages.isNotEmpty ? _newImages : null,
          imagesToDelete: _imagesToDelete.isNotEmpty ? _imagesToDelete : null,
        );
      } else {
        result = await ApiService.createJournal(
          token,
          title,
          _toApiContent(body),
          apiDate,
          mood: _mood!.label,
          imageFiles: _newImages.isNotEmpty ? _newImages : null,
        );
      }
      if (!mounted) return;

      if (result['success'] == true) {
        _close();
        ToasterService.showSuccess(context, _isEdit ? 'Entry updated' : 'Entry saved');
        Navigator.of(context).pop(true);
      } else if (result['requires_auth_redirect'] == true) {
        ToasterService.showError(context, 'Your session expired. Enter your PIN, then save again.');
      } else {
        ToasterService.showError(context, (result['message'] ?? 'Couldn’t save the entry').toString());
      }
    } catch (_) {
      if (mounted) ToasterService.showError(context, 'Couldn’t reach Notevia. Your text is still here; try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLeave() async {
    final discard = await showNvConfirm(
      context,
      title: 'Discard changes?',
      message: 'What you wrote since opening this entry will be lost.',
      confirmLabel: 'Discard',
    );
    if (discard && mounted) {
      _close();
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _close();
        } else {
          _confirmLeave();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(_isEdit ? 'Edit entry' : 'New entry'),
          shape: Border(bottom: BorderSide(color: c.lineMuted)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: NvSpace.sm),
              child: NvButton(label: 'Save', loading: _saving, onPressed: _isEdit && !_dirty ? null : _save),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                // Tapping the empty space under the text continues writing
                onTap: () => _bodyFocus.requestFocus(),
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
                  padding: const EdgeInsets.fromLTRB(NvSpace.gutter, NvSpace.md, NvSpace.gutter, NvSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _metaRow(c),
                      const SizedBox(height: NvSpace.md),
                      TextField(
                        controller: _titleController,
                        focusNode: _titleFocus,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _bodyFocus.requestFocus(),
                        maxLines: null,
                        style: NvText.display.copyWith(color: c.fg),
                        decoration: _bare('Title', NvText.display),
                      ),
                      const SizedBox(height: NvSpace.xs),
                      TextField(
                        controller: _bodyController,
                        focusNode: _bodyFocus,
                        undoController: _undo,
                        inputFormatters: [MarkdownListFormatter()],
                        contextMenuBuilder: (context, state) => markdownContextMenu(context, state, _bodyController),
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        minLines: 12,
                        style: NvText.body.copyWith(color: c.text, height: 1.6),
                        decoration: _bare('What happened today?', NvText.body.copyWith(height: 1.6)),
                      ),
                      if (_existingImages.isNotEmpty || _newImages.isNotEmpty) ...[
                        const SizedBox(height: NvSpace.md),
                        _photos(c),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _toolbar(c),
          ],
        ),
      ),
    );
  }

  InputDecoration _bare(String hint, TextStyle style) => InputDecoration(
    hintText: hint,
    hintStyle: style.copyWith(color: context.nv.subtle),
    filled: false,
    isCollapsed: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 6),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
  );

  Widget _metaRow(NvColors c) {
    Widget chip({
      required Widget child,
      required VoidCallback onTap,
      required String semantics,
      bool selected = false,
    }) => Semantics(
      button: true,
      selected: selected,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: selected ? c.accentSoft : c.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NvRadius.pill),
          side: BorderSide(color: selected ? c.accent : c.line),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [child]),
            ),
          ),
        ),
      ),
    );

    return Wrap(
      spacing: NvSpace.xs,
      runSpacing: NvSpace.xs,
      children: [
        chip(
          semantics: 'Entry date, $_dateLabel. Change',
          onTap: _pickDate,
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 15, color: c.muted),
              const SizedBox(width: 6),
              Text(_dateLabel, style: NvText.meta.copyWith(color: c.fg)),
            ],
          ),
        ),
        for (final m in Mood.values)
          chip(
            semantics: 'Mood ${m.label}',
            selected: _mood == m,
            onTap: () => setState(() => _mood = _mood == m ? null : m),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: m.color(c), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(m.label, style: NvText.meta.copyWith(color: c.fg)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _photos(NvColors c) {
    Widget tile(ImageProvider image, VoidCallback onRemove, String label) => Padding(
      padding: const EdgeInsets.only(right: NvSpace.xs),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(NvRadius.control),
            child: Image(
              image: image,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(width: 88, height: 88, color: c.surface2),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Semantics(
              button: true,
              label: 'Remove $label',
              child: GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: c.surface2,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.line),
                    ),
                    child: Icon(Icons.close, size: 14, color: c.fg),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(top: 6),
        children: [
          for (var i = 0; i < _existingImages.length; i++)
            tile(NetworkImage(_existingImages[i]), () {
              setState(() => _imagesToDelete.add(_existingImages.removeAt(i)));
            }, 'photo ${i + 1}'),
          for (var i = 0; i < _newImages.length; i++)
            tile(FileImage(_newImages[i]), () {
              setState(() => _newImages.removeAt(i));
            }, 'new photo ${i + 1}'),
        ],
      ),
    );
  }

  Widget _toolbar(NvColors c) {
    _bodyController
      ..colors = c
      ..ruleWidth = MediaQuery.sizeOf(context).width - 2 * NvSpace.gutter - 4;
    final writing = _bodyFocus.hasFocus;
    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.lineMuted)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: writing
              ? MarkdownToolbar(
                  controller: _bodyController,
                  undo: _undo,
                  leading: [
                    NvIconButton(icon: Icons.add_photo_alternate_outlined, label: 'Add photo', onPressed: _pickImage),
                  ],
                )
              : _infoBar(c),
        ),
      ),
    );
  }

  Widget _infoBar(NvColors c) => Row(
    children: [
      const SizedBox(width: 4),
      NvIconButton(icon: Icons.add_photo_alternate_outlined, label: 'Add photo', onPressed: _pickImage),
      const Spacer(),
      Text(
        _words == 1 ? '1 word' : '$_words words',
        style: NvText.meta.copyWith(color: c.muted, fontFeatures: const [FontFeature.tabularFigures()]),
      ),
      const SizedBox(width: NvSpace.gutter),
    ],
  );
}
