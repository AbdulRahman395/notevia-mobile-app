import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../widgets/full_screen_image_viewer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<dynamic> _journals = [];
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh data when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final token = await TokenService.getCurrentToken();
      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final journalsResult = await ApiService.getJournals(token);
      final profileResult = await ApiService.getProfile(token);

      if (mounted) {
        setState(() {
          if (journalsResult['success']) {
            _journals = journalsResult['data']['data'] ?? [];
          } else if (journalsResult['requires_auth_redirect'] == true) {
            // Handle 401 - redirect to PIN verification with auth token
            () async {
              final authToken = await TokenService.getAuthToken();
              if (authToken != null && mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/pin-verification',
                  (Route<dynamic> route) => false,
                  arguments: authToken,
                );
              }
            }();
            return;
          }

          if (profileResult['success']) {
            _profile = profileResult['data'];
          } else if (profileResult['requires_auth_redirect'] == true) {
            // Handle 401 - redirect to PIN verification with auth token
            () async {
              final authToken = await TokenService.getAuthToken();
              if (authToken != null && mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/pin-verification',
                  (Route<dynamic> route) => false,
                  arguments: authToken,
                );
              }
            }();
            return;
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load data: ${e.toString()}';
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

  String _stripHtmlTags(String htmlText) {
    final RegExp exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlText.replaceAll(exp, '').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue[400],
                    backgroundImage: _profile?['profile_picture'] != null
                        ? NetworkImage(_profile!['profile_picture'])
                        : null,
                    child: _profile?['profile_picture'] == null
                        ? const Icon(
                            Icons.person,
                            size: 30,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${_profile?['first_name'] ?? 'John'} ${_profile?['last_name'] ?? 'Doe'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await TokenService.clearTokens();
                      if (mounted) {
                        Navigator.of(context).pushReplacementNamed('/signin');
                      }
                    },
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
            ),

            // Journals List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _hasError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading journals',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _fetchData,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    )
                  : _journals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No journals yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start writing your first journal entry',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        itemCount: _journals.length,
                        itemBuilder: (context, index) {
                          final journal = _journals[index];
                          return GestureDetector(
                            onTap: () {
                              final journalId = journal['id'] as int?;
                              if (journalId != null) {
                                Navigator.of(context).pushNamed(
                                  '/journal-detail',
                                  arguments: journalId,
                                );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 15.0),
                              padding: const EdgeInsets.all(20.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title and Date
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          journal['title'] ?? 'Untitled',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          _formatDate(journal['journal_date']),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // Content
                                  Text(
                                    _stripHtmlTags(journal['content'] ?? ''),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                      height: 1.4,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                  const SizedBox(height: 12),

                                  // Media Images (small thumbnails)
                                  if (journal['media'] != null &&
                                      journal['media'] is List &&
                                      (journal['media'] as List).isNotEmpty)
                                    SizedBox(
                                      height: 60,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount:
                                            (journal['media'] as List).length,
                                        itemBuilder: (context, mediaIndex) {
                                          final media =
                                              (journal['media']
                                                  as List)[mediaIndex];
                                          final imageUrl = media['url'] ?? '';

                                          return GestureDetector(
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      FullScreenImageViewer(
                                                        imageUrl: imageUrl,
                                                        heroTag:
                                                            'home_image_${journal['id']}_$mediaIndex',
                                                      ),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              width: 60,
                                              height: 60,
                                              margin: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: Hero(
                                                tag:
                                                    'home_image_${journal['id']}_$mediaIndex',
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) {
                                                          return Container(
                                                            color: Colors
                                                                .grey[200],
                                                            child: Icon(
                                                              Icons
                                                                  .broken_image,
                                                              size: 20,
                                                              color: Colors
                                                                  .grey[400],
                                                            ),
                                                          );
                                                        },
                                                    loadingBuilder:
                                                        (
                                                          context,
                                                          child,
                                                          loadingProgress,
                                                        ) {
                                                          if (loadingProgress ==
                                                              null)
                                                            return child;
                                                          return Container(
                                                            color: Colors
                                                                .grey[100],
                                                            child: Center(
                                                              child: CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                value:
                                                                    loadingProgress
                                                                            .expectedTotalBytes !=
                                                                        null
                                                                    ? loadingProgress
                                                                              .cumulativeBytesLoaded /
                                                                          loadingProgress
                                                                              .expectedTotalBytes!
                                                                    : null,
                                                                valueColor:
                                                                    AlwaysStoppedAnimation<
                                                                      Color
                                                                    >(
                                                                      Colors
                                                                          .blue[400]!,
                                                                    ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),

                                  const SizedBox(height: 12),

                                  // Footer
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.grey[400],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(
            context,
          ).pushNamed('/journal-entry');
          // Refresh data if a new journal was created
          if (result == true) {
            _fetchData();
          }
        },
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
