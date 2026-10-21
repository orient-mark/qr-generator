import 'package:flutter/material.dart';

const ink = Color(0xFF192F2C);
const green = Color(0xFF176B52);
const muted = Color(0xFF75817D);
const line = Color(0xFFE3E9E5);
const canvasColor = Color(0xFFF4F6F2);

ThemeData createTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Segoe UI',
  scaffoldBackgroundColor: canvasColor,
  colorScheme: ColorScheme.fromSeed(seedColor: green, surface: Colors.white),
  textTheme: ThemeData.light().textTheme.apply(
    bodyColor: ink,
    displayColor: ink,
    fontFamily: 'Segoe UI',
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: green,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ink,
      side: const BorderSide(color: line),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  checkboxTheme: CheckboxThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  ),
);
