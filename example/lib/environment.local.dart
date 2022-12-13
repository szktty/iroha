// ignore_for_file: avoid_classes_with_only_static_members

class Environment {
  static Uri signalingUrl = Uri.parse('ws://127.0.0.1:3000/signaling');

  static String roomId = 'ayame-web-sdk-sample';

  static String? signalingKey;

  static String dataChannelLabel = 'dataChannel';
}
