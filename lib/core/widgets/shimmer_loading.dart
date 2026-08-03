import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  REUSABLE SHIMMER WRAPPER
// ═══════════════════════════════════════════════════════════════
class AppShimmer extends StatefulWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(-2.0 + _controller.value * 4.0, -1.0),
                end: Alignment(0.0 + _controller.value * 4.0, 1.0),
                colors: const [
                  Color(0xFFE2E8F0), // Slate 200 base
                  Color(0xFFF8FAFC), // Slate 50 dynamic shine
                  Color(0xFFE2E8F0), // Slate 200 base
                ],
                stops: const [0.3, 0.5, 0.7],
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SKELETON SHAPE GENERATORS
// ═══════════════════════════════════════════════════════════════

class AppSkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const AppSkeletonLine({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class AppSkeletonCircle extends StatelessWidget {
  final double size;

  const AppSkeletonCircle({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

class AppSkeletonSquircle extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const AppSkeletonSquircle({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PRE-CONFIGURED REUSABLE SKELETON CARDS FOR MENUS
// ═══════════════════════════════════════════════════════════════

/// A modern card skeleton mimicking a list item (used in Jenis, Inventaris, Users, Jadwal, Realisasi)
class AppSkeletonListCard extends StatelessWidget {
  const AppSkeletonListCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          // Left Icon box placeholder
          AppSkeletonSquircle(width: 44, height: 44, borderRadius: 12),
          SizedBox(width: 14),
          // Center title / subtitle placeholder
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonLine(width: 140, height: 16, borderRadius: 4),
                SizedBox(height: 8),
                AppSkeletonLine(width: 80, height: 12, borderRadius: 3),
              ],
            ),
          ),
          SizedBox(width: 14),
          // Right pill tag or action placeholder
          AppSkeletonSquircle(width: 60, height: 24, borderRadius: 8),
        ],
      ),
    );
  }
}

/// A modern folder skeleton mimicking a checklist or hierarchical group
class AppSkeletonFolderCard extends StatelessWidget {
  const AppSkeletonFolderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              AppSkeletonSquircle(width: 32, height: 32, borderRadius: 8),
              SizedBox(width: 12),
              AppSkeletonLine(width: 130, height: 16),
              Spacer(),
              AppSkeletonSquircle(width: 50, height: 24, borderRadius: 8),
              SizedBox(width: 10),
              AppSkeletonSquircle(width: 65, height: 26, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(2, (index) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                AppSkeletonSquircle(width: 30, height: 30, borderRadius: 8),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeletonLine(width: double.infinity, height: 14),
                      SizedBox(height: 6),
                      AppSkeletonLine(width: 150, height: 10),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Row(
                  children: [
                    AppSkeletonCircle(size: 24),
                    SizedBox(width: 8),
                    AppSkeletonCircle(size: 24),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
