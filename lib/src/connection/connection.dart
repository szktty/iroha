import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import './../logger.dart';
import './error.dart';
import './message.dart';
import './options.dart';

abstract class AyameConnectionBase {
  AyameConnectionBase({
    required this.signalingUrl,
    required this.roomId,
    required this.options,
    this.debug = false,
    bool isRelay = false,
  }) {
    _pcConfig = <String, dynamic>{
      'iceServers': options.iceServers,
      'iceTransportPolicy': isRelay ? 'relay' : 'all',
    };
  }
  bool debug;
  String roomId;
  Uri signalingUrl;
  AyameConnectionOptions options;
  RTCIceConnectionState connectionState =
      RTCIceConnectionState.RTCIceConnectionStateNew;
  MediaStream? stream;
  MediaStream? remoteStream;
  dynamic authnMetadata;
  dynamic authzMetadata;

  void Function(AyameMetadataOption)? onOpen;
  void Function()? onConnect;
  void Function(Error?)? onDisconnect;
  void Function(MediaStream)? onAddStream;
  void Function()? onRemoveStream;
  void Function()? onBye;
  void Function(RTCDataChannel)? onDataChannel;

  late Map<String, dynamic> _pcConfig;
  RTCPeerConnection? _pc;
  List<RTCDataChannel> _dataChannels = [];
  WebSocket? _ws;
  bool _isOffer = false;
  bool _isExistUser = false;

  bool get _connectionExists => _pc != null && _ws != null;

  Future<void> _disconnect() async {
    for (final dataChan in _dataChannels) {
      await _closeDataChannel(dataChan);
    }
    await _closePeerConnection();
    await _closeWebSocket();
    authzMetadata = null;
    _isOffer = false;
    _isExistUser = false;
    _dataChannels = [];
  }

  Future<void> _callOnDisconnect({
    String? reason,
    Object? error,
  }) async {
    if (onDisconnect != null) {
      onDisconnect!(
        reason != null
            ? AyameConnectionError(
                reason: reason,
                error: error,
              )
            : null,
      );
    }
  }

  Future<void> _signaling() async {
    logger.info('try signaling');
    if (_ws != null) {
      throw AyameConnectionError(reason: 'WS-ALREADY-EXISTS');
    }

    logger.info('connect WebSocket');
    _ws = await WebSocket.connect(signalingUrl.toString());
    _ws!.listen(
      (dynamic event) async {
        logger.info('event => $event');
        if (event is String == false) {
          logger.info('event is not string ${event.runtimeType}');
          return;
        }

        try {
          final message = AyameMessage.fromJson(
            jsonDecode(event.toString()) as Map<String, dynamic>,
          );
          logger.info('received message => ${message.type}');
          if (message.type == null) {
            return;
          }
          switch (message.type!) {
            case AyameMessageType.ping:
              _sendWs(AyameMessage(type: AyameMessageType.pong));
              break;

            case AyameMessageType.bye:
              if (onBye != null) {
                onBye!();
              }
              break;

            case AyameMessageType.accept:
              authzMetadata = message.authzMetadata;
              if (message.iceServers?.isNotEmpty ?? false) {
                final iceServers =
                    message.iceServers!.map((e) => e.toJson()).toList();
                logger.info('iceServers => $iceServers');
                _pcConfig['iceServers'] = iceServers;
              }
              logger.info('isExistUser => ${message.isExistUser}');
              _isExistUser = message.isExistUser ?? false;
              await _createPeerConnection();
              if (_isExistUser) {
                await _sendOffer();
              }
              return;

            case AyameMessageType.reject:
              await _disconnect();
              await _callOnDisconnect(reason: message.reason ?? 'REJECTED');
              break;

            case AyameMessageType.offer:
              if (_pc?.signalingState ==
                  RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
                await _createPeerConnection();
              }
              if (message.sdp != null) {
                await _setOffer(message.sdp!);
              }
              break;

            case AyameMessageType.answer:
              if (message.sdp != null) {
                await _setAnswer(message.sdp!);
              }
              break;

            case AyameMessageType.candidate:
              logger.info('type: candidate => ${message.ice?.toJson()}');
              if (message.ice != null) {
                await _addIceCandidate(message.ice!);
              }
              break;

            case AyameMessageType.pong:
            case AyameMessageType.register:
              // 何もしない
              break;
          }
        } on Exception catch (error) {
          await _disconnect();
          await _callOnDisconnect(reason: 'SIGNALING-ERROR', error: error);
        }
      },
      onDone: () async {
        await _disconnect();
        await _callOnDisconnect(reason: 'WS-CLOSED');
      },
      onError: (Object error) async {
        await _disconnect();
        await _callOnDisconnect(reason: 'WS-CLOSED-WITH-ERROR', error: error);
      },
      cancelOnError: true,
    );

    final register = AyameMessage(
      type: AyameMessageType.register,
      roomId: roomId,
      clientId: options.cliendId,
      authnMetadata: authnMetadata,
      signalingKey: options.signalingKey,
    );
    _sendWs(register);
  }

  Future<void> _setOffer(String sdp) async {
    if (!_connectionExists) {
      return;
    }
    try {
      logger.info('set offer => $sdp');
      final rtcSdp = RTCSessionDescription(sdp, 'offer');
      await _pc!.setRemoteDescription(rtcSdp);
      await _createAnswer();
    } on Exception catch (error) {
      await _disconnect();
      await _callOnDisconnect(reason: 'SET-OFFER-ERROR', error: error);
    }
  }

  void _sendIceCandidate(RTCIceCandidate candidate) {
    _sendWs(
      AyameMessage(
        type: AyameMessageType.candidate,
        ice: IceCandidate.from(candidate),
      ),
    );
  }

  Future<void> _addIceCandidate(IceCandidate candidate) async {
    if (_connectionExists && candidate.candidate?.isNotEmpty == true) {
      logger.info('add ICE candidate => ${candidate.toJson()}');
      await _pc!.addCandidate(candidate.toNative());
    }
  }

  void _sendSdp(RTCSessionDescription sdp) {
    _sendWs(AyameMessage.fromSdp(sdp));
  }

  void _sendWs(AyameMessage message) {
    final data = message.toJson();
    logger.info('message => $data');
    _ws?.add(json.encode(data));
  }

  Future<void> _closeDataChannel(RTCDataChannel dataChannel) async {
    if (dataChannel.state == RTCDataChannelState.RTCDataChannelClosed) {
      return;
    }
    dataChannel.onDataChannelState = null;
    await dataChannel.close();
  }

  Future<void> _createPeerConnection() async {
    logger.info('create peer connection');
    final pc = await createPeerConnection(_pcConfig);

    // audio track
    final audioTrack = stream?.getAudioTracks().first;
    if (audioTrack != null && options.audio.enabled) {
      switch (options.audio.direction) {
        case AyameDirection.sendonly:
        case AyameDirection.sendrecv:
          await pc.addTrack(audioTrack, stream!);
          break;
        case AyameDirection.recvonly:
          await pc.addTransceiver(
            track: audioTrack,
            kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
          );
          break;
      }
    }

    // video track
    final videoTrack = stream?.getVideoTracks().first;
    switch (options.video.direction) {
      case AyameDirection.sendonly:
      case AyameDirection.sendrecv:
        if (videoTrack != null) {
          logger.info('add sender video track');
          await pc.addTrack(videoTrack, stream!);
        }
        break;
      case AyameDirection.recvonly:
        if (options.video.enabled && videoTrack != null) {
          await pc.addTransceiver(
            track: videoTrack,
            kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
            init:
                RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
          );
        }
        break;
    }

    _pc = pc
      ..onAddTrack = (stream, track) {
        logger.info('added track => $track');
        remoteStream = stream;
        if (onAddStream != null) {
          onAddStream!(stream);
        }
      }
      ..onAddStream = (stream) {
        logger.info('added stream => $stream');
        remoteStream = stream;
        if (onAddStream != null) {
          onAddStream!(stream);
        }
      }
      ..onIceCandidate = (candidate) {
        logger.info('candidate => ${candidate.candidate}');
        if (candidate.candidate != null) {
          _sendIceCandidate(candidate);
        } else {
          logger.info('empty ICE candidate');
        }
      }
      ..onIceConnectionState = (state) async {
        logger.info('ICE connection state changed => $state');
        if (pc.iceConnectionState != null &&
            connectionState != pc.iceConnectionState) {
          connectionState = pc.iceConnectionState!;
          switch (connectionState) {
            case RTCIceConnectionState.RTCIceConnectionStateConnected:
              _isOffer = false;
              if (onConnect != null) {
                onConnect!();
              }
              break;
            case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
            case RTCIceConnectionState.RTCIceConnectionStateFailed:
              await _disconnect();
              if (onDisconnect != null) {
                onDisconnect!(
                  AyameConnectionError(reason: 'ICE-CONNECTION-STATE-FAILED'),
                );
              }
              break;
            case RTCIceConnectionState.RTCIceConnectionStateNew:
            case RTCIceConnectionState.RTCIceConnectionStateChecking:
            case RTCIceConnectionState.RTCIceConnectionStateCompleted:
            case RTCIceConnectionState.RTCIceConnectionStateCount:
            case RTCIceConnectionState.RTCIceConnectionStateClosed:
              // 何もしない
              break;
          }
        }
      }
      ..onSignalingState = (state) {
        logger.info('signaling state changed => $state');
      }
      ..onDataChannel = _onDataChannel;

    if (_pc != null) {
      if (onOpen != null) {
        logger.info('onOpen');
        onOpen!(AyameMetadataOption(authzMetadata: authzMetadata));
      }
    }
  }

  void _onDataChannel(RTCDataChannel channel) {
    logger.info('onDataChannel');
    if (_pc == null) {
      return;
    }

    if (channel.label == null || channel.label!.isEmpty) {
      return;
    }

    channel
      ..onDataChannelState = (state) {
        logger.info('data channel state changed => $state');
      }
      ..onMessage = (message) {
        logger.info('data channel received message => $message');
      };

    if (_findDataChannel(channel.label!) == null) {
      _dataChannels.add(channel);
    } else {
      _dataChannels = _dataChannels.map((e) {
        if (e.label == channel.label) {
          return channel;
        } else {
          return e;
        }
      }).toList(growable: true);
    }

    if (onDataChannel != null) {
      onDataChannel!(channel);
    }
  }

  RTCDataChannel? _findDataChannel(String label) {
    for (final chan in _dataChannels) {
      if (chan.label == label) {
        return chan;
      }
    }
    return null;
  }

  Future<RTCDataChannel?> _createDataChannel({
    required String label,
    RTCDataChannelInit? options,
  }) async {
    if (_pc == null) {
      throw AyameConnectionError(reason: 'peer connection does not ready');
    }
    if (_isOffer) {
      throw AyameConnectionError(reason: 'peer connection has local offer');
    }

    var dataChannel = _findDataChannel(label);
    if (dataChannel != null) {
      throw AyameConnectionError(reason: 'data channel already exists');
    }

    if (_isExistUser) {
      dataChannel =
          await _pc!.createDataChannel(label, options ?? RTCDataChannelInit())
            ..onDataChannelState = (state) {
              switch (state) {
                case RTCDataChannelState.RTCDataChannelClosed:
                  logger.info('DataChannel closed');
                  _dataChannels.removeWhere((e) => e.label == label);
                  break;
                case RTCDataChannelState.RTCDataChannelOpen:
                  logger.info('DataChannel opened');
                  break;
                case RTCDataChannelState.RTCDataChannelConnecting:
                  logger.info('DataChannel connecting');
                  break;
                case RTCDataChannelState.RTCDataChannelClosing:
                  logger.info('DataChannel closing');
                  break;
              }
            }
            ..onMessage = (message) {
              logger.info('DataChannel received message => $message');
            };
      _dataChannels.add(dataChannel);
      logger.info('DataChannel created => $label');
      return dataChannel;
    } else {
      logger.info('user does not exist');
      return null;
    }
  }

  Future<void> _sendOffer() async {
    if (!_connectionExists) {
      return;
    }

    final constraints = <String, dynamic>{
      'offerToReceiveAudio': options.audio.enabled &&
          options.audio.direction != AyameDirection.sendonly,
      'offerToReceiveVideo': options.video.enabled &&
          options.video.direction != AyameDirection.sendonly,
    };
    logger.info('offer constraints => $constraints');
    final offer = await _pc!.createOffer(constraints);

    /*
    if (offer.sdp != null && options.video.codec != null) {
      final codecs = [
        AyameVideoCodecOption.vp8,
        AyameVideoCodecOption.vp9,
        AyameVideoCodecOption.h264,
      ];
      for (final codec in codecs) {
        if (options.video.codec == codec) {
          offer.sdp = _removeCodecFromSdp(offer.sdp!, codec);
        }
      }
    }
     */

    logger.info('create offer sdp => ${offer.sdp}');
    await _pc!.setLocalDescription(offer);
    final localSdp = await _pc!.getLocalDescription();
    if (localSdp != null) {
      _sendSdp(localSdp);
    }
    _isOffer = true;
  }

  Future<void> _createAnswer() async {
    if (!_connectionExists) {
      return;
    }

    try {
      final answer = await _pc!.createAnswer();
      logger.info('create answer sdp => ${answer.sdp}');
      await _pc!.setLocalDescription(answer);
      final localSdp = await _pc!.getLocalDescription();
      if (localSdp != null) {
        _sendSdp(localSdp);
      }
    } on Exception catch (error) {
      await _disconnect();
      await _callOnDisconnect(reason: 'CREATE-ANSWER-ERROR', error: error);
    }
  }

  Future<void> _setAnswer(String sdp) async {
    if (!_connectionExists) {
      return;
    }

    final answer = RTCSessionDescription(sdp, 'answer');
    await _pc!.setRemoteDescription(answer);
    logger.info('set answer sdp => $sdp');
  }

  Future<void> _closePeerConnection() async {
    if (_pc == null) {
      return;
    }
    if (_pc!.signalingState == RTCSignalingState.RTCSignalingStateClosed) {
      _pc = null;
      return;
    }

    _pc!.onIceConnectionState = null;
    await _pc!.close();
    _pc = null;
  }

  Future<void> _closeWebSocket() async {
    if (_ws == null) {
      return;
    }
    if (_ws != null && _ws!.readyState == 3) {
      _ws = null;
      return;
    }

    await _ws!.close();
    _ws = null;
  }
}

class AyameConnection extends AyameConnectionBase {
  AyameConnection({
    required super.signalingUrl,
    required super.roomId,
    required super.options,
  });

  Future<void> connect({
    MediaStream? stream,
    AyameMetadataOption? metadataOption,
  }) async {
    logger.info('try connecting');
    if (_connectionExists) {
      logger.info('connection already exists');
      throw AyameConnectionError(reason: 'connection already exists');
    }

    this.stream = stream;
    if (metadataOption != null) {
      authnMetadata = metadataOption.authnMetadata;
    }
    await _signaling();
  }

  Future<void> disconnect() async {
    await _ws?.close();
    _ws = null;
  }

  RTCDataChannel? findDataChannel(String label) => _findDataChannel(label);

  Future<RTCDataChannel?> createDataChannel({
    required String label,
    RTCDataChannelInit? options,
  }) async =>
      _createDataChannel(label: label, options: options);

  Future<bool> removeDataChannel(String label) async {
    logger.info('remove data channel => $label');
    final channel = _findDataChannel(label);
    if (channel != null &&
        channel.state == RTCDataChannelState.RTCDataChannelOpen) {
      await _closeDataChannel(channel);
      return true;
    } else {
      return false;
    }
  }
}
