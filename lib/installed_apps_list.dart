import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:async';

class InstalledAppsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Installed Apps'),
      ),
      body: FutureBuilder<List<AppInfo>>(
        future: _getInstalledApps(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            List<AppInfo>? installedApps = snapshot.data;
            return ListView.builder(
              itemCount: installedApps!.length,
              itemBuilder: (context, index) {
                AppInfo app = installedApps[index];
                return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        child: Image.memory(installedApps[index].icon ?? Uint8List(0)),
                      ),

                      title: Text(app.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Version: ${app.getVersionInfo()}'),
                          Text('Package Name: ${app.packageName}'),
                        ],
                      ),
                    ),
                );
              },
            );
          }
        },
      ),
    );
  }

  Future<List<AppInfo>> _getInstalledApps() async {
    try {
      return await InstalledApps.getInstalledApps(true, true);
    } catch (e) {
      throw Exception('Failed to get installed apps: $e');
    }
  }
}