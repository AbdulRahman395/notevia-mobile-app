import 'package:flutter/material.dart';
import 'dart:async';
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
  final int _itemsPerPage = 25;

  // Dashboard data
  int _writingStreak = 0;

  // Animation controller for the streak flame's gentle flicker
  late AnimationController _streakAnimationController;
  late Animation<double> _flameScale;
  late Animation<double> _flameGlow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Gentle continuous flicker for the streak flame — a soft breathing
    // scale + glow, always running at low amplitude so it feels alive
    // without being distracting (fire doesn't spin, so no rotation here).
    _streakAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _flameScale = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(
        parent: _streakAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _flameGlow = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _streakAnimationController,
        curve: Curves.easeInOut,
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
        return;
      }

      final dashboardResult = await ApiService.getDashboard(token);

      if (mounted && dashboardResult['success']) {
        final data = dashboardResult['data'];
        setState(() {
          _writingStreak = data['writingStreak'] ?? 0;

          // Start streak animation if there's a streak
          if (_writingStreak > 0) {
            if (!_streakAnimationController.isAnimating) {
              _streakAnimationController.repeat(reverse: true);
            }
          } else {
            if (_streakAnimationController.isAnimating) {
              _streakAnimationController.stop();
              _streakAnimationController.reset();
            }
          }
        });
      }
    } catch (e) {
      // Non-fatal: dashboard is a secondary widget, home page still works without it.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh data when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _fetchData();
      _fetchDashboardData();
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

            _journals = data ?? [];
            _currentPage = pagination?['page'] ?? 1;
            _totalPages = pagination?['totalPages'] ?? 1;
            _totalJournals = pagination?['total'] ?? 0;
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

  // Mood emoji + color mapping kept in sync with the Journal Entry page
  // ('Happy'/'Sad'/'Calm'/'Neutral') so the two screens feel like one app.
  String _getMoodEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'sad':
        return '😢';
      case 'calm':
        return '😌';
      case 'neutral':
        return '😐';
      default:
        return '';
    }
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

  String _stripHtmlTags(String htmlText) {
    final RegExp exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlText.replaceAll(exp, '').trim();
  }

  void _editJournal(Map<String, dynamic> journal) async {
    _searchFocusNode.unfocus();
    final journalId = journal['id'] as int?;
    if (journalId != null) {
      // Navigate to journal-entry page with journal data for editing
      final result = await Navigator.of(context).pushNamed(
        '/journal-entry',
        arguments: journal, // Pass the entire journal data for editing
      );
      // Refresh data if journal was successfully updated (result is true)
      if (result == true && mounted) {
        _fetchData(page: _currentPage);
        _fetchDashboardData();
      }
    }
  }

  void _deleteJournal(Map<String, dynamic> journal) async {
    final journalId = journal['id'] as int?;

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

  // ---- UI building blocks -------------------------------------------------

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
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
                const Text(
                  '📖 Your Thoughts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                // Streak pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _streakAnimationController,
                        builder: (context, child) {
                          final scale = _writingStreak > 0
                              ? _flameScale.value
                              : 1.0;
                          final glow = _writingStreak > 0
                              ? _flameGlow.value
                              : 0.4;

                          return Transform.scale(
                            scale: scale,
                            child: Icon(
                              Icons.local_fire_department,
                              color: _writingStreak > 0
                                  ? Color.lerp(
                                      Colors.orange[200],
                                      Colors.orangeAccent[100],
                                      glow,
                                    )
                                  : Colors.white54,
                              size: 16,
                            ),
                          );
                        },
                      ),

                      const SizedBox(width: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          '$_writingStreak day streak',
                          key: ValueKey(_writingStreak),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline, color: Colors.white, size: 20),
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
            icon: const Icon(Icons.more_vert, color: Colors.white),
            position: PopupMenuPosition.under,
            elevation: 3.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(minWidth: 160),
            onSelected: (String value) {
              if (value == 'account') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AccountPage()),
                );
              } else if (value == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              } else if (value == 'logout') {
                TokenService.clearTokens().then((_) {
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed('/signin');
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
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Search journals...',
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 14,
            ),
            prefixIcon: Icon(Icons.search, color: Colors.blue[300], size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 18,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
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
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: Colors.blue[300]),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action],
        ],
      ),
    );
  }

  Widget _buildJournalCard(Map<String, dynamic> journal) {
    final mood = (journal['mood'] ?? '').toString();
    final hasMood = mood.isNotEmpty;
    final media = journal['media'];
    final hasMedia = media != null && media is List && media.isNotEmpty;

    return GestureDetector(
      onTap: () async {
        _searchFocusNode.unfocus();
        final journalId = journal['id'] as int?;
        if (journalId != null) {
          final result = await Navigator.of(
            context,
          ).pushNamed('/journal-detail', arguments: journalId);
          // Refresh data if journal was successfully deleted (result is true)
          if (result == true && mounted) {
            _fetchData(page: _currentPage);
            _fetchDashboardData();
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.all(18.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Date
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    journal['title'] ?? 'Untitled',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDate(journal['journal_date']),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
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
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.45,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            // Media Images (small thumbnails)
            if (hasMedia) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 64,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: (media as List).length,
                  itemBuilder: (context, mediaIndex) {
                    final item = media[mediaIndex];
                    final imageUrl = item['url'] ?? '';

                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => FullScreenImageViewer(
                              imageUrl: imageUrl,
                              heroTag:
                                  'home_image_${journal['id']}_$mediaIndex',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        margin: const EdgeInsets.only(right: 8),
                        child: Hero(
                          tag: 'home_image_${journal['id']}_$mediaIndex',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.broken_image,
                                    size: 20,
                                    color: Colors.grey[400],
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey[100],
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
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.blue[400]!,
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
            ],

            const SizedBox(height: 14),

            // Footer with mood and edit/delete
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (hasMood)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _getMoodColor(mood).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getMoodColor(mood).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${_getMoodEmoji(mood)} $mood',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getMoodColor(mood),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _editJournal(journal),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 15,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _deleteJournal(journal),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          size: 15,
                          color: Colors.red[300],
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            const SizedBox(height: 8),

            // Journals List
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _searchFocusNode.unfocus();
                },
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Colors.blue[400],
                        ),
                      )
                    : _hasError
                    ? _buildEmptyState(
                        icon: Icons.error_outline,
                        title: 'Error loading journals',
                        subtitle: _errorMessage,
                        action: ElevatedButton(
                          onPressed: () => _fetchData(page: _currentPage),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[500],
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Try Again'),
                        ),
                      )
                    : _journals.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'No journals yet',
                        subtitle: 'Start writing your first journal entry',
                      )
                    : RefreshIndicator(
                        color: Colors.blue[400],
                        onRefresh: () => _fetchData(page: _currentPage),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          itemCount:
                              _journals.length + (_totalPages > 1 ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show pagination as the last item
                            if (index == _journals.length && _totalPages > 1) {
                              return _buildPagination();
                            }
                            final journal = _journals[index];
                            return _buildJournalCard(journal);
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
              _fetchDashboardData();
            }
          },
          backgroundColor: Colors.blue[500],
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage > 1 ? Colors.grey[50] : Colors.grey[100],
                ),
                child: IconButton(
                  onPressed: _currentPage > 1
                      ? () => _fetchData(page: _currentPage - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage < _totalPages
                      ? Colors.grey[50]
                      : Colors.grey[100],
                ),
                child: IconButton(
                  onPressed: _currentPage < _totalPages
                      ? () => _fetchData(page: _currentPage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
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
          const SizedBox(height: 10),
          Text(
            'Showing ${_journals.length} of $_totalJournals journals',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
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
      child: InkWell(
        onTap: () => _fetchData(page: pageNum),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? Colors.blue[500] : Colors.transparent,
          ),
          child: Center(
            child: Text(
              pageNum.toString(),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
