import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../services/toaster_service.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/delete_confirmation_dialog.dart';

class JournalDetailPage extends StatefulWidget {
  final int journalId;

  const JournalDetailPage({super.key, required this.journalId});

  @override
  State<JournalDetailPage> createState() => _JournalDetailPageState();
}

class _JournalDetailPageState extends State<JournalDetailPage> {
  Map<String, dynamic>? _journal;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchJournal();
  }

  Future<void> _fetchJournal() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final token = await TokenService.getCurrentToken();
      if (token.isEmpty) {
        throw Exception('No authentication token found');
      }

      final result = await ApiService.getJournalById(token, widget.journalId);

      if (mounted) {
        if (result['success']) {
          setState(() {
            _journal = result['data'];
            _isLoading = false;
          });
        } else if (result['requires_auth_redirect'] == true) {
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
        } else {
          setState(() {
            _hasError = true;
            _errorMessage = result['message'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load journal: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  // Mood emoji + color mapping kept in sync with the rest of the app
  // ('Happy'/'Sad'/'Calm'/'Neutral').
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

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';

    try {
      final dateTime = DateTime.parse(dateString);

      // Convert to PKT (UTC+5)
      final pktDateTime = dateTime.toUtc().add(const Duration(hours: 5));

      final months = [
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

      // Format hour to 12-hour format with am/pm
      int hour = pktDateTime.hour;
      String period = hour >= 12 ? 'pm' : 'am';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;

      return '${months[pktDateTime.month - 1]} ${pktDateTime.day}, ${pktDateTime.year} - $hour:${pktDateTime.minute.toString().padLeft(2, '0')} $period (PKT)';
    } catch (e) {
      return dateString;
    }
  }

  String _formatContentForHtml(String content) {
    if (content.isEmpty) return content;

    // Convert \r\n\r\n to paragraph breaks and \r\n to line breaks
    String formatted = content
        .replaceAll('\r\n\r\n', '</p><p>')
        .replaceAll('\r\n', '<br>');

    // Wrap in paragraph tags if not already wrapped
    if (!formatted.startsWith('<p>')) {
      formatted = '<p>$formatted</p>';
    }

    return formatted;
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        title: 'Delete Journal',
        message:
            'Are you sure you want to delete this journal? This action cannot be undone.',
        onConfirm: _deleteJournal,
        onCancel: () {},
      ),
    );
  }

  Future<void> _deleteJournal() async {
    try {
      final token = await TokenService.getCurrentToken();
      if (token.isEmpty) {
        _showErrorSnackBar('No authentication token found');
        return;
      }

      final result = await ApiService.deleteJournal(token, widget.journalId);

      if (mounted) {
        if (result['success']) {
          _showSuccessSnackBar('Journal deleted successfully');
          // Navigate back to home page after successful deletion with refresh signal
          Navigator.of(context).pop(true);
        } else if (result['requires_auth_redirect'] == true) {
          // Handle 401 - redirect to PIN verification with auth token
          final authToken = await TokenService.getAuthToken();
          if (authToken != null) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/pin-verification',
              (Route<dynamic> route) => false,
              arguments: authToken,
            );
          }
        } else {
          _showErrorSnackBar(result['message'] ?? 'Failed to delete journal');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to delete journal: ${e.toString()}');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ToasterService.showSuccess(context, message);
  }

  void _showErrorSnackBar(String message) {
    ToasterService.showError(context, message);
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
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
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action],
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final mood = (_journal!['mood'] ?? '').toString();
    final hasMood = mood.isNotEmpty;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _journal!['title'] ?? 'Untitled',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDate(_journal!['journal_date'] ?? _journal!['created_at']),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (hasMood) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getMoodEmoji(mood),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    mood,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
        ),
        title: Text(
          'Details',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fetchJournal,
            icon: Icon(Icons.refresh, color: Colors.blue[400]),
            tooltip: 'Refresh',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              onPressed: _showDeleteConfirmation,
              icon: Icon(Icons.delete_outline, color: Colors.red[300]),
              tooltip: 'Delete',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blue[400]))
          : _hasError
          ? _buildEmptyState(
              icon: Icons.error_outline,
              title: 'Error loading journal',
              subtitle: _errorMessage,
              action: ElevatedButton(
                onPressed: _fetchJournal,
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
          : _journal == null
          ? _buildEmptyState(
              icon: Icons.menu_book_outlined,
              title: 'Journal not found',
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header — title, date, mood
                  _buildHeaderCard(),
                  const SizedBox(height: 20),

                  // Content
                  _sectionCard(
                    child: Html(
                      data: _formatContentForHtml(_journal!['content'] ?? ''),
                      style: {
                        "body": Style(
                          fontSize: FontSize(14),
                          lineHeight: const LineHeight(1.6),
                          color: Theme.of(context).colorScheme.onSurface,
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                        ),
                        "p": Style(margin: Margins.only(bottom: 16)),
                        "strong": Style(fontWeight: FontWeight.bold),
                        "em": Style(fontStyle: FontStyle.italic),
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Media Images
                  if (_journal!['media'] != null &&
                      _journal!['media'] is List &&
                      (_journal!['media'] as List).isNotEmpty) ...[
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel(Icons.photo_outlined, 'Photos'),
                          const SizedBox(height: 16),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.0,
                                ),
                            itemCount: (_journal!['media'] as List).length,
                            itemBuilder: (context, index) {
                              final media = (_journal!['media'] as List)[index];
                              final imageUrl = media['url'] ?? '';

                              return GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => FullScreenImageViewer(
                                        imageUrl: imageUrl,
                                        heroTag:
                                            'journal_image_${media['id']}_$index',
                                      ),
                                    ),
                                  );
                                },
                                child: Hero(
                                  tag: 'journal_image_${media['id']}_$index',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[100],
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.broken_image,
                                                    size: 32,
                                                    color: Colors.grey[400],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Image not available',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[500],
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
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
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Metadata
                  if (_journal!['created_at'] != null)
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel(
                            Icons.info_outline,
                            'Journal Information',
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: Colors.blue[400],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Created On',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(_journal!['created_at']),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_journal!['updated_at'] != null &&
                              _journal!['updated_at'] !=
                                  _journal!['created_at']) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.update_outlined,
                                    size: 16,
                                    color: Colors.blue[400],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Updated',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.5),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatDate(_journal!['updated_at']),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
