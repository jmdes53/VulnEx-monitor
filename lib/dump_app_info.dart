import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';

Future<void> dumpAppInfoToJson(BuildContext context) async {
  // Show a loading dialog for visual purposes
  showDialog(
    context: context,
    barrierDismissible: false, // Prevent dismissing dialog by tapping outside
    builder: (BuildContext context) {
      return AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Dumping System Info...'),
          ],
        ),
      );
    },
  );

  // Get current date to properly identify the analysis
  DateTime now = DateTime.now();
  String formattedDate = '${now.day.toString().padLeft(2, '0')}_${now.month.toString().padLeft(2, '0')}_${now.year}_app_info.json';

  // Get device info
  late AndroidDeviceInfo androidInfo;
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  androidInfo = await deviceInfo.androidInfo;

  // Get installed apps
  List<AppInfo> installedApps = await InstalledApps.getInstalledApps();

  // Create JSON data
  Map<String, dynamic> jsonData = {
    'android_version': androidInfo.version.release,
    'sec_patch': androidInfo.version.securityPatch,
    'apps': installedApps.map((app) => {
      'version': app.versionName,
      'package': app.packageName,
    }).toList(),
  };

  // Convert String to JSON data
  String jsonString = jsonEncode(jsonData);

  // Write JSON data to a file
  final Directory appDocDir = await getApplicationDocumentsDirectory();
  String appDocPath = appDocDir.path;
  final File jsonFile = File('$appDocPath/$formattedDate');
  await jsonFile.writeAsString(jsonString);

  // Close loading dialog
  Navigator.of(context).pop();

  // Show success message
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('App info dumped to $formattedDate'),
  ));
}