import 'package:flutter/cupertino.dart';
import '../app_styles.dart';

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
        color: AppColors.destructiveBg,
        pressedOpacity: 0.7,
        borderRadius: BorderRadius.circular(AppDimens.radiusM),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.destructive,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
