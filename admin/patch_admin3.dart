import 'dart:io';

void main() {
  String code = File('lib/screens/user_management_tab.dart').readAsStringSync();
  
  // Replace the StreamBuilder query logic
  String oldStream = "stream: FirebaseFirestore.instance.collection('drivers').orderBy('createdAt', descending: true).limit(_currentLimit).snapshots(),";
  
  String newStream = '''stream: (() {
              var q = FirebaseFirestore.instance.collection('drivers');
              
              if (_selectedFilter != 'All') {
                q = q.where('status', isEqualTo: _selectedFilter.toLowerCase());
              }
              
              if (_searchQuery.isNotEmpty) {
                // Firestore Prefix Search (Server-side)
                q = q.where('name', isGreaterThanOrEqualTo: _searchQuery)
                     .where('name', isLessThan: _searchQuery + '\\uf8ff')
                     .orderBy('name'); // Required by Firestore when using range operators
              } else {
                q = q.orderBy('createdAt', descending: true);
              }
              
              return q.limit(_currentLimit).snapshots();
            })(),''';
            
  if (code.contains(oldStream)) {
    code = code.replaceAll(oldStream, newStream);
  } else {
    print('Could not find oldStream');
  }

  // Remove the client-side filtering logic
  String oldFilterLogic = '''              var docs = snapshot.data?.docs ?? [];
              
              if (_selectedFilter != 'All') {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['status'] as String? ?? 'pending').toLowerCase() == _selectedFilter.toLowerCase();
                }).toList();
              }

              if (_searchQuery.isNotEmpty) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  final phone = (data['phone'] as String? ?? '').toLowerCase();
                  return name.contains(_searchQuery) || phone.contains(_searchQuery);
                }).toList();
              }''';
              
  String newFilterLogic = "              var docs = snapshot.data?.docs ?? [];";

  if (code.contains(oldFilterLogic)) {
    code = code.replaceAll(oldFilterLogic, newFilterLogic);
  } else {
    print('Could not find oldFilterLogic');
  }

  File('lib/screens/user_management_tab.dart').writeAsStringSync(code);
  print('Admin Patched');
}
