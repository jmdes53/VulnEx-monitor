// lib/cve_checker.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

Future<void> checkForVulnerabilities(String jsonFilePath, BuildContext context) async {
  try {
    // Read the JSON file to get the Android version
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$jsonFilePath';
    final jsonString = await File(filePath).readAsString();
    final jsonData = json.decode(jsonString);
    final androidVersion = jsonData['android_version'];
    final Map<String, String>appList = {'app' : 'version'};

    if (androidVersion == null) {
      throw Exception('Android version not found in JSON file');
    }
    // Query the NVD API

    // 1. Search Android Version Vulns
    //const String apiKey = 'b762158a-8c28-4304-91e3-5e2922c6f365';
    final cpeMatchString = 'cpe:2.3:o:google:android:${formattedAndroidVersion(androidVersion)}:*:*:*:*:*:*:*';
    final cpeUrl = 'https://services.nvd.nist.gov/rest/json/cpes/2.0?cpeMatchString=$cpeMatchString';
    final cpeResponse = await http.get(Uri.parse(cpeUrl));
    final cpeData = json.decode(cpeResponse.body);
    print('===CPE STRING: $cpeUrl===');

    // 2. Search Android Apps Vulns
    List<String> cpeAppList = [];
    List<String> cpeUrls = [];

    String packageName;
    String version;

    for (var app in jsonData['apps']){
        packageName = app['package'];
        version = app['version'];
        String cpe = packageNameToCpe(packageName, version);
        if (cpe != '') {
          cpeAppList.add(cpe);
          cpeUrls.add('https://services.nvd.nist.gov/rest/json/cpes/2.0?cpeMatchString='
              + cpe);
        }
    }

    for (var url in cpeUrls){
      var cpeResponse = await http.get(
        Uri.parse(url),
        /*headers: {
          'X-Api-Key': apiKey,  // Add the API key in the headers
        },*/
      );
      if (cpeResponse.statusCode == 200) {
        var cpeData = json.decode(cpeResponse.body);
        print('===CPE STRING: $url===');
        if (cpeData['products'] != null && cpeData['products'].isNotEmpty) {
          // Extract all cpeNames from the results
          final cpeNames = (cpeData['products'] as List).map((product) => product['cpe']['cpeName']).toList();
          print('CPE Names: $cpeNames');
        } else {
          print('No products found in the CPE response for $url');
        }
      } else {
        print('Failed to fetch data for $url');
      }
    }


    if (cpeData['products'] == null || cpeData['products'].isEmpty) {
      throw Exception('No products found in the CPE response');
    }

    // Extract all cpeNames from the results
    final cpeNames = (cpeData['products'] as List).map((product) => product['cpe']['cpeName']).toList();
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
              Text('Searching for vulnerabilities...'),
            ],
          ),
        );
      },
    );
    // Step 3: Query the CVE API for each cpeName
    final cveDict = <String, Map<String, dynamic>>{};

    for (final cpeName in cpeNames) {
      final cveUrl = 'https://services.nvd.nist.gov/rest/json/cves/2.0?cpeName=$cpeName';
      final cveResponse = await http.get(Uri.parse(cveUrl));
      final cveData = json.decode(cveResponse.body);

      final cveItems = cveData['vulnerabilities'] ?? [];
      for (final item in cveItems) {
        final cveId = item['cve']['id'];
        final metrics = item['cve']['metrics'] ?? {};
        final references = item['cve']['references'];

        double? cvssScore;
        double? impactScore;
        double? exploitabilityScore;
        String recommend;

        if (metrics.containsKey('cvssMetricV31')) {
          final cvssData = metrics['cvssMetricV31'][0]['cvssData'];
          cvssScore = cvssData['baseScore'];
          impactScore = cvssData['impactScore'];
          exploitabilityScore = cvssData['exploitabilityScore'];
        } else if (metrics.containsKey('cvssMetricV30')) {
          final cvssData = metrics['cvssMetricV30'][0]['cvssData'];
          cvssScore = cvssData['baseScore'];
          impactScore = cvssData['impactScore'];
          exploitabilityScore = cvssData['exploitabilityScore'];
        } else if (metrics.containsKey('cvssMetricV2')) {
          final cvssData = metrics['cvssMetricV2'][0]['cvssData'];
          cvssScore = cvssData['baseScore'];
          impactScore = cvssData['impactScore'];
          exploitabilityScore = cvssData['exploitabilityScore'];
        }
        recommend = references[0]['url'];

        // If impact or exploitability score is not directly in cvssData, check nested entries
        if (impactScore == null || exploitabilityScore == null) {
          for (final metricKey in ['cvssMetricV31', 'cvssMetricV30', 'cvssMetricV2']) {
            if (metrics.containsKey(metricKey)) {
              for (final entry in metrics[metricKey]) {
                if (impactScore == null && entry.containsKey('impactScore')) {
                  impactScore = entry['impactScore'];
                }
                if (exploitabilityScore == null && entry.containsKey('exploitabilityScore')) {
                  exploitabilityScore = entry['exploitabilityScore'];
                }
              }
            }
          }
        }

        cveDict[cveId] = {
          'cvssScore': cvssScore,
          'impactScore': impactScore,
          'exploitabilityScore': exploitabilityScore,
          'recommend': recommend,
        };
      }
    }

    // Step 4: Write the CVE details to a JSON file
    DateTime now = DateTime.now();
    String formattedDate = '${now.day.toString().padLeft(2, '0')}_${now.month.toString().padLeft(2, '0')}_${now.year}_cve_list.json';
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    final File outputFile = File('$appDocPath/$formattedDate');
    await outputFile.writeAsString(json.encode(cveDict));

    print('Unique CVE IDs with their CVSS scores, impact, and exploitability scores have been written to $outputFile');
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Vulnerabilities list written to $outputFile'),
    ));
  } catch (e) {
    print('Error: $e');
  }
}

String formattedAndroidVersion(androidVersion){
  double? version = double.tryParse(androidVersion);

  if (version == null) {
    throw ArgumentError('Invalid android version');
  }

  // Check if the number is an integer
  if (version % 1 == 0) {
    // Convert to float with one decimal place
    return version.toStringAsFixed(1);
  } else {
    // Leave as it is
    return androidVersion;
  }
}

String packageNameToCpe(String packageName, String version) {
  List<String> parts = packageName.split('.');
  var res = '';
  if (parts.length > 2) {
    String vendor = parts[1];
    String product;

    if (parts[2] != 'android')
       product = parts.sublist(2).join('_');
    else
      product = parts.sublist(3).join('_');

    if(!product.startsWith('android_apps') && vendor != 'google' && vendor != 'android')
      res = 'cpe:2.3:a:$vendor:$product:$version:*:*:*:*:android:*:*';
  }
  return res;
}