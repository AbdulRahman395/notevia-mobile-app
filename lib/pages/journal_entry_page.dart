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
  bool _showCalendar = false;
  String _selectedMood = '';
  final ImagePicker _imagePicker = ImagePicker();

  // Edit mode variables
  bool _isEditMode = false;
  Map<String, dynamic>? _originalJournalData;
  List<String> _originalImages = [];
  List<String> _imagesToDelete = [];

  @override
  void initState() {
    super.initState();
    // Set default date to today
    _selectedDate = DateTime.now();
    _focusedDay = DateTime.now();

    // Debug: Check if we received journal data
    print(
      'JournalEntryPage initState - widget.journalData: ${widget.journalData}',
    );

    // Check if we're in edit mode
    if (widget.journalData != null) {
      _isEditMode = true;
      _originalJournalData = widget.journalData;
      print('Edit mode detected, populating fields...');
      _populateFieldsFromJournalData();
    } else {
      print('No journal data received - create mode');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _thoughtsController.dispose();
    super.dispose();
  }

  void _populateFieldsFromJournalData() {
    if (_originalJournalData == null) {
      print('No original journal data to populate');
      return;
    }

    final journal = _originalJournalData!;
    print('Populating fields from journal data: $journal');

    // Populate text fields
    final title = journal['title'] ?? '';
    final content = _stripHtmlTags(journal['content'] ?? '');
    print('Setting title: "$title"');
    print('Setting content: "$content"');

    _titleController.text = title;
    _thoughtsController.text = content;

    // Set date
    if (journal['journal_date'] != null) {
      try {
        final dateStr = journal['journal_date'];
        print('Setting date: $dateStr');
        _selectedDate = DateTime.parse(dateStr);
        _focusedDay = _selectedDate!;
      } catch (e) {
        print('Error parsing date: $e');
      }
    }

    // Set mood
    final mood = journal['mood'] ?? '';
    print('Setting mood: "$mood"');
    _selectedMood = mood;

    // Store original images
    if (journal['media'] != null && journal['media'] is List) {
      _originalImages = (journal['media'] as List)
          .map((media) => media['url'] as String? ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
      print('Found ${_originalImages.length} original images');
    }

    print('Field population completed');
    print('Title controller text: "${_titleController.text}"');
    print('Thoughts controller text: "${_thoughtsController.text}"');
    print('Selected mood: "$_selectedMood"');

    // Trigger a rebuild to ensure the UI updates with the populated data
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
      _showCalendar = false; // Hide calendar after selection
    });
  }

  void _toggleCalendar() {
    setState(() {
      _showCalendar = !_showCalendar;
    });
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
        });
      }
    } catch (e) {
      print('Image picker error: $e');
      _showError('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    return Future.value();
  }

  Future<void> _removeOriginalImage(int index) {
    setState(() {
      final imageUrl = _originalImages[index];
      _originalImages.removeAt(index);
      _imagesToDelete.add(imageUrl);
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

  Color _getMoodBackgroundColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return const Color(0xFF81C784); // More vibrant green
      case 'sad':
        return const Color(0xFFE57373); // More vibrant red
      case 'neutral':
        return const Color(0xFF90A4AE); // More vibrant blue-grey
      case 'calm':
        return const Color(0xFF64B5F6); // More vibrant sky blue
      default:
        return Colors.amber[200]!; // More visible default color
    }
  }

  Widget _buildMoodCircle(String moodName, String emoji, double circleSize) {
    final isSelected = _selectedMood == moodName;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMood = moodName;
        });
      },
      child: Container(
        width: circleSize,
        height: circleSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? _getMoodBackgroundColor(moodName)
              : _getMoodBackgroundColor(moodName).withOpacity(0.3),
          border: Border.all(
            color: isSelected
                ? _getMoodBackgroundColor(moodName)
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(
              fontSize: circleSize * 0.4, // 40% of circle size (smaller emojis)
              color: null, // Use default emoji colors
            ),
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
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
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveJournal,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field
              const Text(
                'Title',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Enter journal title...',
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: Colors.blue[400]!,
                      width: 2.0,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [UpperCaseFirstLetterFormatter()],
              ),

              const SizedBox(height: 12),

              // Date Field
              const Text(
                'Date',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[300]!, width: 1.0),
                ),
                child: Column(
                  children: [
                    // Clickable date display
                    InkWell(
                      onTap: _toggleCalendar,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.grey[600],
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedDate != null
                                  ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                  : 'Select date...',
                              style: TextStyle(
                                color: _selectedDate != null
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.4),
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              _showCalendar
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.grey[600],
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Calendar (shown conditionally)
                    if (_showCalendar)
                      TableCalendar(
                        firstDay: DateTime.utc(2000, 1, 1),
                        lastDay: DateTime.utc(2100, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) {
                          return isSameDay(_selectedDate, day);
                        },
                        onDaySelected: _onDaySelected,
                        onFormatChanged: (format) {
                          setState(() {
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
                            fontSize: 14,
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
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                          weekendStyle: TextStyle(
                            fontSize: 11,
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
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          weekendTextStyle: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          outsideTextStyle: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          selectedTextStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                          todayTextStyle: TextStyle(
                            fontSize: 12,
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

              const SizedBox(height: 16),

              // Thoughts Field
              const Text(
                'Thoughts',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _thoughtsController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Write your thoughts here...',
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1.0,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: Colors.blue[400]!,
                      width: 2.0,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [UpperCaseFirstLetterFormatter()],
              ),

              const SizedBox(height: 16),

              // Mood Selection
              const Text(
                'Mood',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate responsive sizing
                  double screenWidth = constraints.maxWidth;
                  double circleSize = screenWidth < 400 ? 45.0 : 50.0;
                  double spacing = screenWidth < 400 ? 6.0 : 8.0;

                  return Container(
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!, width: 1.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildMoodCircle('Happy', '😍', circleSize),
                        SizedBox(width: spacing),
                        _buildMoodCircle('Sad', '😢', circleSize),
                        SizedBox(width: spacing),
                        _buildMoodCircle('Neutral', '😐', circleSize),
                        SizedBox(width: spacing),
                        _buildMoodCircle('Calm', '☺️', circleSize),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Image Upload Section
              const Text(
                'Images',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              if (_selectedImages.isNotEmpty ||
                  (_isEditMode && _originalImages.isNotEmpty))
                Column(
                  children: [
                    // Display existing images in edit mode
                    if (_isEditMode && _originalImages.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _originalImages.length,
                          itemBuilder: (context, index) {
                            final imageUrl = _originalImages[index];
                            return Container(
                              width: 90,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1.0,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      imageUrl,
                                      width: 90,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              width: 90,
                                              height: 120,
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeOriginalImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    // Display newly selected images
                    if (_selectedImages.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 90,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.blue[300]!,
                                  width: 2.0,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.file(
                                      _selectedImages[index],
                                      width: 90,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                    // Add more images button
                    if (_isEditMode && _originalImages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: InkWell(
                          onTap: _pickImage,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: double.infinity,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Add More Images',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              else
                InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: double.infinity,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1.0,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 32,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add Images',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to select from gallery',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
