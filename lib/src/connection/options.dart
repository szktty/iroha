import 'message.dart';

enum AyameDirection {
  sendonly,
  recvonly,
  sendrecv,
}

class AyameAudioOption {
  AyameAudioOption({
    required this.direction,
    this.enabled = true,
  });
  AyameDirection direction;
  bool enabled;
}

enum AyameVideoCodecOption {
  vp8,
  vp9,
  av1,
  h264,
  h265,
}

class AyameVideoOption {
  AyameVideoOption({
    required this.direction,
    this.codec,
    this.enabled = true,
  });
  AyameVideoCodecOption? codec;
  AyameDirection direction;
  bool enabled;
}

class AyameConnectionOptions {
  AyameConnectionOptions({
    required this.audio,
    required this.video,
    required this.cliendId,
  });

  AyameAudioOption audio;
  AyameVideoOption video;
  String cliendId;
  List<IceServer> iceServers = [];
  String? signalingKey;
}

class AyameMetadataOption {
  AyameMetadataOption({
    this.authnMetadata,
    this.authzMetadata,
  });
  dynamic authnMetadata;
  dynamic authzMetadata;
}
