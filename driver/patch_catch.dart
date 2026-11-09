import 'dart:io';

void main() {
  String code = File('lib/screens/login_options_screen.dart').readAsStringSync();
  String oldCatch = '''    } on FirebaseAuthException catch (e) {
      if (mounted) {
        CustomToast.show(context, e.message ?? 'Google Sign-In failed');
      }
    } finally {''';
  String newCatch = '''    } on FirebaseAuthException catch (e) {
      if (mounted) {
        CustomToast.show(context, e.message ?? 'Google Sign-In failed');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Google Sign-In Error: \$e');
      }
    } finally {''';
  if (code.contains(oldCatch)) {
    code = code.replaceFirst(oldCatch, newCatch);
    File('lib/screens/login_options_screen.dart').writeAsStringSync(code);
    print('Catch patched');
  } else {
    print('Patch failed');
  }
}
