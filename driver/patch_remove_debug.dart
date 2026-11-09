import 'dart:io';

void main() {
  String code = File('lib/screens/login_options_screen.dart').readAsStringSync();
  
  String oldCatch = '''    } catch (e) {
      if (mounted) {
        // Show detailed debug dialog for ApiException 10
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Debug Login Error'),
            content: SingleChildScrollView(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  String sha1 = snapshot.hasData ? snapshot.data!.buildSignature : 'Loading...';
                  // Format the hex string to XX:XX:XX format for easy copying/reading
                  if (sha1.length == 40 && !sha1.contains(':')) {
                    sha1 = [for (var i = 0; i < sha1.length; i += 2) sha1.substring(i, i + 2)].join(':').toUpperCase();
                  }
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Error: \$e\\n', style: const TextStyle(color: Colors.red)),
                      const Text('Your Installed App\\'s Exact SHA-1:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SelectableText(sha1, style: const TextStyle(fontFamily: 'monospace', fontSize: 16, color: Colors.blue)),
                      const SizedBox(height: 10),
                      const Text('1. Copy the blue SHA-1 above.\\n2. Add it to Firebase -> Driver App.\\n3. Wait 5 mins & try again.'),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
            ],
          )
        );
      }
    } finally {''';

  String newCatch = '''    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Google Sign-In Error: \$e', isError: true);
      }
    } finally {''';

  if (code.contains("Debug Login Error")) {
    code = code.replaceFirst(oldCatch, newCatch);
    
    // Also optionally remove the package_info_plus import to clean up completely
    code = code.replaceFirst("import 'package:package_info_plus/package_info_plus.dart';\n", "");
    
    File('lib/screens/login_options_screen.dart').writeAsStringSync(code);
    print('Debug dialog removed');
  } else {
    print('Patch failed');
  }
}
