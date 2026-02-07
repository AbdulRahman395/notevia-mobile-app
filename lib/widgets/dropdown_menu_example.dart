import 'package:flutter/material.dart';
import 'dropdown_menu.dart';

class DropdownMenuExample extends StatelessWidget {
  const DropdownMenuExample({super.key});

  void _handleEdit() {
    debugPrint('Edit action triggered');
    // Handle edit logic here
  }

  void _handleDelete() {
    debugPrint('Delete action triggered');
    // Handle delete logic here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dropdown Menu Example')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Example 1: In a list item
            Card(
              child: ListTile(
                title: const Text('Sample Item 1'),
                subtitle: const Text('Tap the menu icon to see options'),
                trailing: MoreOptionsDropdown(
                  onEdit: _handleEdit,
                  onDelete: _handleDelete,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Example 2: In a custom container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sample Item 2',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Custom layout example',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                  MoreOptionsDropdown(
                    onEdit: _handleEdit,
                    onDelete: _handleDelete,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Example 3: Standalone
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Standalone menu: '),
                MoreOptionsDropdown(
                  onEdit: _handleEdit,
                  onDelete: _handleDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
