import 'package:flutter/material.dart';

Future<bool> showConfirmDialog(BuildContext context, String message) async {
  return await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Onay'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('İptal'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Onayla'),
        ),
      ],
    ),
  ) ?? false;
}
