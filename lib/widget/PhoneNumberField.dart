import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PhoneNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool readOnly;
  final FocusNode? focusNode;

  const PhoneNumberField({
    Key? key,
    required this.controller,
    this.validator,
    this.readOnly = false,
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      keyboardType: TextInputType.phone,
      cursorColor: const Color(0xFFC58189),
      style: GoogleFonts.poppins(
        fontSize: 15,
        color: Colors.black87,
      ),
      validator: validator ?? _defaultValidator,
      onChanged: (value) {
        // Remove leading zero if present
        if (value.startsWith('0')) {
          controller.text = value.substring(1);
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        }
      },
      decoration: InputDecoration(
        hintText: 'Masukkan nomor telepon',
        hintStyle: GoogleFonts.poppins(
          color: Colors.grey[400],
          fontSize: 14,
        ),
        prefixIcon: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          margin: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phone_android,
                color: const Color(0xFFC58189),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '+62',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFC58189),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 80,
          minHeight: 0,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE8C4BD),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        errorStyle: GoogleFonts.poppins(
          fontSize: 12,
        ),
      ),
    );
  }

  String? _defaultValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nomor telepon tidak boleh kosong';
    }

    if (value.length < 9) {
      return 'Nomor telepon tidak valid';
    }

    return null;
  }
}
