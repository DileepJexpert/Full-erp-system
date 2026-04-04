import 'package:flutter/material.dart';

class RecentBillsFeed extends StatelessWidget {
  const RecentBillsFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Recent bills will appear here'),
      ),
    );
  }
}
