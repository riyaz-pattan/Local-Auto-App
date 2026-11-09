import 'package:flutter/material.dart';

class MovingVehicleLoader extends StatefulWidget {
  final String text;
  final Color primaryColor;
  final Color backgroundColor;

  const MovingVehicleLoader({
    super.key,
    this.text = 'Loading...',
    this.primaryColor = const Color(0xFF111827), // deep dark color suitable for the app
    this.backgroundColor = Colors.white,
  });

  @override
  State<MovingVehicleLoader> createState() => _MovingVehicleLoaderState();
}

class _MovingVehicleLoaderState extends State<MovingVehicleLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _animation = Tween<double>(begin: -1.2, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );

    _bounceAnimation = Tween<double>(begin: 0.0, end: -4.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 150,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Road
              Positioned(
                bottom: 8,
                left: 10,
                right: 10,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              // Moving Vehicle
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Align(
                    alignment: Alignment(_animation.value, 0.0),
                    child: Transform.translate(
                      offset: Offset(
                          0,
                          _bounceAnimation.value *
                              (_controller.value > 0.5 ? -1 : 1)), // Bounce
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: widget.backgroundColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.primaryColor.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.electric_rickshaw,
                          color: widget.primaryColor,
                          size: 28,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.text,
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
