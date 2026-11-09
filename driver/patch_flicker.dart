import 'dart:io';

void main() {
  String code = File('lib/main.dart').readAsStringSync();
  
  String oldStreamBuilder = '''      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _localDeviceId == null) {
          return const CustomSplashScreen(text: 'Loading...');
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const OnboardingScreen();
        }
        final data = snapshot.data!.data()! as Map<String, dynamic>;''';
        
  String newStreamBuilder = '''      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _localDeviceId == null) {
          return const CustomSplashScreen(text: 'Loading...');
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const OnboardingScreen();
        }
        final data = snapshot.data!.data()! as Map<String, dynamic>;
        
        // Fix for "Flicker" & Routing bug: 
        // When initState writes deviceId/fcmToken, Firestore's optimistic cache immediately fires a snapshot
        // containing ONLY those fields. If we route based on that, existing users see "Under Review" for a split second,
        // and new users skip onboarding!
        if (!data.containsKey('name') || !data.containsKey('phone')) {
          if (snapshot.metadata.isFromCache) {
            // It's a partial local cache document. Wait for the real server data.
            return const CustomSplashScreen(text: 'Loading profile...');
          }
          // The server confirmed they actually don't have a profile yet. Route to onboarding.
          return const OnboardingScreen();
        }''';

  code = code.replaceFirst(oldStreamBuilder, newStreamBuilder);
  File('lib/main.dart').writeAsStringSync(code);
  print('Patched ProfileGate flicker and routing logic');
}
