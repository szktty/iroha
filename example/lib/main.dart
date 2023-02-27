import 'package:example/environment.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:iroha/iroha.dart';
import 'package:simple_logger/simple_logger.dart';

SimpleLogger _logger = SimpleLogger();

void main() async {
  Ayame.setLogLevel(Level.ALL, includeCallerInfo: true);

  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Iroha Demo',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
      ),
      home: const MyHomePage(title: 'Iroha Demo'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late AyameConnection _conn;
  bool _connected = false;

  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _renderersInited = false;
  int _navigationIndex = 0;
  List<RTCVideoRenderer> get _renderers => [_localRenderer, _remoteRenderer];

  String _message = '⭐';
  final _receivedMessages = List<String>.empty(growable: true);

  _MyHomePageState() {
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    if (!_renderersInited) {
      for (final renderer in _renderers) {
        await renderer.initialize();
      }
      _logger.info('renderers initialized');
      _renderersInited = true;
    }
  }

  Future<void> _disposeRenderers() async {
    if (_renderersInited) {
      _logger.info('dispose renderers');
      for (final renderer in _renderers) {
        if (renderer.textureId != null) {
          renderer.srcObject = null;
        }
        await renderer.dispose();
      }
    }
    _renderersInited = false;
  }

  @override
  void dispose() {
    super.dispose();
    _disposeRenderers();
  }

  Future<void> _connect() async {
    // デバイスの設定
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

    final conn = Ayame.connection(
      signalingUrl: Environment.signalingUrl,
      roomId: Environment.roomId,
      options: Ayame.defaultOptions()..signalingKey = Environment.signalingKey,
    )
      ..onOpen = (option) async {
        _logger.info('opened connection');
        final dataChannel =
            await _conn.createDataChannel(label: Environment.dataChannelLabel);
        if (dataChannel != null) {
          _logger.info('created data channel');
          dataChannel.onMessage = _onMessage;
        }
        setState(() {
          _connected = true;
        });
      }
      ..onDisconnect = (error) async {
        _logger.info('disconnect => $error');
        setState(() {
          _connected = false;
        });
      }
      ..onAddStream = (stream) async {
        _logger.info('added remote stream => $stream');
        _remoteRenderer.srcObject = stream;
        setState(() {});
      }
      ..onDataChannel = (channel) {
        _logger.info('opened data channel => ${channel.label}');
        channel.onMessage = _onMessage;
      };

    // metadata サンプル
    final metadataOption = AyameMetadataOption(
      authnMetadata: <String, dynamic>{},
    );

    // 接続
    await conn.connect(stream: stream, metadataOption: metadataOption);

    setState(() {
      _conn = conn;
      _logger.info('renderer inited => $_renderersInited');
      _localRenderer.srcObject = stream;
    });
  }

  Future<void> _disconnect() async {
    await _conn.disconnect();
    setState(() {
      _connected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: _navigationView(),
          ),
          _connectButton(),
        ],
      ),
      bottomNavigationBar: _bottomNavigationBar(),
    );
  }

  Widget _navigationView() {
    switch (_navigationIndex) {
      case 0:
        return _videoChatView();
      default:
        return _textChatView();
    }
  }

  Widget _videoChatView() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 16),
            _remoteVideoView(),
            const SizedBox(height: 16),
            _localVideoView(),
          ],
        ),
      );

  Widget _localVideoView() => Container(
        margin: EdgeInsets.zero,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height / 3 - 50,
        decoration: const BoxDecoration(color: Colors.black54),
        child: RTCVideoView(_localRenderer, mirror: true),
      );

  Widget _remoteVideoView() => Container(
        margin: EdgeInsets.zero,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height / 3 - 50,
        decoration: const BoxDecoration(color: Colors.black54),
        child: RTCVideoView(_remoteRenderer),
      );

  Widget _textChatView() => Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _receivedMessages.length,
                      itemBuilder: (content, index) {
                        final message = _receivedMessages[index];
                        return IntrinsicHeight(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 16),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  width: 0.3,
                                  color: Colors.lightGreen,
                                ),
                              ),
                            ),
                            child: Text(message),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: TextField(
                      controller: TextEditingController(text: _message),
                      onChanged: (value) {
                        setState(() {
                          _message = value;
                        });
                      },
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _connected ? _sendMessage : null,
                  child: const Text('送信'),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _connectButton() => Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                fixedSize: const Size(70, 70),
                shape: const CircleBorder(),
                backgroundColor:
                    _connected ? Colors.deepOrange : Colors.lightGreen),
            onPressed: _connected ? _disconnect : _connect,
            child: ClipOval(
              child: Icon(
                _connected ? Icons.stop : Icons.play_arrow,
                size: 55,
              ),
            ),
          ),
        ),
      );

  Widget _bottomNavigationBar() => BottomNavigationBar(
        currentIndex: _navigationIndex,
        onTap: (index) {
          setState(() {
            _navigationIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.video_camera_front),
            label: 'ビデオチャット',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'テキストチャット',
          ),
        ],
      );

  Future<void> _sendMessage() async {
    if (!_connected || _message.isEmpty) {
      return;
    }

    final dataChannel = _conn.findDataChannel(Environment.dataChannelLabel);
    if (dataChannel == null) {
      _logger.info('datachannel not found => ${Environment.dataChannelLabel}');
      return;
    }
    _logger.info('send message => $_message');
    final message = RTCDataChannelMessage(_message);
    await dataChannel.send(message);
  }

  dynamic _onMessage(RTCDataChannelMessage message) {
    _logger.info('received message => $message');
    setState(() {
      _receivedMessages.add(message.text);
    });
  }
}
