import 'package:flutter/material.dart';

class FieldSquareEdit extends StatelessWidget {
  final TextEditingController controller;
  final bool isPassword;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType inputType;
  final String? Function(String?)? validator;

  const FieldSquareEdit({
    Key? key,
    required this.controller,
    required this.isPassword,
    required this.hintText,
    required this.prefixIcon,
    this.inputType = TextInputType.text,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // Menyesuaikan dengan lebar layar
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 251, 231, 233),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: inputType,
        cursorColor: const Color(0xFFC58189),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFFC58189),
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: const Color(0xFFC58189),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: const Color.fromARGB(255, 251, 231, 233),
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
        ),
        validator: validator,
      ),
    );
  }
}
