import 'dart:async';

import 'package:flutter/material.dart';

class CountdownTimer extends StatefulWidget {
  final DateTime expirationTime;

  const CountdownTimer(this.expirationTime, {Key? key}) : super(key: key);

  @override
  _CountdownTimerState createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Duration _timeLeft;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.expirationTime.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  void _updateTime() {
    setState(() {
      final now = DateTime.now();
      _timeLeft = widget.expirationTime.difference(now);
      if (_timeLeft.isNegative) {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft.isNegative) {
      return const Text(
        'Expired',
        style: TextStyle(color: Colors.red, fontSize: 14),
      );
    }

    final hours = _timeLeft.inHours;
    final minutes = _timeLeft.inMinutes % 60;
    final seconds = _timeLeft.inSeconds % 60;

    return Text(
      '$hours:$minutes:$seconds',
      style: const TextStyle(color: Colors.red, fontSize: 14),
    );
  }
}
