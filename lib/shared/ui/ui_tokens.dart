import 'package:flutter/material.dart';

class UiTokens {
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));
  static const r18 = BorderRadius.all(Radius.circular(18));
  static const r24 = BorderRadius.all(Radius.circular(24));

  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;

  static List<BoxShadow> softShadow({double opacity = 0.08}) => [
        BoxShadow(
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 10),
          color: Colors.black.withOpacity(opacity),
        ),
      ];
}
