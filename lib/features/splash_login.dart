import 'package:flutter/material.dart';

class SplashLogin extends StatelessWidget {
  const SplashLogin({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Giriş yapılıyor...'),
          ],
        ),
      ),
    );
  }
}
