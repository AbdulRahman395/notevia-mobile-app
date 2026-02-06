import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/theme_service.dart';
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
  final ThemeService _themeService = ThemeService();
  final FocusNode _searchFocusNode = FocusNode();

  // Pagination variables
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalJournals = 0;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeService.loadTheme();
    _themeService.addListener(_onThemeChanged);
    _fetchData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeService.removeListener(_onThemeChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh data when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _fetchData();
    }
  }

  Future<void> _fetchData({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final token = await TokenService.getCurrentToken();
      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final journalsResult = await ApiService.getJournals(
        token,
        page: page,
        limit: _itemsPerPage,
      );
      final profileResult = await ApiService.getProfile(token);

      if (mounted) {
        setState(() {
          if (journalsResult['success']) {
            final data = journalsResult['data'];
            final pagination = journalsResult['pagination'];
            print('API Response: $journalsResult');
            print('Number of journals returned: ${data?.length ?? 0}');
            print('Pagination info: $pagination');

            _journals = data ?? [];
            _currentPage = pagination?['page'] ?? 1;
            _totalPages = pagination?['totalPages'] ?? 1;
            _totalJournals = pagination?['total'] ?? 0;

            // Debug logging
            print(
              'Pagination debug - Current page: $_currentPage, Total pages: $_totalPages, Total journals: $_totalJournals',
            );
            print('Journals count: ${_journals.length}');
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
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
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      await _themeService.toggleTheme();
                    },
                    icon: Icon(
                      _themeService.isDarkMode
                          ? Icons.light_mode
                          : Icons.dark_mode,
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

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: TextField(
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search journals...',
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  onChanged: (value) {
                    // TODO: Implement search functionality
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Journals List
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _searchFocusNode.unfocus();
                },
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
                              onPressed: () => _fetchData(page: _currentPage),
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start writing your first journal entry',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchData(page: _currentPage),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          itemCount: _journals.length,
                          itemBuilder: (context, index) {
                            final journal = _journals[index];
                            return GestureDetector(
                              onTap: () {
                                _searchFocusNode.unfocus();
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
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
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
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            _formatDate(
                                              journal['journal_date'],
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.6),
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
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
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
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
                                                                null) {
                                                              return child;
                                                            }
                                                            return Container(
                                                              color: Colors
                                                                  .grey[100],
                                                              child: Center(
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                  value:
                                                                      loadingProgress
                                                                              .expectedTotalBytes !=
                                                                          null
                                                                      ? loadingProgress.cumulativeBytesLoaded /
                                                                            loadingProgress.expectedTotalBytes!
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
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.4),
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
            ),

            // Pagination
            if (_totalPages > 1) _buildPagination(),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous button
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!),
                  color: _currentPage > 1
                      ? Colors.transparent
                      : Colors.grey[100],
                ),
                child: IconButton(
                  onPressed: _currentPage > 1
                      ? () => _fetchData(page: _currentPage - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  style: IconButton.styleFrom(
                    foregroundColor: _currentPage > 1
                        ? Colors.grey[700]
                        : Colors.grey[400],
                  ),
                ),
              ),

              // Page numbers (show only 3 pages as requested)
              ..._getPageNumbers().map((pageNum) => _buildPageButton(pageNum)),

              // Next button
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!),
                  color: _currentPage < _totalPages
                      ? Colors.transparent
                      : Colors.grey[100],
                ),
                child: IconButton(
                  onPressed: _currentPage < _totalPages
                      ? () => _fetchData(page: _currentPage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  style: IconButton.styleFrom(
                    foregroundColor: _currentPage < _totalPages
                        ? Colors.grey[700]
                        : Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Showing ${_journals.length} of $_totalJournals journals',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  List<int> _getPageNumbers() {
    List<int> pages = [];

    if (_totalPages <= 3) {
      // Show all pages if total is 3 or less
      for (int i = 1; i <= _totalPages; i++) {
        pages.add(i);
      }
    } else {
      // Show only 3 pages with current page in the middle when possible
      if (_currentPage == 1) {
        pages = [1, 2, 3];
      } else if (_currentPage == _totalPages) {
        pages = [_totalPages - 2, _totalPages - 1, _totalPages];
      } else {
        pages = [_currentPage - 1, _currentPage, _currentPage + 1];
      }
    }

    return pages;
  }

  Widget _buildPageButton(int pageNum) {
    final bool isSelected = pageNum == _currentPage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.transparent : Colors.transparent,
        ),
        child: InkWell(
          onTap: () => _fetchData(page: pageNum),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                pageNum.toString(),
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                  decoration: isSelected
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  decorationThickness: 2,
                  decorationStyle: TextDecorationStyle.solid,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
