// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AyameMessage _$AyameMessageFromJson(Map<String, dynamic> json) => AyameMessage(
      allowed: json['allowed'] as bool?,
      authnMetadata: json['authnMetadata'],
      authzMetadata: json['authzMetadata'],
      ayameClient: json['ayameClient'] as String?,
      clientId: json['clientId'] as String?,
      environment: json['environment'] as String?,
      ice: json['ice'] == null
          ? null
          : IceCandidate.fromJson(json['ice'] as Map<String, dynamic>),
      iceServers: (json['iceServers'] as List<dynamic>?)
          ?.map((e) => IceServer.fromJson(e as Map<String, dynamic>))
          .toList(),
      isExistClient: json['isExistClient'] as bool?,
      isExistUser: json['isExistUser'] as bool?,
      libwebrtc: json['libwebrtc'] as String?,
      reason: json['reason'] as String?,
      roomId: json['roomId'] as String?,
      sdp: json['sdp'] as String?,
      signalingKey: json['signalingKey'] as String?,
      type: $enumDecodeNullable(_$AyameMessageTypeEnumMap, json['type']),
    );

Map<String, dynamic> _$AyameMessageToJson(AyameMessage instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('allowed', instance.allowed);
  writeNotNull('authnMetadata', instance.authnMetadata);
  writeNotNull('authzMetadata', instance.authzMetadata);
  writeNotNull('ayameClient', instance.ayameClient);
  writeNotNull('clientId', instance.clientId);
  writeNotNull('environment', instance.environment);
  writeNotNull('ice', instance.ice?.toJson());
  writeNotNull(
      'iceServers', instance.iceServers?.map((e) => e.toJson()).toList());
  writeNotNull('isExistClient', instance.isExistClient);
  writeNotNull('isExistUser', instance.isExistUser);
  writeNotNull('libwebrtc', instance.libwebrtc);
  writeNotNull('roomId', instance.roomId);
  writeNotNull('reason', instance.reason);
  writeNotNull('sdp', instance.sdp);
  writeNotNull('signalingKey', instance.signalingKey);
  writeNotNull('type', _$AyameMessageTypeEnumMap[instance.type]);
  return val;
}

const _$AyameMessageTypeEnumMap = {
  AyameMessageType.accept: 'accept',
  AyameMessageType.answer: 'answer',
  AyameMessageType.bye: 'bye',
  AyameMessageType.candidate: 'candidate',
  AyameMessageType.offer: 'offer',
  AyameMessageType.ping: 'ping',
  AyameMessageType.pong: 'pong',
  AyameMessageType.register: 'register',
  AyameMessageType.reject: 'reject',
};

IceCandidate _$IceCandidateFromJson(Map<String, dynamic> json) => IceCandidate(
      candidate: json['candidate'] as String?,
      sdpMid: json['sdpMid'] as String?,
      sdpMLineIndex: json['sdpMLineIndex'] as int?,
      usernameFragment: json['usernameFragment'] as String?,
    );

Map<String, dynamic> _$IceCandidateToJson(IceCandidate instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('candidate', instance.candidate);
  writeNotNull('sdpMid', instance.sdpMid);
  writeNotNull('sdpMLineIndex', instance.sdpMLineIndex);
  writeNotNull('usernameFragment', instance.usernameFragment);
  return val;
}

IceServer _$IceServerFromJson(Map<String, dynamic> json) => IceServer(
      urls: (json['urls'] as List<dynamic>?)?.map((e) => e as String).toList(),
      username: json['username'] as String?,
      credential: json['credential'] as String?,
    );

Map<String, dynamic> _$IceServerToJson(IceServer instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('urls', instance.urls);
  writeNotNull('username', instance.username);
  writeNotNull('credential', instance.credential);
  return val;
}
