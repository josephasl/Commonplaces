import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DeleteTriggerButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const DeleteTriggerButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        // Style: Light Red Background with Red Text (Common iOS "Destructive" Action style)
        // If you prefer Solid Red with White text, change color to destructiveRed and text to white.
        color: const Color(0xFFFFE5E5),
        pressedOpacity: 0.7,
        borderRadius: BorderRadius.circular(12),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            color: CupertinoColors.destructiveRed,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
