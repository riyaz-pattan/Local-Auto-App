import 'dart:io';

void main() {
  String code = File('lib/screens/user_management_tab.dart').readAsStringSync();
  
  String oldListView = "return ListView.separated(\n                padding: const EdgeInsets.all(16),\n                itemCount: docs.length,\n                separatorBuilder:";
  
  String newListView = '''return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length + 1,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == docs.length) {
                    if (docs.length < _currentLimit) {
                       return const SizedBox.shrink(); // Reached end of DB
                    }
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
                  }
                  final doc = docs[index];''';

  // We have to correctly map the rest of itemBuilder since it was replaced.
  // Wait, replacing it with a regex or simpler replace is safer. Let's look at the actual itemBuilder.
}
