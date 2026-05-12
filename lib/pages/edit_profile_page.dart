import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/toaster_service.dart';

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
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _showCalendar = false;
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
        _focusedDay = _selectedDate!;
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
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _newProfilePicture = File(image.path);
      });
    }
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
          _showError(result['message'] ?? 'Failed to update profile');
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
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: Column(
                  children: [
                    // Clickable date display
                    InkWell(
                      onTap: _toggleCalendar,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
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
                              _showCalendar
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Calendar
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
                          outsideDaysVisible: false,
                          weekendTextStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          holidayTextStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          selectedTextStyle: const TextStyle(
                            color: Colors.white,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Colors.blue[600],
                            shape: BoxShape.circle,
                          ),
                          todayTextStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Colors.blue[100],
                            shape: BoxShape.circle,
                          ),
                          defaultTextStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                  ],
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
