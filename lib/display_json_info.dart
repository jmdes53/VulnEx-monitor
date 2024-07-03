import 'package:flutter/material.dart';
import 'analysis_list.dart';

class JsonInfoScreen extends StatelessWidget {
  final Analysis analysis;

  JsonInfoScreen({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('JSON Info'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Date: ${analysis.getFormattedMonthName()} ${analysis.date.day}, ${analysis.date.year}'),
            SizedBox(height: 16),
            Text('Data:'),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: analysis.data.map((item) => Text(item)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
