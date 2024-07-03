// lib/graphic_display.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'in_app_browser.dart';

class CVEChartScreen extends StatefulWidget {
  final String jsonFileName;

  CVEChartScreen({required this.jsonFileName});

  @override
  _CVEChartScreenState createState() => _CVEChartScreenState();
}

class _CVEChartScreenState extends State<CVEChartScreen> {
  List<charts.Series<CVERange, String>> _seriesBarData = [];
  List<charts.Series<CVERange, String>> _impactBarData = [];
  List<charts.Series<CVERange, String>> _exploitabilityBarData = [];

  final cveList = <CVE>[];
  final severeCVE = <CVE>[];


  @override
  void initState() {
    super.initState();
    _loadCVEData();
  }

  Future<void> _loadCVEData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${widget.jsonFileName}';
      final jsonString = await File(filePath).readAsString();
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;

      // Define the CVE ranges to count iterations
      final ranges = {
        '0-2': 0,
        '2.1-4': 0,
        '4.1-6': 0,
        '6.1-8': 0,
        '8.1-10': 0,
      };

      // Variables to calculate averages
      String range;
      final Map<String, double>totalImpactScore = {
        '0-2': 0.0,
        '2.1-4': 0.0,
        '4.1-6': 0.0,
        '6.1-8': 0.0,
        '8.1-10': 0.0,
      };
      final Map<String, double> totalExploitabilityScore = {
        '0-2': 0.0,
        '2.1-4': 0.0,
        '4.1-6': 0.0,
        '6.1-8': 0.0,
        '8.1-10': 0.0,
      };

      CVE cve;


      // Categorize CVEs by their CVSS scores and calculate averages
      jsonData.forEach((key, value) {
        final cvssScore = value['cvssScore'] as double?;
        final impactScore = value['impactScore'] as double?;
        final exploitabilityScore = value['exploitabilityScore'] as double?;
        final cveName = key as String?;
        final cveRecommend = value['recommend'] as String?;
        range = '?';

        if (cvssScore != null) {
          if (cvssScore <= 2) {
            range ='0-2';
          } else if (cvssScore > 2 && cvssScore <= 4) {
            range = '2.1-4';
          } else if (cvssScore > 4 && cvssScore <= 6) {
            range = '4.1-6';
          } else if (cvssScore > 6 && cvssScore <= 8) {
            range = '6.1-8';
          } else if (cvssScore > 8) {
            range = '8.1-10';
          }
        }

        ranges[range] = ranges[range]! + 1;
        if(impactScore != null) {
          totalImpactScore[range] = totalImpactScore[range]! + impactScore;
        }
        if(exploitabilityScore != null) {
          totalExploitabilityScore[range] =
              totalExploitabilityScore[range]! + exploitabilityScore;
        }
        cve = CVE(cveName!, cvssScore!, impactScore!, exploitabilityScore!, cveRecommend!);
        cveList.add(cve);
        if(exploitabilityScore >= 8 && impactScore >= 8){
          severeCVE.add(cve);
        }

      });

      // Prepare the data for the bar chart
      final cveData = ranges.keys.map((range) {
        final count = ranges[range]!;
        final avgImpactScore = ranges[range]! > 0
            ? totalImpactScore[range]! / ranges[range]!
            : 0.0;
        final avgExploitabilityScore = ranges[range]! > 0
            ? totalExploitabilityScore[range]! / ranges[range]!
            : 0.0;
        return CVERange(range, count, avgExploitabilityScore, avgImpactScore);
      }).toList();

      setState(() {
        _seriesBarData.add(
          charts.Series(
            domainFn: (CVERange range, _) => range.range,
            measureFn: (CVERange range, _) => range.count,
            id: 'CVEs',
            data: cveData,
            fillColorFn: (CVERange range, _) =>
                charts.ColorUtil.fromDartColor(Colors.blue),
          ),
        );

        _impactBarData.add(
          charts.Series(
            domainFn: (CVERange score, _) => score.range,
            measureFn: (CVERange score, _) => score.impactScore,
            measureUpperBoundFn: (CVERange score, _) => 10,
            id: 'Impact',
            data: cveData,
            fillColorFn: (CVERange score, _) =>
                charts.ColorUtil.fromDartColor(_getColorForScore(score.impactScore)),
          ),
        );

        _exploitabilityBarData.add(
          charts.Series(
            domainFn: (CVERange score, _) => score.range,
            measureFn: (CVERange score, _) => score.exploitabilityScore,
            id: 'Exploitability',
            data: cveData,
            fillColorFn: (CVERange score, _) =>
                charts.ColorUtil.fromDartColor(_getColorForScore(score.exploitabilityScore)),
          ),
        );
      });
    } catch (e) {
      print('Error: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CVE Distribution'),
        actions: [
          PopupMenuButton<String>(
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'cveList',
                child: Text('CVE List'),
              ),
              //TODO: widget explaining data here
              const PopupMenuItem<String>(
                value: 'info',
                child: Text('What is this?'),
              ),
            ],
            onSelected: (String value) {
              if (value == 'cveList') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CVECardList(cveList.reversed.toList())),
                );
              } else if (value == 'info') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TextDisplayPage()),
                );
              }
            },
          ),
        ],
      ),
      body: _seriesBarData.isEmpty
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.all(8.0),
            child: _topText(severeCVE)
            ),
            //if(severeCVE.isNotEmpty){
              ElevatedButton(onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CVECardList(severeCVE.reversed.toList())),
                );
              },
                child: Text('Show Severe CVE List'),
              ),
            //}
            Padding(padding: const EdgeInsets.all(8.0),
            child: Text('Vulnerabilities found: (Nº)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28.0),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: 300,
                child: charts.BarChart(
                  _seriesBarData,
                  animate: true,
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.all(8.0),
              child: Text('Impact score average',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28.0),),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: 100,
                child: charts.BarChart(
                  _impactBarData,
                  animate: true,
                  vertical: false,
                  primaryMeasureAxis: charts.NumericAxisSpec(
                    viewport: charts.NumericExtents(0, 10),
                  ),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.all(8.0),
              child: Text('Exploitability score average',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28.0),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: 100,
                child: charts.BarChart(
                  _exploitabilityBarData,
                  animate: true,
                  vertical: false,
                  primaryMeasureAxis: charts.NumericAxisSpec(
                    viewport: charts.NumericExtents(0, 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class CVECardList extends StatelessWidget {
  final List<CVE> cveList;

  CVECardList(this.cveList);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CVE Card List'),
      ),
      body: ListView.builder(
        itemCount: cveList.length,
        itemBuilder: (context, index) {
          final cve = cveList[index];
          return Card(
            child: InkWell(
              onTap: () async {
                //TODO: Fix http located CVE solution
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InAppBrowserPage(url: 'https://nvd.nist.gov/vuln/detail/${cve.name}'),
                  ),
                );
              },
              onLongPress: () async{
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return SimpleDialog(
                      title: Text('CVE options'),
                      children: [
                        SimpleDialogOption(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InAppBrowserPage(url: 'https://nvd.nist.gov/vuln/detail/${cve.name}'),
                              ),
                            );
                          },
                          child: Text('Go to NIST official information page'),
                        ),
                        SimpleDialogOption(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InAppBrowserPage(url: cve.recommend),
                              ),
                            );
                          },
                          child: Text('Go to Vendors recommendation page'),
                        ),
                      ],
                    );
                  },
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(child: Text(cve.name)),
                    _buildScoreContainer(cve.cvssScore, _getColorForScore(cve.cvssScore), 'CVSS'),
                    SizedBox(width: 8),
                    _buildScoreContainer(cve.impactScore, _getColorForScore(cve.impactScore), 'Impact'),
                    SizedBox(width: 8),
                    _buildScoreContainer(cve.exploitabilityScore, _getColorForScore(cve.exploitabilityScore), 'Exploitability'),
                    SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _buildScoreContainer(double score, Color color, String label) {
  return Column(
    children: [
      Container(
        width: 30,
        height: 30,
        color: color,
        alignment: Alignment.center,
        child: Text(
          score.toString(),
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      ),
      SizedBox(height: 4),
      Text(label),
    ],
  );
}


class TextDisplayPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Information'),
      ),
      body: Center(
        child: Text(
          'The data displayed here shows how vulnerable your device is.\n'
              'The first graphic (the blue one) shows how many Vulnerabilities were'
              ' found for your current Android Version and installed apps.\n'
              'The second graphic displays the impact score, that, to put it simple, '
              'shows how much damage a potential attacker can deal if he \"hacks\"'
              ' you\n'
              'The third one, shows the exploitability score average, which measures '
              'how easy/common it is for attackers to take advantage of said vulnerability\n\n'
              'Each graphic has been separated based in their cvssScore, a score which '
              'measures the overall risk of the potential vulnerability. Higher bars in'
              ' the higher scores sectors means higher risk',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
        ),
      ),
    );
  }
}

Color _getColorForScore(double score) {
  Color color;
  if (score >= 0 && score <= 2.5) {
    color = Colors.lime;
  } else if (score > 2.5 && score <= 5) {
    color = Colors.orangeAccent;
  } else if (score > 5 && score <= 7.5) {
    color = Colors.deepOrangeAccent;
  } else if (score > 7.5 && score <=9){
    color = Colors.red;
  }
  else{
    color = Colors.black;
  }
    return color;
}

Text _topText(List<CVE> sevCve){
  String text;
  Color color;
  if(sevCve.isEmpty){
    text = 'Congratulations!\nNo severe vulnerabilities were found for your device';
    color = Colors.green;
  }
  else if(sevCve.length > 0 && sevCve.length <= 5){
    text = 'Warning:\n${sevCve.length} severe Vulnerabilities were found, click below'
        ' to check them and update the related app as soon as possible!';
    color = Colors.orangeAccent;
  }
  else{
    text = 'Potential risk:\n${sevCve.length} severe Vulnerabilities were found, click below'
        ' to check them and update the related app as soon as possible!';
    color = Colors.red;
  }
  return Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 20.0));
}

// CVE Range statistics class
class CVERange {
  final String range;
  final int count;
  final double exploitabilityScore;
  final double impactScore;

  CVERange(this.range, this.count, this.exploitabilityScore, this.impactScore);
}

class CVE {
  final String name;
  final double cvssScore;
  final double impactScore;
  final double exploitabilityScore;
  String recommend;
  CVE(this.name, this.cvssScore, this.impactScore, this.exploitabilityScore, this.recommend);
}
