// ============================================================
// auth_text_field.dart
// ============================================================
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final IconData? prefixIcon;
  final Widget? suffixIcon;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textPrimaryDark,
          ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.textTertiaryDark, size: 20)
            : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
