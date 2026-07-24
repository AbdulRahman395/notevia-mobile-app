import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/toaster_service.dart';

class UpperCaseFirstLetterFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // If the text is being typed from the beginning, capitalize the first letter
    if (newValue.selection.start == 0 && newValue.text.length == 1) {
      return TextEditingValue(
        text: newValue.text.toUpperCase(),
        selection: newValue.selection,
      );
    }

    // If the entire text is selected and user starts typing, capitalize first letter
    if (oldValue.selection.start == 0 &&
        oldValue.selection.end == oldValue.text.length) {
      return TextEditingValue(
        text: newValue.text[0].toUpperCase() + newValue.text.substring(1),
        selection: newValue.selection,
      );
    }

    return newValue;
  }
}

class JournalEntryPage extends StatefulWidget {
  final Map<String, dynamic>? journalData;

  const JournalEntryPage({super.key, this.journalData});

  @override
  State<JournalEntryPage> createState() => _JournalEntryPageState();
}

class _JournalEntryPageState extends State<JournalEntryPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _thoughtsController = TextEditingController();
  DateTime? _selectedDate;
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  final List<File> _selectedImages = [];
  bool _isLoading = false;
  String _selectedMood = '';
  final ImagePicker _imagePicker = ImagePicker();

  // Tracks whether any field has changed since load, for the "unsaved changes" pill
  bool _isDirty = false;

  // Edit mode variables
  bool _isEditMode = false;
  Map<String, dynamic>? _originalJournalData;
  List<String> _originalImages = [];
  List<String> _imagesToDelete = [];

  static const List<Map<String, String>> _moods = [
    {'name': 'Happy', 'emoji': '😊'},
    {'name': 'Sad', 'emoji': '😢'},
    {'name': 'Calm', 'emoji': '😌'},
    {'name': 'Neutral', 'emoji': '😐'},
  ];

  @override
  void initState() {
    super.initState();
    // Set default date to today
    _selectedDate = DateTime.now();
    _focusedDay = DateTime.now();

    // Check if we're in edit mode
    if (widget.journalData != null) {
      _isEditMode = true;
      _originalJournalData = widget.journalData;
      _populateFieldsFromJournalData();
    }

    _titleController.addListener(_markDirty);
    _thoughtsController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _titleController.removeListener(_markDirty);
    _thoughtsController.removeListener(_markDirty);
    _titleController.dispose();
    _thoughtsController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty) {
      setState(() {
        _isDirty = true;
      });
    }
  }

  void _populateFieldsFromJournalData() {
    if (_originalJournalData == null) return;

    final journal = _originalJournalData!;

    // Populate text fields
    final title = journal['title'] ?? '';
    final content = _stripHtmlTags(journal['content'] ?? '');

    _titleController.text = title;
    _thoughtsController.text = content;

    // Set date
    if (journal['journal_date'] != null) {
      try {
        final dateStr = journal['journal_date'];
        _selectedDate = DateTime.parse(dateStr);
        _focusedDay = _selectedDate!;
      } catch (e) {
        // ignore malformed date
      }
    }

    // Set mood
    final mood = journal['mood'] ?? '';
    _selectedMood = mood;

    // Store original images
    if (journal['media'] != null && journal['media'] is List) {
      _originalImages = (journal['media'] as List)
          .map((media) => media['url'] as String? ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
    }

    if (mounted) {
      setState(() {});
    }
  }

  String _stripHtmlTags(String htmlText) {
    final RegExp exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlText.replaceAll(exp, '').trim();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDate = selectedDay;
      _focusedDay = focusedDay;
      _isDirty = true;
    });
    Navigator.of(context).pop();
  }

  Future<void> _openDatePickerSheet() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    TableCalendar(
                      firstDay: DateTime.utc(2000, 1, 1),
                      lastDay: DateTime.utc(2100, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDate, day),
                      onDaySelected: _onDaySelected,
                      onFormatChanged: (format) {
                        sheetSetState(() {
                          _calendarFormat = format;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                        weekendStyle: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        selectedDecoration: BoxDecoration(
                          color: Colors.blue[600],
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Colors.blue[100],
                          shape: BoxShape.circle,
                        ),
                        defaultTextStyle: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        weekendTextStyle: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        outsideTextStyle: TextStyle(
                          fontSize: 13,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        selectedTextStyle: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        todayTextStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[600]!,
                        ),
                        markerDecoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickImage() async {
    try {
      // Request permission first
      PermissionStatus status;

      if (Platform.isAndroid) {
        // For Android 13+ use READ_MEDIA_IMAGES, for older versions use READ_EXTERNAL_STORAGE
        status = await Permission.photos.request();
      } else {
        // For iOS
        status = await Permission.photos.request();
      }

      if (status.isDenied) {
        _showError('Photo library permission is required to select images');
        return;
      }

      if (status.isPermanentlyDenied) {
        _showError('Please enable photo library permission in app settings');
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
          _isDirty = true;
        });
      }
    } catch (e) {
      _showError('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _isDirty = true;
    });
    return Future.value();
  }

  Future<void> _removeOriginalImage(int index) {
    setState(() {
      final imageUrl = _originalImages[index];
      _originalImages.removeAt(index);
      _imagesToDelete.add(imageUrl);
      _isDirty = true;
    });
    return Future.value();
  }

  void _showError(String message) {
    ToasterService.showError(context, message);
  }

  void _showSuccess(String message) {
    ToasterService.showSuccess(context, message);
  }

  String _normalizeContentForApi(String content) {
    if (content.isEmpty) return content;

    // Convert single \n to \r\n for consistency
    String normalized = content.replaceAll('\n', '\r\n');

    // Ensure double line breaks for paragraphs (convert multiple \r\n to double \r\n\r\n)
    normalized = normalized.replaceAll(RegExp(r'\r\n{3,}'), '\r\n\r\n');

    return normalized;
  }

  Color _getMoodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return const Color(0xFF66BB6A);
      case 'sad':
        return const Color(0xFF5C9CE6);
      case 'calm':
        return const Color(0xFF4FC3C7);
      case 'neutral':
        return const Color(0xFF9E9E9E);
      default:
        return Colors.amber[600]!;
    }
  }

  Future<void> _saveJournal() async {
    if (_titleController.text.trim().isEmpty) {
      _showError('Please enter a title');
      return;
    }

    if (_thoughtsController.text.trim().isEmpty) {
      _showError('Please enter your thoughts');
      return;
    }

    if (_selectedDate == null) {
      _showError('Please select a date');
      return;
    }

    if (_selectedMood.isEmpty) {
      _showError('Please select a mood');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await TokenService.getCurrentToken();
      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      // Format date for API
      final formattedDate =
          '${_selectedDate!.year.toString().padLeft(4, '0')}-'
          '${_selectedDate!.month.toString().padLeft(2, '0')}-'
          '${_selectedDate!.day.toString().padLeft(2, '0')}';

      // Determine if we're creating or updating
      Map<String, dynamic> result;
      if (_isEditMode) {
        // Update existing journal with only modified fields
        final journalId = _originalJournalData!['id'] as int;

        // Determine which fields have changed
        String? updatedTitle;
        String? updatedContent;
        String? updatedDate;
        String? updatedMood;

        if (_titleController.text.trim() !=
            (_originalJournalData!['title'] ?? '')) {
          updatedTitle = _titleController.text.trim();
        }

        String currentContent = _normalizeContentForApi(
          _thoughtsController.text.trim(),
        );
        if (currentContent !=
            _stripHtmlTags(_originalJournalData!['content'] ?? '')) {
          updatedContent = currentContent;
        }

        if (formattedDate != _originalJournalData!['journal_date']) {
          updatedDate = formattedDate;
        }

        if (_selectedMood != (_originalJournalData!['mood'] ?? '')) {
          updatedMood = _selectedMood.isNotEmpty ? _selectedMood : null;
        }

        result = await ApiService.updateJournal(
          token,
          journalId,
          title: updatedTitle,
          content: updatedContent,
          journalDate: updatedDate,
          mood: updatedMood,
          newImageFiles: _selectedImages.isNotEmpty ? _selectedImages : null,
          imagesToDelete: _imagesToDelete.isNotEmpty ? _imagesToDelete : null,
        );
      } else {
        // Create new journal entry
        result = await ApiService.createJournal(
          token,
          _titleController.text.trim(),
          _normalizeContentForApi(_thoughtsController.text.trim()),
          formattedDate,
          mood: _selectedMood.isNotEmpty ? _selectedMood : null,
          imageFiles: _selectedImages.isNotEmpty ? _selectedImages : null,
        );
      }

      if (mounted) {
        if (result['success']) {
          final successMessage = _isEditMode
              ? 'Journal updated successfully!'
              : 'Journal entry saved successfully!';
          _showSuccess(successMessage);
          setState(() {
            _isDirty = false;
          });
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              // Always return to home page with refresh signal
              Navigator.of(context).pop(true);
            }
          });
        } else if (result['requires_auth_redirect'] == true) {
          // Handle 401 - redirect to PIN verification with auth token
          _showError('Authentication expired. Please verify your PIN.');
          () async {
            final authToken = await TokenService.getAuthToken();
            await Future.delayed(const Duration(seconds: 1));
            if (authToken != null && mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/pin-verification',
                (Route<dynamic> route) => false,
                arguments: authToken,
              );
            }
          }();
        } else {
          _showError(result['message'] ?? 'Failed to save journal entry');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save journal: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  static const List<String> _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _formatFriendlyDate(DateTime date) {
    final weekday = _weekdayNames[date.weekday - 1];
    final month = _monthNames[date.month - 1];
    return '$weekday, $month ${date.day}';
  }

  // ---- UI building blocks -------------------------------------------------

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue[400]),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[400]!, Colors.blue[600]!],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditMode ? '📖 Edit Journal' : '📖 New Journal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'How are you feeling today?',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Text(
                  _selectedDate != null
                      ? _formatFriendlyDate(_selectedDate!)
                      : '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_isDirty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Unsaved',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoodChip(String moodName, String emoji) {
    final isSelected = _selectedMood == moodName;
    final color = _getMoodColor(moodName);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMood = moodName;
          _isDirty = true;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 6),
                  Text(
                    moodName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail({
    required Widget image,
    required VoidCallback onDelete,
    bool highlighted = false,
  }) {
    return Container(
      width: 96,
      height: 96,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: highlighted
            ? Border.all(color: Colors.blue[300]!, width: 2)
            : null,
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(width: 96, height: 96, child: image),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPhotoTile() {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey[300]!,
            style: BorderStyle.solid,
          ),
        ),
        child: Icon(Icons.add, size: 28, color: Colors.grey[500]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyPhotos =
        _selectedImages.isNotEmpty ||
        (_isEditMode && _originalImages.isNotEmpty);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          _isEditMode ? 'Edit Journal Entry' : 'New Journal Entry',
          style: TextStyle(
            color:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: Icon(
            Icons.close,
            color:
                Theme.of(context).appBarTheme.foregroundColor ?? Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header card
                    _buildHeaderCard(),
                    const SizedBox(height: 24),

                    // 2. Mood — placed first among the input sections
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel(Icons.mood, 'How are you feeling?'),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              const spacing = 12.0;
                              final chipWidth =
                                  (constraints.maxWidth - spacing) / 2;
                              return Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                children: _moods.map((m) {
                                  return SizedBox(
                                    width: chipWidth,
                                    child: _buildMoodChip(
                                      m['name']!,
                                      m['emoji']!,
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Title
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel(Icons.edit_outlined, 'Title'),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              hintText: "What's today's story?",
                              hintStyle: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.4),
                                fontSize: 16,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.blue[400]!,
                                  width: 2.0,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                            style: const TextStyle(fontSize: 16),
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.sentences,
                            inputFormatters: [UpperCaseFirstLetterFormatter()],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4. Thoughts — the main focus of the page
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel(Icons.notes_outlined, 'Thoughts'),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _thoughtsController,
                            minLines: 8,
                            maxLines: 12,
                            decoration: InputDecoration(
                              hintText: "Write what's on your mind...",
                              hintStyle: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.4),
                                fontSize: 15,
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Colors.blue[400]!,
                                  width: 2.0,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            style: const TextStyle(fontSize: 15, height: 1.5),
                            textCapitalization: TextCapitalization.sentences,
                            inputFormatters: [UpperCaseFirstLetterFormatter()],
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${_thoughtsController.text.length} characters',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 5. Date
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel(Icons.calendar_today_outlined, 'Date'),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: _openDatePickerSheet,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _selectedDate != null
                                        ? _formatFriendlyDate(_selectedDate!)
                                        : 'Select date...',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.grey[600],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 6. Photos
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel(Icons.photo_outlined, 'Photos'),
                          const SizedBox(height: 16),
                          if (!hasAnyPhotos)
                            Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    size: 40,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Capture today's memories",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add Photos'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[400],
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            SizedBox(
                              height: 96,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  ..._originalImages.asMap().entries.map((e) {
                                    return _buildPhotoThumbnail(
                                      image: Image.network(
                                        e.value,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[200],
                                                child: const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                      ),
                                      onDelete: () =>
                                          _removeOriginalImage(e.key),
                                    );
                                  }),
                                  ..._selectedImages.asMap().entries.map((e) {
                                    return _buildPhotoThumbnail(
                                      image: Image.file(
                                        e.value,
                                        fit: BoxFit.cover,
                                      ),
                                      onDelete: () => _removeImage(e.key),
                                      highlighted: true,
                                    );
                                  }),
                                  _buildAddPhotoTile(),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // 7. Floating / sticky save button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveJournal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[500],
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Save Entry',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
