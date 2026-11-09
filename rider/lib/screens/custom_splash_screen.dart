import 'package:flutter/material.dart';
import '../widgets/moving_vehicle_loader.dart';

class CustomSplashScreen extends StatelessWidget {
  final String text;
  
  const CustomSplashScreen({
    super.key,
    this.text = 'Loading...',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: MovingVehicleLoader(text: text),
      ),
    );
  }
}
