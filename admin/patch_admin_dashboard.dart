import 'dart:io';

void main() {
  String code = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  // 1. Remove live_map_tab import
  code = code.replaceAll("import 'live_map_tab.dart';", "");
  
  // 2. Remove LiveMapTab from _tabs
  String oldTabs = '''  final List<Widget> _tabs = const [
    UserManagementTab(),
    LiveMapTab(),
    AnalyticsTab(),
    BroadcastTab(),
    SettingsTab(),
  ];''';
  String newTabs = '''  final List<Widget> _tabs = const [
    UserManagementTab(),
    AnalyticsTab(),
    BroadcastTab(),
    SettingsTab(),
  ];''';
  code = code.replaceFirst(oldTabs, newTabs);

  // 3. Remove Nav Item
  String oldNavItems = '''                _buildNavItem(0, Icons.people_outline, Icons.people, 'Users'),
                _buildNavItem(1, Icons.map_outlined, Icons.map, 'Live Map'),
                _buildNavItem(2, Icons.bar_chart_outlined, Icons.bar_chart, 'Analytics'),
                _buildNavItem(3, Icons.campaign_outlined, Icons.campaign, 'Broadcast'),
                _buildNavItem(4, Icons.settings_outlined, Icons.settings, 'Settings'),''';
  String newNavItems = '''                _buildNavItem(0, Icons.people_outline, Icons.people, 'Users'),
                _buildNavItem(1, Icons.bar_chart_outlined, Icons.bar_chart, 'Analytics'),
                _buildNavItem(2, Icons.campaign_outlined, Icons.campaign, 'Broadcast'),
                _buildNavItem(3, Icons.settings_outlined, Icons.settings, 'Settings'),''';
  code = code.replaceFirst(oldNavItems, newNavItems);

  // 4. Update logout action to show confirmation
  String oldLogout = '''          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            tooltip: 'Logout',
          ),''';
  String newLogout = '''          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                await FirebaseAuth.instance.signOut();
              }
            },
            tooltip: 'Logout',
          ),''';
  code = code.replaceFirst(oldLogout, newLogout);

  File('lib/screens/dashboard_screen.dart').writeAsStringSync(code);
  print('Dashboard patched');
}
