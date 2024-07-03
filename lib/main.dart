import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'display_json_info.dart';
import 'installed_apps_list.dart';
import 'dump_app_info.dart';
import 'analysis_list.dart';
import 'cve_search.dart';
import 'graphic_display.dart';

void main() {
  runApp(const MyApp());
}

class AnalysisMessage {
  final String message;
  final Color color;

  AnalysisMessage({required this.message, required this.color});
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VulnEx',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'VulnEx'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin{
  //List<Application>? apps;
  late TabController _tabController;
  String? androidVersion;
  String? lastSecurityPatch;
  List<Analysis> _analysisList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync:this );
    _getSystemInfo();
    _fetchAnalysisList();
    _loadCVEData();
  }

  Future<void> _getSystemInfo() async {
    late AndroidDeviceInfo androidInfo;

    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      androidInfo = await deviceInfo.androidInfo;
    } catch (e) {
      print('Failed to get device info: $e');
      return;
    }

    setState(() {
      androidVersion = androidInfo.version.release;
      lastSecurityPatch = androidInfo.version.securityPatch;
    });
  }

  void _showInstalledApps() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InstalledAppsList()),
    );
  }

  Future<void> _fetchAnalysisList() async {
    List<Analysis> analysisList = await fetchAnalysisData();
    setState(() {
      _analysisList = analysisList;
    });
  }

  Future<void> _loadCVEData() async {
    List<Analysis> analysisList = await fetchAnalysisData();
    setState(() {
      _analysisList = analysisList;
    });
  }

  AnalysisMessage getAnalysisMessage() {
    if (_analysisList.isEmpty) {
      return AnalysisMessage(
        message: "No analysis made? Press the '+' button to make your first analysis",
        color: Colors.red,
      );
    } else {
      int daysDifference = _analysisList.last.getDaysDifference();
      if (daysDifference >= 21) {
        return AnalysisMessage(
          message: "The last analysis was made $daysDifference days ago. Press the '+' button to make an analysis",
          color: Colors.red,
        );
      } else {
        return AnalysisMessage(
          message: "The last analysis was made $daysDifference days ago",
          color: Colors.green,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Analysis'),
            Tab(text: 'System Information'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
      children: [
          // First Tab: Analysis Record
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  getAnalysisMessage().message,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: getAnalysisMessage().color,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
              itemCount: _analysisList.length,
              itemBuilder: (context, index) {
                Analysis analysis = _analysisList[index];
                return Card(
                  child: ListTile(
                    title: Text('Date: ${analysis.getFormattedMonthName()} ${analysis.date.day} , ${analysis.date.year}'),
                    onTap: (){
                        String cveFileName = getFileName(analysis.date, 'cve_list');
                        if (cveFileName.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CVEChartScreen(jsonFileName: cveFileName),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Please check for CVEs first'),
                            ),
                          );
                        }
                    },
                    onLongPress: () {
                    // Show a dialog with a popup menu when the card is long pressed
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return SimpleDialog(
                            title: Text('Analysis options'),
                            children: [
                              SimpleDialogOption(
                                onPressed: () {
                                // Navigate to JsonInfoScreen when "json info" is selected
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => JsonInfoScreen(analysis: analysis),
                                    ),
                                  );
                                },
                                child: Text('View JSON Info'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
              ),
            ],
          ),
          // Second Tab: System data and application_list Widget
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Android Version: $androidVersion',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Last Security Patch: $lastSecurityPatch',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                // List of installed Apps
                ElevatedButton(
                  onPressed: () {
                    _showInstalledApps();
                  },
                  child: Text('Show Installed Apps'),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await dumpAppInfoToJson(context);
          showDialog(context: context, barrierDismissible: false, // Prevent dismissing dialog by tapping outside
            builder: (BuildContext context) {
              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Connecting to CVE Database...'),
                  ],
                ),
              );
            }, );
          await _fetchAnalysisList();
          DateTime now = DateTime.now();
          await checkForVulnerabilities(getFileName(now, 'app_info'), context);
          // Close loading dialog
          Navigator.of(context).pop();
        },
        tooltip: 'Do an analysis',
        child: const Icon(Icons.add),
      ),
    );
  }
}

String getFileName(DateTime date, String fileType){
  String type, File;
  if(fileType == 'app_info' || fileType == 'cve_list'){
    type = fileType;
    File = '${date.day.toString().padLeft(2, '0')}_${date.month.toString().padLeft(2, '0')}_${date.year}_${type}.json';
  }
  else
    File = '';
  return File;
}
