import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';

class ModelLogo extends StatelessWidget {
  final String value;
  final double size;

  const ModelLogo({
    super.key,
    required this.value,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final isAsset = value.startsWith('assets/');
    final padding = size <= 28 ? 3.0 : 7.0;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: isAsset
          ? Image.asset(
              value,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.memory_rounded,
                color: AppTheme.textSecondary,
              ),
            )
          : Center(
              child: Text(
                value,
                style: TextStyle(fontSize: size * 0.42),
              ),
            ),
    );
  }
}
