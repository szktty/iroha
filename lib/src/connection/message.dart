import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:json_annotation/json_annotation.dart';

// flutter pub run build_runner build
part 'message.g.dart';

enum AyameMessageType {
  accept,
  answer,
  bye,
  candidate,
  offer,
  ping,
  pong,
  register,
  reject,
}

@JsonSerializable()
class AyameMessage {
  AyameMessage({
    this.allowed,
    this.authnMetadata,
    this.authzMetadata,
    this.ayameClient,
    this.clientId,
    this.environment,
    this.ice,
    this.iceServers,
    this.isExistClient,
    this.isExistUser,
    this.libwebrtc,
    this.reason,
    this.roomId,
    this.sdp,
    this.signalingKey,
    this.type,
  });

  factory AyameMessage.fromSdp(RTCSessionDescription sdp) => AyameMessage(
      type: AyameMessageType.values.firstWhere((e) => e.name == sdp.type!),
      sdp: sdp.sdp);

  factory AyameMessage.fromJson(Map<String, dynamic> json) =>
      _$AyameMessageFromJson(json);

  final bool? allowed;
  final dynamic authnMetadata;
  final dynamic authzMetadata;
  final String? ayameClient;
  final String? clientId;
  final String? environment;
  final IceCandidate? ice;
  final List<IceServer>? iceServers;
  final bool? isExistClient;
  final bool? isExistUser;
  final String? libwebrtc;
  final String? roomId;
  final String? reason;
  final String? sdp;
  final String? signalingKey;
  final AyameMessageType? type;

  Map<String, dynamic> toJson() => _$AyameMessageToJson(this);
}

@JsonSerializable()
class IceCandidate {
  IceCandidate({
    this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
    this.usernameFragment,
  });

  factory IceCandidate.from(RTCIceCandidate candidate) => IceCandidate(
        candidate: candidate.candidate,
        sdpMid: candidate.sdpMid,
        sdpMLineIndex: candidate.sdpMLineIndex,
      );

  factory IceCandidate.fromJson(Map<String, dynamic> json) =>
      _$IceCandidateFromJson(json);

  final String? candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
  final String? usernameFragment;

  Map<String, dynamic> toJson() => _$IceCandidateToJson(this);

  RTCIceCandidate toNative() =>
      RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
}

@JsonSerializable()
class IceServer {
  IceServer({this.urls, this.username, this.credential});

  factory IceServer.fromJson(Map<String, dynamic> json) =>
      _$IceServerFromJson(json);

  List<String>? urls;
  String? username;
  String? credential;

  Map<String, dynamic> toJson() => _$IceServerToJson(this);
}
