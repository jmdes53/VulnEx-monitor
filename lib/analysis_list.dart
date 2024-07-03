import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class Analysis {
  final DateTime date;
  final List<String> data;

  Analysis({required this.date, required this.data});

  factory Analysis.fromJson(Map<String, dynamic> json) {
    return Analysis(
      date: DateTime.parse(json['date']),
      data: List<String>.from(json['data']),
    );
  }

  String getFormattedMonthName() {
    return DateFormat('MMMM').format(date);
  }

  int getDaysDifference() {
    DateTime currentDate = DateTime.now();
    return currentDate.difference(date).inDays;
  }
}

Future<List<Analysis>> fetchAnalysisData() async {
  List<Analysis> analysisList = [];

  try {
    // Get list of all files in directory
    Directory directory = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> files = directory.listSync();
    for (FileSystemEntity file in files) {
      if (file is File && file.path.endsWith('_app_info.json')) {
        // Read JSON data from file
        String jsonString = await file.readAsString();
        Map<String, dynamic> jsonData = jsonDecode(jsonString);

        // Extract date from filename
        String filename = file.path.split('/').last;
        List<String> parts = filename.split('_');
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        DateTime date = DateTime(year, month, day);

        // Extract analysis data from JSON
        List<String> data = [];
        data.add('Android Version: ${jsonData['android_version']}');
        data.add('Security patch: ${jsonData['sec_patch']}');
        data.add('=== Application packages ===');
        jsonData['apps'].forEach((app) {
          data.add('(${app['package']}): ${app['version']}');
        });

        // Create Analysis object and add it to the list
        analysisList.add(Analysis(date: date, data: data));
      }
    }
  } catch (e) {
    print('Error fetching analysis data: $e');
  }

  return analysisList;
}