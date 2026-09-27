import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';
import 'tsx_visual_tokens.dart';

class SMTextField extends StatelessWidget {
  const SMTextField({
    super.key,
    this.hintText,
    this.labelText,
    this.errorText,
    this.helperText,
    this.controller,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.keyboardType,
    this.textAlign,
    this.prefixIcon,
    this.suffixIcon,
    this.tsx = false,
  });

  const SMTextField.tsx({
    super.key,
    this.hintText,
    this.labelText,
    this.errorText,
    this.helperText,
    this.controller,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.keyboardType,
    this.textAlign,
    this.prefixIcon,
    this.suffixIcon,
  }) : tsx = true;

  final String? hintText;
  final String? labelText;
  final String? errorText;
  final String? helperText;
  final TextEditingController? controller;
  final bool obscureText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final int? maxLines;
  final TextInputType? keyboardType;
  final TextAlign? textAlign;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool tsx;

  @override
  Widget build(BuildContext context) {
    if (tsx) {
      return TextFormField(
        controller: controller,
        obscureText: obscureText,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textAlign: textAlign ?? TextAlign.start,
        validator: validator,
        onFieldSubmitted: onSubmitted,
        onChanged: onChanged,
        style: TSXTypography.bodyMedium,
        decoration: InputDecoration(
          hintText: hintText,
          labelText: labelText,
          errorText: errorText,
          helperText: helperText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: TSXColors.background,
          contentPadding: EdgeInsets.symmetric(
            horizontal: TSXSpacing.lg,
            vertical: TSXSpacing.md,
          ),
          hintStyle: TSXTypography.bodySmall,
          labelStyle: TSXTypography.bodyMedium.copyWith(color: TSXColors.secondaryText),
          errorStyle: TSXTypography.caption.copyWith(color: TSXColors.error),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TSXRadius.input),
            borderSide: BorderSide(color: TSXColors.surfaceBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TSXRadius.input),
            borderSide: BorderSide(color: TSXColors.surfaceBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TSXRadius.input),
            borderSide: BorderSide(color: TSXColors.accent, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TSXRadius.input),
            borderSide: BorderSide(color: TSXColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TSXRadius.input),
            borderSide: BorderSide(color: TSXColors.error, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(TSXRadius.input),
            borderSide: BorderSide(color: TSXColors.mutedText),
          ),
        ),
      );
    }

    // Original v3 design
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textAlign: textAlign ?? TextAlign.start,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        errorText: errorText,
        helperText: helperText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
      style: SMTypography.body.copyWith(color: SMColors.primaryText),
    );
  }
}