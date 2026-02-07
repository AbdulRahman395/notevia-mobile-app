import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dropdown_menu.dart';

class JournalCard extends StatelessWidget {
  final String id;
  final String title;
  final String content;
  final DateTime journalDate;
  final List<Map<String, String>> media;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const JournalCard({
    super.key,
    required this.id,
    required this.title,
    required this.content,
    required this.journalDate,
    required this.media,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with title and menu
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title.isNotEmpty ? title : 'Untitled',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      MoreOptionsDropdown(onEdit: onEdit, onDelete: onDelete),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Date
                  Text(
                    DateFormat('MMM d, yyyy').format(journalDate),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Content preview
                  Text(
                    _stripHtmlTags(content),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (media.isNotEmpty) ...[
                    const SizedBox(height: 12),

                    // Media preview
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          ...media
                              .take(3)
                              .map(
                                (image) => Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Image.network(
                                        image['url'] ?? '',
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[200],
                                                child: const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
                                                  size: 20,
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),

                          if (media.length > 3)
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '+${media.length - 3}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF4B5563),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _stripHtmlTags(String htmlString) {
    final RegExp exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').trim();
  }
}
