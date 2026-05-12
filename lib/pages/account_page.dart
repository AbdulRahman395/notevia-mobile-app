import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import 'edit_profile_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    try {
      final token = await TokenService.getCurrentToken();
      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final result = await ApiService.getProfile(token);

      if (mounted) {
        setState(() {
          if (result['success']) {
            _profileData = result['data'];
            _hasError = false;
          } else {
            _hasError = true;
            _errorMessage = result['message'] ?? 'Failed to load profile';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error loading profile: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';

    try {
      final dateTime = DateTime.parse(dateString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    } catch (e) {
      return dateString;
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
          'Profile',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              if (_profileData != null) {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) =>
                        EditProfilePage(profileData: _profileData!),
                  ),
                );
                // Refresh profile data if user saved changes
                if (result == true) {
                  _fetchProfileData();
                }
              }
            },
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading profile',
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _fetchProfileData,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            )
          : _profileData != null
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header with Picture
                  Center(
                    child: Column(
                      children: [
                        // Profile Picture
                        Container(
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
                            child:
                                _profileData!['profile_picture'] != null &&
                                    _profileData!['profile_picture']
                                        .toString()
                                        .isNotEmpty
                                ? Image.network(
                                    _profileData!['profile_picture'],
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
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.grey[100],
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: Colors.grey[200],
                                    child: Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Full Name
                        Text(
                          _profileData!['full_name'] ?? 'No Name',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        // Bio
                        if (_profileData!['bio'] != null &&
                            _profileData!['bio'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ),
                            child: Text(
                              _profileData!['bio'],
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Profile Details
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User ID
                        _buildDetailRow(
                          'User ID',
                          _profileData!['user_id']?.toString() ?? 'N/A',
                          Icons.person_outline,
                        ),
                        const Divider(height: 24),
                        // Date of Birth
                        if (_profileData!['date_of_birth'] != null)
                          _buildDetailRow(
                            'Date of Birth',
                            _formatDate(_profileData!['date_of_birth']),
                            Icons.cake_outlined,
                          ),
                        if (_profileData!['date_of_birth'] != null)
                          const Divider(height: 24),
                        // Member Since
                        _buildDetailRow(
                          'Member Since',
                          _formatDate(_profileData!['created_at']),
                          Icons.calendar_today_outlined,
                        ),
                        if (_profileData!['updated_at'] != null)
                          const Divider(height: 24),
                        // Last Updated
                        if (_profileData!['updated_at'] != null)
                          _buildDetailRow(
                            'Last Updated',
                            _formatDate(_profileData!['updated_at']),
                            Icons.update_outlined,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const Center(child: Text('No profile data available')),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
