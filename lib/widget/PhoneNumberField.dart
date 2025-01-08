import 'package:flutter/material.dart';

class PhoneNumberField extends StatelessWidget {
  final TextEditingController controller;

  const PhoneNumberField({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 500,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 251, 231, 233),
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC58189).withOpacity(1),
          ),
        ],
      ),
      child: TextFormField(
        keyboardType: TextInputType.phone,
        cursorColor: const Color(0xFFC58189),
        controller: controller,
        onChanged: (value) {
          // Menghapus angka 0 di depan jika ada
          if (value.startsWith('0')) {
            controller.text = value.substring(1);
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
          }
        },
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              '+62',
              style: const TextStyle(
                color: Color(0xFFC58189),
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          hintText: "Enter phone number",
          hintStyle: const TextStyle(
            color: Color(0xFFC58189),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.only(top: 20.0, bottom: 0.0),
        ),
      ),
    );
  }
}
