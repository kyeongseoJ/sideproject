import 'dart:async';

import 'package:flutter/material.dart';
import 'package:novelty_app/api/mission_api.dart';
import 'package:novelty_app/api/personality_api.dart';
import 'package:novelty_app/api/world_api.dart';
import 'package:novelty_app/app_splash_screen.dart';
import 'package:novelty_app/novelty_theme.dart';
import 'package:novelty_app/personality/personality_bootstrap.dart';
import 'package:novelty_app/user/user_key_store.dart';
import 'package:novelty_app/world/world_spike_screen.dart';
import 'package:novelty_app/world/world_level_test_screen.dart';

const bool _worldTestMode = bool.fromEnvironment('WORLD_TEST');
const bool _worldSpikeMode = bool.fromEnvironment('WORLD_SPIKE');
void main() {
  runApp(const NoveltyApp());
}

class NoveltyApp extends StatefulWidget {
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
  State<NoveltyApp> createState() => _NoveltyAppState();
}

class _NoveltyAppState extends State<NoveltyApp> {
  late final Completer<void> _bootstrapReady;

  @override
  void initState() {
    super.initState();
    _bootstrapReady = Completer<void>();
  }

  void _markBootstrapReady() {
    if (!_bootstrapReady.isCompleted) _bootstrapReady.complete();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Novelty',
      debugShowCheckedModeBanner: false,
      theme: buildNoveltyTheme(),
      home: _worldTestMode
          ? const WorldLevelTestScreen()
          : _worldSpikeMode
          ? WorldSpikeScreen(onBack: () {})
          : NoveltySplashGate(
              readiness: _bootstrapReady.future,
              child: PersonalityBootstrapScreen(
                gateway: widget.personalityGateway,
                missionGateway: widget.missionGateway,
                userKeyStore: widget.userKeyStore,
                worldGateway: widget.worldGateway,
                onReady: _markBootstrapReady,
              ),
            ),
    );
  }
}
