import 'package:flutter/material.dart';

Widget CategoryCard(String text, String label) {
  return GestureDetector(
    onTap: () => {
      if(label == 'Kalung'){
        // Navigator.pushReplacement(co)
      }else if(label == 'Gelang'){

      }else if(label == 'Cincin'){

      }else if(label == 'Anting'){

      }
    },
    child: Container(
      width: 80,
      margin: EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFC58189).withOpacity(0.2),
            child: Text(
              text,
              style: TextStyle(fontSize: 24),
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF31394E)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
