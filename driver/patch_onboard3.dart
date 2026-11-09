import 'dart:io';

void main() {
  String code = File('lib/screens/onboarding_screen.dart').readAsStringSync();
  
  String oldBody = '''      body: Column(
        children: [
          // Step indicator''';
          
  String newBody = '''      body: _loadingData 
          ? const Center(child: CircularProgressIndicator()) 
          : Column(
        children: [
          // Step indicator''';
          
  if (code.contains(oldBody)) {
    code = code.replaceFirst(oldBody, newBody);
    File('lib/screens/onboarding_screen.dart').writeAsStringSync(code);
    print('Fixed _loadingData body usage');
  } else {
    print('Failed to find body');
  }
}
