import 'package:flutter/material.dart';

class FieldSquare extends StatelessWidget {
  final TextEditingController con;
  final bool isPassword;
  final String text;
  final IconData logo;
  final Widget? suffixIcon;
  const FieldSquare({
    super.key,
    required this.con,
    required this.isPassword,
    required this.text,
    required this.logo,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    Brightness theme = MediaQuery.of(context).platformBrightness;
    return Container(
      width: 500,
      decoration: BoxDecoration(
        color: Color.fromARGB(255, 251, 231, 233),
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFC58189).withOpacity(1),
          ),
        ],
      ),
      child: TextFormField(
        cursorColor: Color(0xFFC58189),
        controller: con,
        obscureText: isPassword,
        decoration: InputDecoration(
          hintText: text,
          hintStyle: TextStyle(
            color: Color(0xFFC58189),
          ),
          prefixIcon: Icon(
            logo,
            color: Color(0xFFC58189),
          ),
          suffixIcon: suffixIcon,
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
