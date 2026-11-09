import 'dart:io';

void main() {
  String code = File('lib/broadcast_wrapper.dart').readAsStringSync();
  
  // Replace _downloadAndShowBroadcast and _showBroadcastDialog
  String oldLogic = '''  Future<void> _downloadAndShowBroadcast(String id, String imageUrl) async {
    if (_isShowing || _currentlyProcessingId == id) return;
    _currentlyProcessingId = id;

    try {
      await precacheImage(NetworkImage(imageUrl), context);

      if (mounted && !_dismissedIds.contains(id) && !_isShowing) {
        _showBroadcastDialog(id, imageUrl);
      }
    } catch (e) {
      debugPrint('Failed to preload broadcast image: \$e');
    } finally {
      _currentlyProcessingId = null;
    }
  }

  void _showBroadcastDialog(String id, String imageUrl) {
    if (_isShowing) return;
    _isShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain, 
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  radius: 18,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () {
                      _markAsDismissed(id);
                      Navigator.of(context).pop();
                      _isShowing = false;
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }''';

  String newLogic = '''  Future<void> _downloadAndShowBroadcast(String id, String imageUrl) async {
    if (_isShowing || _currentlyProcessingId == id) return;
    _currentlyProcessingId = id;

    try {
      final imageProvider = NetworkImage(imageUrl);
      final stream = imageProvider.resolve(createLocalImageConfiguration(context));
      
      final completer = java.Completer<void>();
      late ImageStreamListener listener;
      
      listener = ImageStreamListener(
        (ImageInfo info, bool syncCall) {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (dynamic exception, StackTrace? stackTrace) {
          if (!completer.isCompleted) completer.completeError(exception);
        },
      );
      
      stream.addListener(listener);
      await completer.future;
      stream.removeListener(listener);

      if (mounted && !_dismissedIds.contains(id) && !_isShowing) {
        _showBroadcastDialog(id, imageProvider);
      }
    } catch (e) {
      debugPrint('Failed to preload broadcast image: \$e');
    } finally {
      _currentlyProcessingId = null;
    }
  }

  void _showBroadcastDialog(String id, ImageProvider imageProvider) {
    if (_isShowing) return;
    _isShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.contain, 
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  radius: 18,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () {
                      _markAsDismissed(id);
                      Navigator.of(context).pop();
                      _isShowing = false;
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }''';

  newLogic = newLogic.replaceAll('java.Completer', 'Completer');

  if (code.contains('_showBroadcastDialog')) {
    code = code.replaceFirst(oldLogic, newLogic);
    File('lib/broadcast_wrapper.dart').writeAsStringSync(code);
    print('Broadcast patched');
  } else {
    print('Patch failed');
  }
}
