import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('App Version Control', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Force drivers and riders to update their apps to access the network.', style: GoogleFonts.inter(color: Colors.grey[700])),
        const SizedBox(height: 24),
        const AppVersionCard(appType: 'driver_app', title: 'Driver App Settings'),
        const SizedBox(height: 16),
        const AppVersionCard(appType: 'rider_app', title: 'Rider App Settings'),
      ],
    );
  }
}

class AppVersionCard extends StatefulWidget {
  final String appType;
  final String title;

  const AppVersionCard({super.key, required this.appType, required this.title});

  @override
  State<AppVersionCard> createState() => _AppVersionCardState();
}

class _AppVersionCardState extends State<AppVersionCard> {
  final _minController = TextEditingController();
  final _latestController = TextEditingController();
  final _urlController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final event = await FirebaseDatabase.instance.ref('app_settings/${widget.appType}').once();
    if (event.snapshot.exists) {
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      _minController.text = data['minimum_version']?.toString() ?? '1.0.0';
      _latestController.text = data['latest_version']?.toString() ?? '1.0.0';
      _urlController.text = data['play_store_url']?.toString() ?? '';
    } else {
      _minController.text = '1.0.0';
      _latestController.text = '1.0.0';
    }
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    await FirebaseDatabase.instance.ref('app_settings/${widget.appType}').update({
      'minimum_version': _minController.text.trim(),
      'latest_version': _latestController.text.trim(),
      'play_store_url': _urlController.text.trim(),
    });
    
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minController,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Version (Force Update)',
                      border: OutlineInputBorder(),
                      helperText: 'e.g. 1.0.0',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _latestController,
                    decoration: const InputDecoration(
                      labelText: 'Latest Version (Soft Update)',
                      border: OutlineInputBorder(),
                      helperText: 'e.g. 1.0.5',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Play Store URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveData,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Save Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
