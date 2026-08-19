import 'package:flutter/material.dart';

void main() {
  runApp(const NoveltyApp());
}

class NoveltyApp extends StatelessWidget {
  const NoveltyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Novelty',
      home: Scaffold(
        body: Center(child: Text('Novelty')),
      ),
    );
  }
}
