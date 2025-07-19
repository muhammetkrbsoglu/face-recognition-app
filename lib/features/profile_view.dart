import 'package:flutter/material.dart';
import '../models/user_profile.dart';

class ProfileView extends StatelessWidget {
  final UserProfile profile;
  const ProfileView({required this.profile, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: AssetImage(profile.imagePath),
            ),
            const SizedBox(height: 16),
            Text(profile.name, style: const TextStyle(fontSize: 22)),
            Text('Rol: ${profile.role}', style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
