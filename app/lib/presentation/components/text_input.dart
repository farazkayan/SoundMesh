import 'package:flutter/material.dart';
import 'package:soundmesh/core/design_system/index.dart';

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
  });

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

  @override
  Widget build(BuildContext context) {
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