import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/delete_confirmation_dialog.dart';
import 'settings_page.dart';
import 'account_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  List<dynamic> _journals = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // Pagination variables
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalJournals = 0;
  final int _itemsPerPage = 10;

  // Dashboard data
  int _writingStreak = 0;

  // Animation controllers
  late AnimationController _streakAnimationController;
  late Animation<double> _streakAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize streak animation for spinner rotation with pause
    _streakAnimationController = AnimationController(
      duration: const Duration(
        milliseconds: 9600,
      ), // 9.6 seconds for full cycle
      vsync: this,
    );

    _streakAnimation =
        Tween<double>(
          begin: 0.0,
          end: 1.0, // Full rotation
        ).animate(
          CurvedAnimation(
            parent: _streakAnimationController,
            curve: const Interval(
              0.0,
              0.36, // Animate for 36% of the duration (3.5 seconds), pause for 64% (6.1 seconds)
              curve: Curves.linear, // Linear for smooth spinning
            ),
          ),
        );

    // Shake animation during pause phase (like Candy Crush)
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _streakAnimationController,
        curve: const Interval(
          0.36,
          0.58, // Shake during pause (1.1 seconds total)
          curve: Curves.easeInOut,
        ),
      ),
    );

    // Scale animation during pause phase with smooth transition back
    _scaleAnimation =
        TweenSequence<double>([
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 1.0, end: 1.3),
            weight: 0.5, // Scale up during first half (0.36-0.47, 1.05 seconds)
          ),
          TweenSequenceItem<double>(
            tween: Tween<double>(begin: 1.3, end: 1.0),
            weight:
                0.5, // Scale down during second half (0.47-0.58, 1.05 seconds)
          ),
        ]).animate(
          CurvedAnimation(
            parent: _streakAnimationController,
            curve: const Interval(
              0.36,
              0.58, // Scale animation during pause phase (2.1 seconds total)
              curve: Curves.easeOutCubic,
            ),
          ),
        );

    // Start data fetching after animation is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
      _fetchDashboardData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchFocusNode.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _streakAnimationController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 1; // Reset to first page when searching
    });

    // Cancel previous timer
    _searchDebounce?.cancel();

    // Set new timer to trigger search after 500ms delay
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fetchData(search: query.isEmpty ? null : query);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  Future<void> _fetchDashboardData() async {
    try {
      final token = await TokenService.getCurrentToken();
      if (token.isEmpty) {
        print('No token found for dashboard fetch');
        return;
      }

      final dashboardResult = await ApiService.getDashboard(token);
      print('Dashboard result: $dashboardResult');

      if (mounted && dashboardResult['success']) {
        final data = dashboardResult['data'];
        print('Dashboard data: $data');
        setState(() {
          _writingStreak = data['writingStreak'] ?? 0;
          print('Writing streak set to: $_writingStreak');

          // Start streak animation if there's a streak
          if (_writingStreak > 0) {
            if (!_streakAnimationController.isAnimating) {
              _streakAnimationController.repeat();
            }
          } else {
            if (_streakAnimationController.isAnimating) {
              _streakAnimationController.stop();
              _streakAnimationController.reset();
            }
          }
        });
      } else {
        print('Dashboard fetch failed: ${dashboardResult['message']}');
      }
    } catch (e) {
      print('Error fetching dashboard data: ${e.toString()}');
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

  Future<void> _fetchData({int page = 1, String? search}) async {
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
        search: search,
      );

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

  String _getMoodEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return '😍';
      case 'sad':
        return '😢';
      case 'neutral':
        return '😐';
      case 'calm':
        return '☺️';
      default:
        return '';
    }
  }

  Color _getMoodBackgroundColor(String mood) {
    print('Mood background called with: $mood'); // Debug line
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

  String _stripHtmlTags(String htmlText) {
    final RegExp exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlText.replaceAll(exp, '').trim();
  }

  void _editJournal(Map<String, dynamic> journal) async {
    _searchFocusNode.unfocus();
    final journalId = journal['id'] as int?;
    print('Edit journal clicked - journal data: $journal');
    if (journalId != null) {
      // Navigate to journal-entry page with journal data for editing
      print('Navigating to journal-entry with arguments: $journal');
      final result = await Navigator.of(context).pushNamed(
        '/journal-entry',
        arguments: journal, // Pass the entire journal data for editing
      );
      // Refresh data if journal was successfully updated (result is true)
      if (result == true && mounted) {
        _fetchData(page: _currentPage);
      }
    } else {
      print('No journal ID found, cannot edit');
    }
  }

  void _deleteJournal(Map<String, dynamic> journal) async {
    final journalId = journal['id'] as int?;
    final journalTitle = journal['title'] as String? ?? 'Untitled';

    if (journalId == null) return;

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DeleteConfirmationDialog(
          title: 'Delete Journal',
          message:
              'Are you sure you want to delete this journal? This action cannot be undone.',
          onConfirm: () async {
            try {
              final token = await TokenService.getCurrentToken();
              if (token.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Authentication error. Please login again.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              final result = await ApiService.deleteJournal(token, journalId);

              if (mounted) {
                if (result['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Journal deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Refresh the data
                  _fetchData(page: _currentPage);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result['message'] ?? 'Failed to delete journal',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting journal: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          onCancel: () {
            // Do nothing, just close the dialog
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // App Header
            Container(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Streak indicator like Duolingo
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _writingStreak > 0
                          ? Colors.orange[50]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _writingStreak > 0
                            ? Colors.orange[300]!
                            : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_writingStreak > 0)
                          AnimatedBuilder(
                            animation: Listenable.merge([
                              _streakAnimation,
                              _shakeAnimation,
                              _scaleAnimation,
                            ]),
                            builder: (context, child) {
                              // Safety check for animation values
                              final shakeValue = _shakeAnimation.value.isNaN
                                  ? 0.0
                                  : _shakeAnimation.value;
                              final scaleValue = _scaleAnimation.value.isNaN
                                  ? 1.0
                                  : _scaleAnimation.value;

                              // Calculate shake offset (during pause phase)
                              final shakeOffset =
                                  shakeValue *
                                  2.0 *
                                  math.sin(shakeValue * math.pi * 8);

                              // Calculate scale (during pause phase)
                              final scale = scaleValue;

                              return Transform.translate(
                                offset: Offset(shakeOffset, 0),
                                child: Transform.scale(
                                  scale: scale,
                                  child: Icon(
                                    Icons.local_fire_department,
                                    color: Colors.orange[500],
                                    size: 18,
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          Icon(
                            Icons.local_fire_department,
                            color: Colors.grey[400],
                            size: 18,
                          ),
                        const SizedBox(width: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            '$_writingStreak',
                            key: ValueKey(_writingStreak),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _writingStreak > 0
                                  ? Colors.orange[700]
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.lock, size: 20),
                    onPressed: () async {
                      await TokenService.clearAccessToken();
                      if (mounted) {
                        final authToken = await TokenService.getAuthToken();
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/pin-verification',
                          (Route<dynamic> route) => false,
                          arguments: authToken,
                        );
                      }
                    },
                    tooltip: 'Lock',
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    position: PopupMenuPosition.under,
                    elevation: 3.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(minWidth: 160),
                    onSelected: (String value) {
                      print('Menu selected: $value');
                      if (value == 'account') {
                        print('Navigating to account page');
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AccountPage(),
                          ),
                        );
                      } else if (value == 'settings') {
                        print('Navigating to settings page');
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );
                      } else if (value == 'logout') {
                        print('Logging out');
                        TokenService.clearTokens().then((_) {
                          if (mounted) {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed('/signin');
                          }
                        });
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'account',
                        child: Text('Profile'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'settings',
                        child: Text('Settings'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Text('Logout'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search journals...',
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                            ),
                            onPressed: _clearSearch,
                          )
                        : null,
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
                    _onSearchChanged(value);
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
                          itemCount:
                              _journals.length + (_totalPages > 1 ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show pagination as the last item
                            if (index == _journals.length && _totalPages > 1) {
                              return _buildPagination();
                            }
                            final journal = _journals[index];
                            return GestureDetector(
                              onTap: () async {
                                _searchFocusNode.unfocus();
                                final journalId = journal['id'] as int?;
                                if (journalId != null) {
                                  final result = await Navigator.of(context)
                                      .pushNamed(
                                        '/journal-detail',
                                        arguments: journalId,
                                      );
                                  // Refresh data if journal was successfully deleted (result is true)
                                  if (result == true && mounted) {
                                    _fetchData(page: _currentPage);
                                  }
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12.0),
                                padding: const EdgeInsets.all(16.0),
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
                                              fontSize: 14,
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
                                              fontSize: 10,
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

                                    const SizedBox(height: 8),

                                    // Content
                                    Text(
                                      _stripHtmlTags(journal['content'] ?? ''),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                        height: 1.4,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    // Mood display
                                    if (journal['mood'] != null &&
                                        journal['mood']
                                            .toString()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                    ],

                                    const SizedBox(height: 8),

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

                                    // Footer with arrow and mood
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Left side - mood display
                                        if (journal['mood'] != null &&
                                            journal['mood']
                                                .toString()
                                                .isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getMoodBackgroundColor(
                                                journal['mood'].toString(),
                                              ).withOpacity(0.3),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '${journal['mood']} ${_getMoodEmoji(journal['mood'].toString())}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700]!,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),

                                        // Right side - edit and delete icons
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Edit icon
                                            GestureDetector(
                                              onTap: () =>
                                                  _editJournal(journal),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Icon(
                                                  Icons.edit,
                                                  size: 14,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.6),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            // Delete icon
                                            GestureDetector(
                                              onTap: () =>
                                                  _deleteJournal(journal),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Icon(
                                                  Icons.delete,
                                                  size: 14,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.6),
                                                ),
                                              ),
                                            ),
                                          ],
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
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20.0, right: 10),
        child: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.of(
              context,
            ).pushNamed('/journal-entry');
            // Refresh data if journal was successfully created (result is true)
            if (result == true && mounted) {
              _fetchData(page: _currentPage);
            }
          },
          backgroundColor: Colors.blue[400],
          child: const Icon(Icons.add, color: Colors.white, size: 28),
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
