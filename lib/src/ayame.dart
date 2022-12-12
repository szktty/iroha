import 'package:random_string/random_string.dart';
import 'package:simple_logger/simple_logger.dart';

import './connection/connection.dart';
import './connection/options.dart';
import 'logger.dart';

// ignore_for_file: avoid_classes_with_only_static_members
// ignore_for_file: avoid_redundant_argument_values

class Ayame {
  static void setLogLevel(Level level, {bool includeCallerInfo = false}) {
    logger.setLevel(level, includeCallerInfo: includeCallerInfo);
  }

  static AyameConnectionOptions defaultOptions() => AyameConnectionOptions(
        audio: AyameAudioOption(
          direction: AyameDirection.sendrecv,
          enabled: true,
        ),
        video: AyameVideoOption(
          direction: AyameDirection.sendrecv,
          enabled: true,
        ),
        cliendId: randomNumeric(17),
      );

  static AyameConnection connection({
    required Uri signalingUrl,
    required String roomId,
    required AyameConnectionOptions options,
  }) =>
      AyameConnection(
          signalingUrl: signalingUrl, roomId: roomId, options: options);
}
