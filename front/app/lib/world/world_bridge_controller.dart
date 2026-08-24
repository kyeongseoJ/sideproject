import 'dart:convert';

typedef WorldBridgeMessageCallback =
    void Function(Map<String, Object?> message);

class WorldBridgeController {
  Future<void> Function(String message)? _sender;
  final List<String> _pending = <String>[];

  Future<void> send(String type, [Map<String, Object?> payload = const {}]) {
    final message = jsonEncode(<String, Object?>{
      'version': 1,
      'type': type,
      'payload': payload,
    });
    final sender = _sender;
    if (sender == null) {
      _pending.add(message);
      return Future<void>.value();
    }
    return sender(message);
  }

  Future<void> attach(Future<void> Function(String message) sender) async {
    _sender = sender;
    final pending = List<String>.of(_pending);
    _pending.clear();
    for (final message in pending) {
      await sender(message);
    }
  }

  void detach() {
    _sender = null;
  }
}

Map<String, Object?>? decodeWorldBridgeMessage(String rawMessage) {
  final decoded = jsonDecode(rawMessage);
  if (decoded is! Map<String, Object?> ||
      decoded['version'] != 1 ||
      decoded['type'] is! String ||
      decoded['payload'] is! Map<String, Object?>) {
    return null;
  }
  return decoded;
}
