import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String getGreeting() {
  var now = DateTime.now()
      .toUtc()
      .subtract(const Duration(hours: 8)); // Adjust for PST
  var hour = now.hour;

  if (hour >= 6 && hour < 12) {
    return 'Good Morning';
  } else if (hour >= 12 && hour < 18) {
    return 'Good Afternoon';
  } else {
    return 'Good Evening';
  }
}

String getCurrentDate() {
  var now = DateTime.now();
  var formatter = DateFormat('MMM dd, yyyy');
  return formatter.format(now);
}
