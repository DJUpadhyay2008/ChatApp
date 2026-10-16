import 'package:flutter/material.dart';

class InitialsAvatar extends StatelessWidget {
  final String name;
  final double radius;
  final double? fontSize;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.radius = 22,
    this.fontSize,
  });

  String _getInitials(String input) {
    final parts = input.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _getColorForName(String input) {
    const colors = [
      Color(0xFF00A884),
      Color(0xFF2E7D32),
      Color(0xFF0288D1),
      Color(0xFF7B1FA2),
      Color(0xFFE64A19),
      Color(0xFF5D4037),
      Color(0xFF455A64),
      Color(0xFFC2185B),
    ];
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = input.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
    final bgColor = _getColorForName(name);

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize ?? (radius * 0.75),
        ),
      ),
    );
  }
}
