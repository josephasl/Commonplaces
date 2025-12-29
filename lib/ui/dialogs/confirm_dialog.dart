import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/base_bottom_sheet.dart';

Future<void> showDeleteConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? subtitle,
  required VoidCallback onConfirm,
  String confirmLabel = "Delete",
}) {
  return showCupertinoModalPopup(
    context: context,
    builder: (ctx) => BaseBottomSheet(
      title: title,
      hideSave: true,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 24.0,
              horizontal: 16.0,
            ),
            child: Column(
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Red Delete Button
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: CupertinoColors.destructiveRed,
              borderRadius: BorderRadius.circular(12),
              onPressed: () {
                onConfirm();
                Navigator.pop(ctx);
              },
              child: Text(
                confirmLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
