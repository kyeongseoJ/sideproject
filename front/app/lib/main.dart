import 'package:flutter/material.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/personality/personality_bootstrap.dart';
import 'package:novelty_app/user/user_key_store.dart';

void main() {
  runApp(const NoveltyApp());
}

class NoveltyApp extends StatelessWidget {
  const NoveltyApp({super.key, this.personalityGateway, this.userKeyStore});

  final PersonalityGateway? personalityGateway;
  final UserKeyStore? userKeyStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Novelty',
      debugShowCheckedModeBanner: false,
      theme: buildNoveltyTheme(),
      home: PersonalityBootstrapScreen(
        gateway: personalityGateway,
        userKeyStore: userKeyStore,
      ),
    );
  }
}
