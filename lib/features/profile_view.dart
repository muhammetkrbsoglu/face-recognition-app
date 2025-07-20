import 'dart:io';

import 'package:akilli_kapi_guvenlik_sistemi/models/face_model.dart';
import 'package:flutter/material.dart';

class ProfileView extends StatelessWidget {
  // HATA DÜZELTMESİ: Beklenen model FaceModel olarak güncellendi.
  final FaceModel profile;

  const ProfileView({required this.profile, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(profile.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 80,
                backgroundImage: FileImage(File(profile.imagePath)),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileInfoRow('ID', profile.id.toString()),
                    _buildProfileInfoRow('İsim', profile.name),
                    _buildProfileInfoRow('Cinsiyet', profile.gender),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Embedding Vektörü:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    profile.embeddings.toString(),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
