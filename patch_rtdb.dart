import 'dart:io';

void main() {
  final file = File('admin/lib/screens/user_management_tab.dart');
  String code = file.readAsStringSync();

  // Add import
  if (!code.contains("import 'package:firebase_database/firebase_database.dart';")) {
    code = code.replaceFirst("import 'package:cloud_firestore/cloud_firestore.dart';", "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:firebase_database/firebase_database.dart';");
  }

  final oldBlock = r'''        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: (() {
              Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('drivers');
              
              if (_selectedFilter != 'All') {
                q = q.where('status', isEqualTo: _selectedFilter.toLowerCase());
              }
              
              if (_searchQuery.isNotEmpty) {
                // Firestore Prefix Search (Server-side)
                q = q.where('name', isGreaterThanOrEqualTo: _searchQuery)
                     .where('name', isLessThan: _searchQuery + '\uf8ff')
                     .orderBy('name'); // Required by Firestore when using range operators
              } else {
                q = q.orderBy('createdAt', descending: true);
              }
              
              return q.limit(_currentLimit).snapshots();
            })(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading users', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Theme.of(context).colorScheme.secondary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text('No users found', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.secondary)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                          label: Text('Load More Drivers', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    );
                  }
                  final data = docs[index].data() as Map<String, dynamic>;
                  final driverId = docs[index].id;''';

  final newBlock = r'''        Expanded(
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('drivers_index').onValue,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading users', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final rtdbData = snapshot.data?.snapshot.value as Map<dynamic, dynamic>? ?? {};
              
              List<Map<String, dynamic>> allDrivers = [];
              rtdbData.forEach((key, value) {
                final driverData = Map<String, dynamic>.from(value as Map);
                driverData['id'] = key;
                allDrivers.add(driverData);
              });

              // Apply Tab Filter
              if (_selectedFilter != 'All') {
                allDrivers = allDrivers.where((d) => d['status'] == _selectedFilter.toLowerCase()).toList();
              }

              // Apply Search Filter
              if (_searchQuery.isNotEmpty) {
                allDrivers = allDrivers.where((d) => 
                  (d['name'] as String? ?? '').toLowerCase().contains(_searchQuery) ||
                  (d['phone'] as String? ?? '').contains(_searchQuery)
                ).toList();
              }

              // Sort by createdAt descending
              allDrivers.sort((a, b) {
                final aTime = a['createdAt'] as int? ?? 0;
                final bTime = b['createdAt'] as int? ?? 0;
                return bTime.compareTo(aTime);
              });

              final isEndReached = allDrivers.length <= _currentLimit;
              final displayDrivers = allDrivers.take(_currentLimit).toList();

              if (displayDrivers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Theme.of(context).colorScheme.secondary.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text('No users found', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.secondary)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: displayDrivers.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == displayDrivers.length) {
                    if (isEndReached) return const SizedBox.shrink();
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
                          label: Text('Load More Drivers', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    );
                  }
                  
                  final data = displayDrivers[index];
                  final driverId = data['id'] as String;''';

  code = code.replaceFirst(oldBlock, newBlock);
  file.writeAsStringSync(code);
}
