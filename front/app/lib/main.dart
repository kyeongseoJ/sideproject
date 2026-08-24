import 'package:flutter/material.dart';
import 'package:novelty_app/api/mission_api.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/api/world_api.dart';
import 'package:novelty_app/app_splash_screen.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/personality/personality_bootstrap.dart';
import 'package:novelty_app/user/user_key_store.dart';
import 'package:novelty_app/world/world_spike_screen.dart';

const bool _worldSpikeMode = bool.fromEnvironment('WORLD_SPIKE');
void main() {
  runApp(const NoveltyApp());
}

class NoveltyApp extends StatelessWidget {
  const NoveltyApp({
    super.key,
    this.personalityGateway,
    this.missionGateway,
    this.userKeyStore,
    this.worldGateway,
  });

  final PersonalityGateway? personalityGateway;
  final MissionGateway? missionGateway;
  final UserKeyStore? userKeyStore;
  final WorldGateway? worldGateway;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Novelty',
      debugShowCheckedModeBanner: false,
      theme: buildNoveltyTheme(),
      home: _worldSpikeMode
          ? WorldSpikeScreen(onBack: () {})
          : NoveltySplashGate(
              child: PersonalityBootstrapScreen(
                gateway: personalityGateway,
                missionGateway: missionGateway,
                userKeyStore: userKeyStore,
                worldGateway: worldGateway,
              ),
            ),
    );
  }
}
