// ignore_for_file: avoid_classes_with_only_static_members

class Environment {
  static Uri signalingUrl =
      Uri.parse('wss://ayame-labo.shiguredo.app/signaling');

  static String roomId = 'yourname@ayame-labo-sample';

  static String? signalingKey = '';

  static String dataChannelLabel = 'dataChannel';
}
