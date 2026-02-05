import 'package:flutter/material.dart';
import 'box_list_item.dart';

class BoxList extends StatelessWidget {
  const BoxList({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: ListView.builder(
          itemCount: 10,
          itemBuilder: (context, index) {
            return BoxListItem(index: index);
          },
        ),
      ),
    );
  }
}
