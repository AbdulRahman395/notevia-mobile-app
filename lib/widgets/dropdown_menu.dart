import 'package:flutter/material.dart';

class MoreOptionsDropdown extends StatefulWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MoreOptionsDropdown({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<MoreOptionsDropdown> createState() => _MoreOptionsDropdownState();
}

class _MoreOptionsDropdownState extends State<MoreOptionsDropdown>
    with TickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
    });
    if (_isOpen) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _handleEdit() {
    widget.onEdit();
    _close();
  }

  void _handleDelete() {
    widget.onDelete();
    _close();
  }

  void _close() {
    setState(() {
      _isOpen = false;
    });
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _close,
      child: Container(
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Menu button
            GestureDetector(
              onTap: _toggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _isOpen ? Colors.grey[200] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _isOpen
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: AnimatedScale(
                  scale: _isOpen ? 0.95 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),

            // Dropdown menu
            if (_isOpen)
              Positioned(
                right: 0,
                top: 36,
                child: GestureDetector(
                  onTap: () {}, // Prevent closing when clicking on the menu
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            width: 160,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit option
                                InkWell(
                                  onTap: _handleEdit,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8),
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.edit,
                                          size: 14,
                                          color: Colors.blue[600],
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Edit',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF374151),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Delete option
                                InkWell(
                                  onTap: _handleDelete,
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(8),
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete,
                                          size: 14,
                                          color: Colors.red[600],
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Delete',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF374151),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
    );
  }
}
