import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomToast {
  static void show(BuildContext context, String message, {bool isError = true}) {
    // Clean up raw error messages
    String displayMessage = message;
    if (message.contains('] ')) {
      displayMessage = message.split('] ').last;
    }
    if (displayMessage.toLowerCase().startsWith('firebase auth error:')) {
      displayMessage = displayMessage.substring(20).trim();
    }
    if (displayMessage.toLowerCase().startsWith('exception:')) {
      displayMessage = displayMessage.substring(10).trim();
    }

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              displayMessage,
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      backgroundColor: isError ? Colors.redAccent.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      elevation: 6,
      duration: const Duration(seconds: 4),
    );
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
