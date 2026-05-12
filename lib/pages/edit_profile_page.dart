import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/toaster_service.dart';
import '../services/image_compression_service.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const EditProfilePage({super.key, required this.profileData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  DateTime? _selectedDate;
  File? _newProfilePicture;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data
    _fullNameController.text = widget.profileData['full_name'] ?? '';
    _bioController.text = widget.profileData['bio'] ?? '';

    // Parse existing date of birth if available
    if (widget.profileData['date_of_birth'] != null) {
      try {
        final dateStr = widget.profileData['date_of_birth'];
        _selectedDate = DateTime.parse(dateStr);
      } catch (e) {
        print('Error parsing date: ${e.toString()}');
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _showDatePickerPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: 260,
            height: 280,
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Date',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.close, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Calendar
                Expanded(
                  child: TableCalendar(
                    firstDay: DateTime.utc(2000, 1, 1),
                    lastDay: DateTime.utc(2100, 12, 31),
                    focusedDay: _selectedDate ?? DateTime.now(),
                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Month',
                    },
                    selectedDayPredicate: (day) {
                      return isSameDay(_selectedDate, day);
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDate = selectedDay;
                      });
                      Navigator.of(context).pop();
                    },
                    onPageChanged: (focusedDay) {
                      // Handle page change if needed
                    },
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      leftChevronIcon: Icon(
                        Icons.chevron_left,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 16,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 16,
                      ),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(
                        fontSize: 8,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                      weekendStyle: TextStyle(
                        fontSize: 8,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      weekendTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 9,
                      ),
                      holidayTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 9,
                      ),
                      selectedTextStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.blue[600],
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 9,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Colors.blue[100],
                        shape: BoxShape.circle,
                      ),
                      defaultTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 9,
                      ),
                      cellMargin: const EdgeInsets.all(0),
                      cellPadding: const EdgeInsets.all(2),
                    ),
                    rowHeight: 28,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDateForDisplay(DateTime? date) {
    if (date == null) return 'Select date...';

    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateForApi(DateTime? date) {
    if (date == null) return '';

    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _showError(String message) {
    ToasterService.showError(context, message);
  }

  void _showSuccess(String message) {
    ToasterService.showSuccess(context, message);
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final File originalFile = File(image.path);

        // Check file size
        final fileSize = await originalFile.length();
        final formattedSize = ImageCompressionService.getFormattedFileSize(
          fileSize,
        );
        print('Selected image size: $formattedSize');

        // Compress the image
        _showCompressionDialog();

        final File? compressedFile =
            await ImageCompressionService.compressImage(originalFile);

        if (compressedFile != null) {
          final finalSize = await compressedFile.length();
          final finalFormattedSize =
              ImageCompressionService.getFormattedFileSize(finalSize);
          print('Compressed image size: $finalFormattedSize');

          setState(() {
            _newProfilePicture = compressedFile;
          });

          Navigator.of(context).pop(); // Close compression dialog
          _showSuccess('Image compressed successfully ($finalFormattedSize)');
        } else {
          Navigator.of(context).pop(); // Close compression dialog
          _showError('Failed to compress image. Please try a different image.');
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      _showError('Failed to pick image: ${e.toString()}');
    }
  }

  void _showCompressionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Compressing image...'),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      final token = await TokenService.getCurrentToken();
      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final result = await ApiService.updateProfile(
        token,
        fullName: _fullNameController.text.trim().isEmpty
            ? null
            : _fullNameController.text.trim(),
        dateOfBirth: _selectedDate != null
            ? _formatDateForApi(_selectedDate)
            : null,
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        profilePicture: _newProfilePicture,
      );

      if (mounted) {
        if (result['success']) {
          _showSuccess('Profile updated successfully');
          // Go back to profile page with refresh flag
          Navigator.of(context).pop(true);
        } else {
          // Handle file too large error specifically
          if (result['is_file_too_large'] == true) {
            _showError(
              '${result['message']} Try selecting a smaller image or let the app compress it automatically.',
            );
            // Clear the profile picture to allow user to try again
            setState(() {
              _newProfilePicture = null;
            });
          } else {
            _showError(result['message'] ?? 'Failed to update profile');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Error updating profile: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _isUpdating ? null : _updateProfile,
            child: _isUpdating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blue[300]!,
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: _newProfilePicture != null
                              ? Image.file(
                                  _newProfilePicture!,
                                  fit: BoxFit.cover,
                                )
                              : widget.profileData['profile_picture'] != null &&
                                    widget.profileData['profile_picture']
                                        .toString()
                                        .isNotEmpty
                              ? Image.network(
                                  widget.profileData['profile_picture'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[200],
                                      child: Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey[400],
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 60,
                                    color: Colors.grey[400],
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to change profile picture',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Full Name
              const Text(
                'Full Name',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: TextFormField(
                  controller: _fullNameController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter your full name',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Date of Birth
              const Text(
                'Date of Birth',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: InkWell(
                  onTap: _showDatePickerPopup,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
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
                              ? _formatDateForDisplay(_selectedDate)
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
                          Icons.keyboard_arrow_down,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bio
              const Text(
                'Bio',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: TextFormField(
                  controller: _bioController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Tell us about yourself',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 4,
                  validator: (value) {
                    if (value != null && value.trim().length > 500) {
                      return 'Bio must be less than 500 characters';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
