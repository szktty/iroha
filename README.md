# Iroha - Flutter 用 Ayame ライブラリ

Iroha は WebRTC Signaling Server Ayame  の Flutter 用ライブラリです。
[Ayame Web SDK](https://github.com/OpenAyame/ayame-web-sdk) とほぼ同じ API を実装しています。

WebRTC の機能は [flutter-webrtc](https://pub.dev/packages/flutter_webrtc) を利用しています。

## システム条件

- Flutter 3.3 以降

## ライセンス

Apache License 2.0

## インストール

次のコマンドを実行してください。

```
flutter pub add iroha
```

## 使い方

```dart
import 'package:iroha/iroha.dart';

void main() async {
  // カメラの映像を取得する (flutter-webrtc)
  final mediaConstraints = <String, dynamic>{
    'audio': true,
    'video': {
      'mandatory': {
        'minWidth': '640',
        'minHeight': '480',
        'minFrameRate': '30',
      },
      'facingMode': 'user',
      'optional': <dynamic>[],
    },
  }; 
  final stream = await mediaDevices.getUserMedia(mediaConstraints);

  // 接続設定
  final conn = Ayame.connection(
    signalingUrl: 'wss://ayame-labo.shiguredo.app/signaling',
    roomId: '<yourname>@ayame-labo-sample',
    options: Ayame.defaultOptions()..signalingKey = '...',
  )
  // 接続確立時のコールバック
  ..onOpen = (option) async {
    // DataChannel 作成
    final dataChannel =
      await _conn.createDataChannel(label: 'label');
    dataChannel?.onMessage = (message) {};
  }
  // 切断時のコールバック
  ..onDisconnect = (error) {}
  // リモートストリーム追加時のコールバック
  ..onAddStream = (stream) {}
  // DataChannel 作成時のコールバック
  ..onDataChannel = (channel) {};

  // メタデータ
  final metadataOption = AyameMetadataOption(
    authnMetadata: <String, dynamic>{},
  );

  // 接続
  await conn.connect(stream: stream, metadataOption: metadataOption);
}
 ```

## サンプルアプリ

`example/` にあります。
`lib/environment.local.dart` または `lib/environment.ayame-demo.dart` をコピーして `lib/environment.dart` を作成し、サーバー URL などの接続設定を記述してください。

- 「ビデオチャット」はカメラの映像とリモートの映像の送受信を行います
- 「テキストチャット」は DataChannel を利用してテキストの送受信を行います
 
## 未実装の機能

以下の機能は未実装です。

- 映像コーデックを指定するオプション
    - flutter-webrtc には ``RTCRtpTransceiver.setCodecPreferences()`` が実装されていないのでコーデックを指定できません
