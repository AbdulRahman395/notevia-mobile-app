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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).appBarTheme.foregroundColor,
          ),
        ),
        title: Text(
          'Details',
          style: TextStyle(
            color: Theme.of(context).appBarTheme.foregroundColor,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _fetchJournal,
            icon: Icon(
              Icons.refresh,
              color: Theme.of(context).appBarTheme.foregroundColor,
            ),
          ),
          IconButton(
            onPressed: _showDeleteConfirmation,
            icon: Icon(Icons.delete_outline, color: Colors.red),
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
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading journal',
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
                    onPressed: _fetchJournal,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            )
          : _journal == null
          ? const Center(child: Text('Journal not found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _journal!['title'] ?? 'Untitled',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Content
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
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
                      children: [
                        Html(
                          data: _formatContentForHtml(
                            _journal!['content'] ?? '',
                          ),
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

                        // Mood display
                        if (_journal!['mood'] != null &&
                            _journal!['mood'].toString().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getMoodBackgroundColor(
                                    _journal!['mood'].toString(),
                                  ).withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_journal!['mood']} ${_getMoodEmoji(_journal!['mood'].toString())}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700]!,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Media Images
                  if (_journal!['media'] != null &&
                      _journal!['media'] is List &&
                      (_journal!['media'] as List).isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
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
                          Text(
                            'Photos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Display images in a grid
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
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.surface,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.broken_image,
                                                    size: 40,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.4),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Image not available',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withOpacity(0.5),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Container(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
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
                  const SizedBox(height: 24),

                  // Metadata
                  if (_journal!['created_at'] != null)
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Journal Information',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Created On: ${_formatDate(_journal!['created_at'])}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          if (_journal!['updated_at'] != null &&
                              _journal!['updated_at'] !=
                                  _journal!['created_at'])
                            Text(
                              'Updated: ${_formatDate(_journal!['updated_at'])}',
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
                ],
              ),
            ),
    );
  }
}
