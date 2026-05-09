import 'package:flutter/material.dart';

class SwiftCallLogoIcon extends StatelessWidget {
  final double size;

  const SwiftCallLogoIcon({super.key, this.size = 46.0});

  @override
  Widget build(BuildContext context) {
    final badgeSize = size * 0.40;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Phone handset — centered, white
          Center(
            child: Icon(
              Icons.call_rounded,
              color: Colors.white,
              size: size * 0.60,
            ),
          ),
          // Gold lightning-bolt badge — top-right corner
          Positioned(
            right: size * 0.02,
            top: size * 0.02,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD060),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD060).withValues(alpha: 0.50),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.bolt,
                color: Colors.white,
                size: badgeSize * 0.65,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
