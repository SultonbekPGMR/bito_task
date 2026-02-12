import 'package:flutter/material.dart';

extension HttpStatusCode on int? {
  bool isSuccess() => this != null && this! >= 200 && this! < 300;
}

extension ContextExtensions on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;

  double get screenHeight => MediaQuery.of(this).size.height;

  EdgeInsets get padding => MediaQuery.of(this).padding;

  double get statusBarHeight => MediaQuery.of(this).padding.top;

  double get bottomInset => MediaQuery.of(this).padding.bottom;

  double get appBarHeight => kToolbarHeight;

  ThemeData get theme => Theme.of(this);

  ColorScheme get colorScheme => theme.colorScheme;

  TextTheme get textTheme => theme.textTheme;

  bool get isDarkMode => theme.brightness == Brightness.dark;
}

extension StringExtension on String {
  String toShortName() {
    List<String> parts = this.split(" "); // Split the full name

    if (parts.length < 3) return this; // Return original if not enough parts

    String lastName = parts[0][0].toUpperCase() +
        parts[0].substring(1).toLowerCase(); // Capitalized Last Name
    String firstInitial =
        parts[1][0].toUpperCase(); // First letter of First Name
    String middleInitial =
        parts[2][0].toUpperCase(); // First letter of Middle Name

    return "$lastName $firstInitial.$middleInitial.";
  }
}

extension TimeFormatter on int {
  String toHHmm() {
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(this * 1000);
    String hours = dateTime.hour.toString().padLeft(2, '0');
    String minutes = dateTime.minute.toString().padLeft(2, '0');
    return "$hours:$minutes";
  }
}
