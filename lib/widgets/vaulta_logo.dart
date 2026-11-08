import 'package:flutter/material.dart';

/// The Vaulta "V" mark on its navy tile (looks right in both light and dark mode).
class VaultaLogo extends StatelessWidget {
  const VaultaLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.14),
        decoration: BoxDecoration(
          color: const Color(0xFF2A3747),
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Image.asset('assets/images/vaulta_mark.png', fit: BoxFit.contain),
      );
}
