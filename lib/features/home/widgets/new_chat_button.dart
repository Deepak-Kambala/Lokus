import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

class NewChatButton extends StatelessWidget {
  final VoidCallback onPressed;

  const NewChatButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'New Chat',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Icon(
            Icons.add_comment_outlined,
            size: 18,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
