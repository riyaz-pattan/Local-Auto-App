import 'dart:io';

void main() {
  final file = File('admin/lib/screens/user_management_tab.dart');
  String code = file.readAsStringSync();

  // 1. Add import for firebase_database
  if (!code.contains("import 'package:firebase_database/firebase_database.dart';")) {
    code = code.replaceFirst("import 'package:cloud_firestore/cloud_firestore.dart';", "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:firebase_database/firebase_database.dart';");
  }

  // 2. We need to replace the Expanded( child: StreamBuilder<QuerySnapshot>( ... ) ) 
  // with Expanded( child: StreamBuilder<DatabaseEvent>( ... ) )
  
  // Let's find the Expanded block
  int startIndex = code.indexOf('Expanded(');
  if (startIndex == -1) { print("Expanded not found"); return; }
  
  // We want to replace the whole Expanded block up to where it returns ListView
  // It's safer to use a regex or string replacement.
}
