import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import 'journal_card.dart';
import 'delete_confirmation_dialog.dart';

class JournalList extends StatefulWidget {
  final Function(Map<String, dynamic>) onEdit;
  final Function(String) onView;

  const JournalList({super.key, required this.onEdit, required this.onView});

  @override
  State<JournalList> createState() => _JournalListState();
}

class _JournalListState extends State<JournalList> {
  List<Map<String, dynamic>> _journals = [];
  bool _isLoading = true;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _fetchJournals();
  }

  Future<void> _fetchJournals({int retryCount = 0}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final token = await TokenService.getAccessToken();
      if (token == null) {
        setState(() {
          _error = 'No authentication token found';
          _isLoading = false;
        });
        return;
      }

      final response = await ApiService.getJournals(
        token,
        page: _page,
        limit: _limit,
      );

      debugPrint('API Response: $response');
      debugPrint(
        'Number of journals returned: ${response['data']?.length ?? 0}',
      );
      debugPrint('Pagination info: ${response['pagination']}');

      final List<Map<String, dynamic>> formattedJournals = [];
      if (response['data'] != null) {
        for (var journal in response['data']) {
          formattedJournals.add({
            'id': journal['id']?.toString() ?? '',
            'title': journal['title'] ?? '',
            'content': journal['content'] ?? '',
            'journal_date':
                DateTime.tryParse(journal['journal_date'] ?? '') ??
                DateTime.now(),
            'media': _formatMedia(journal['media']),
          });
        }
      }

      setState(() {
        _journals = formattedJournals;
        _totalPages = response['pagination']?['totalPages'] ?? 1;
        _isLoading = false;
      });
    } catch (err) {
      debugPrint('Error fetching journals: $err');
      setState(() {
        _error = 'Failed to load journals. Refreshing...';
        _isLoading = false;
      });

      // If this is the first error, try to refresh after a short delay
      if (retryCount == 0) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _fetchJournals(retryCount: 1);
          }
        });
      }
    }
  }

  List<Map<String, String>> _formatMedia(List? mediaList) {
    if (mediaList == null) return [];

    return mediaList
        .map((media) {
          return {
            'id': media['id']?.toString() ?? '',
            'url': media['url'] ?? '',
          };
        })
        .cast<Map<String, String>>()
        .toList();
  }

  Future<void> _handleDelete(String id) async {
    // TODO: Implement deleteJournal method in ApiService
    debugPrint('Delete journal functionality not yet implemented for ID: $id');
    setState(() {
      _error = 'Delete functionality not yet implemented.';
    });
  }

  void _showDeleteDialog(String journalId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DeleteConfirmationDialog(
          title: 'Delete Journal',
          message:
              'Are you sure you want to delete this journal? This action cannot be undone.',
          onConfirm: () => _handleDelete(journalId),
          onCancel: () {},
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48.0),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        border: Border(
          left: BorderSide(color: const Color(0xFFEF4444), width: 4),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ?? 'An error occurred',
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text(
              'No journal entries found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start by creating your first journal entry!',
              style: TextStyle(fontSize: 16, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton(
            onPressed: _page > 1
                ? () {
                    setState(() {
                      _page--;
                    });
                    _fetchJournals();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey[300]!),
              shape: const CircleBorder(),
            ),
          ),

          // Page numbers
          ...List.generate(_totalPages.clamp(1, 10), (index) {
            final pageNumber = index + 1;
            final isSelected = pageNumber == _page;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _page = pageNumber;
                  });
                  _fetchJournals();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      pageNumber.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),

          // Next button
          IconButton(
            onPressed: _page < _totalPages
                ? () {
                    setState(() {
                      _page++;
                    });
                    _fetchJournals();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey[300]!),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _page == 1) {
      return _buildLoadingState();
    }

    if (_error != null && _journals.isEmpty) {
      return _buildErrorState();
    }

    if (_journals.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Journal grid
        LayoutBuilder(
          builder: (context, constraints) {
            // Responsive grid columns
            int crossAxisCount;
            if (constraints.maxWidth >= 1280) {
              crossAxisCount = 5; // xl
            } else if (constraints.maxWidth >= 1024) {
              crossAxisCount = 4; // lg
            } else if (constraints.maxWidth >= 768) {
              crossAxisCount = 3; // md
            } else if (constraints.maxWidth >= 640) {
              crossAxisCount = 2; // sm
            } else {
              crossAxisCount = 1; // xs
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: _journals.length,
              itemBuilder: (context, index) {
                final journal = _journals[index];
                return JournalCard(
                  id: journal['id'] ?? '',
                  title: journal['title'] ?? '',
                  content: journal['content'] ?? '',
                  journalDate: journal['journal_date'] ?? DateTime.now(),
                  media: List<Map<String, String>>.from(journal['media'] ?? []),
                  onTap: () => widget.onView(journal['id'] ?? ''),
                  onEdit: () => widget.onEdit(journal),
                  onDelete: () => _showDeleteDialog(journal['id'] ?? ''),
                );
              },
            );
          },
        ),

        // Pagination
        _buildPagination(),
      ],
    );
  }
}
