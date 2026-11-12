import 'dart:async';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'dart:math';
class DataPullTimer extends StatefulWidget {
  @override
  _DataPullTimerState createState() => _DataPullTimerState();
}

class _DataPullTimerState extends State<DataPullTimer> {
  late Timer _timer;
  int _endTime = 0;
  double _percentComplete = 0.0;

  @override
  void initState() {
    super.initState();
    _calculateNextPull();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _calculateNextPull() {
    DateTime now = DateTime.now();
    DateTime nextPull = now.add(Duration(minutes: (30 - now.minute % 30)));
    _endTime = nextPull.millisecondsSinceEpoch;
  }

void _startTimer() {
  _timer = Timer.periodic(Duration(seconds: 1), (timer) {
    setState(() {
      int now = DateTime.now().millisecondsSinceEpoch;
      int remaining = _endTime - now;
      int totalDuration = 1800000; // 30 mins. (check if correct..)

      _percentComplete = min(1.0, max(0.0, (totalDuration - remaining) / totalDuration));

      if (remaining <= 0) {
        _calculateNextPull();
      }
    });
  });
}

  String _formatTime(int milliseconds) {
    int totalSeconds = milliseconds ~/ 1000;
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return "$minutes minute(s) & $seconds seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: LinearPercentIndicator(
            lineHeight: 20.0,
            percent: _percentComplete,
            backgroundColor: Colors.grey,
            progressColor: Colors.blue,
            barRadius: const Radius.circular(10),
            animation: true,
            animateFromLastPercent: true,
            alignment: MainAxisAlignment.center,
            animationDuration: 1000,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 12),
          child: Text(
            'Time until next data pull: ${_formatTime(_endTime - DateTime.now().millisecondsSinceEpoch)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
