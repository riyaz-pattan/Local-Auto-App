import 'dart:io';

void main() {
  String code = File('lib/screens/user_management_tab.dart').readAsStringSync();
  
  // Add _currentLimit state
  if (!code.contains('int _currentLimit = 30;')) {
    code = code.replaceAll(
      "String _selectedFilter = 'All';",
      "String _selectedFilter = 'All';\n  int _currentLimit = 30;"
    );
  }

  // Update the stream query
  code = code.replaceAll(
    "stream: FirebaseFirestore.instance.collection('drivers').snapshots(),",
    "stream: FirebaseFirestore.instance.collection('drivers').orderBy('createdAt', descending: true).limit(_currentLimit).snapshots(),"
  );

  // Add the "Load More" button at the end of the ListView
  String oldListView = "return ListView.builder(\n                padding: const EdgeInsets.all(16),\n                itemCount: docs.length,\n                itemBuilder: (context, index) {";
  
  String newListView = '''return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length + 1, // +1 for the load more button
                itemBuilder: (context, index) {
                  if (index == docs.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _currentLimit += 30;
                            });
                          },
                          icon: const Icon(Icons.expand_more),
                          label: const Text('Load More Drivers'),
                        ),
                      ),
                    );
                  }''';
                  
  code = code.replaceAll(oldListView, newListView);
  
  File('lib/screens/user_management_tab.dart').writeAsStringSync(code);
}
