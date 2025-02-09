import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Assisted Intuition',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AnimatedHomePage(),
    );
  }
}

class AnimatedHomePage extends StatefulWidget {
  const AnimatedHomePage({super.key});

  @override
  State<AnimatedHomePage> createState() => _AnimatedHomePageState();
}

class _AnimatedHomePageState extends State<AnimatedHomePage> {
  String animatedText = "";
  bool showConnectButton = false;
  bool showDeviceList = false;
  final String fullText = "Assisted Intuition";
  int charIndex = 0;
  List<String> mockDevices = ["Biosensor A", "Biosensor B", "Biosensor C"];

  @override
  void initState() {
    super.initState();
    _startTypewriterAnimation();
  }

  void _startTypewriterAnimation() {
    Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (charIndex < fullText.length) {
        setState(() {
          animatedText += fullText[charIndex];
        });
        charIndex++;
      } else {
        timer.cancel();
        _fadeOutTextAndShowButton();
      }
    });
  }

  void _fadeOutTextAndShowButton() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      showConnectButton = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: showConnectButton || showDeviceList
          ? AppBar(
              title: const Text('Assisted Intuition'),
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            )
          : null,
      body: Center(
        child: showDeviceList
            ? ListView.builder(
                itemCount: mockDevices.length,
                itemBuilder: (context, index) {
                  final device = mockDevices[index];
                  return ListTile(
                    title: Text(
                      device,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GraphScreen(deviceName: device),
                        ),
                      );
                    },
                  );
                },
              )
            : showConnectButton
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    onPressed: () {
                      setState(() {
                        showDeviceList = true;
                      });
                    },
                    child: const Text('Connect'),
                  )
                : Text(
                    animatedText,
                    style: const TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
      ),
    );
  }
}

class GraphScreen extends StatefulWidget {
  final String deviceName;
  const GraphScreen({super.key, required this.deviceName});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  final _channel = WebSocketChannel.connect(
    Uri.parse('ws://127.0.0.1:8000'),
  );

  double xPos = 0.0, yPos = 0.0, zPos = 0.0;
  Color orbColor = Colors.red;
  final List<ColorEntry> colorHistory = [];
  final int historyDuration = 600; // in seconds (10 minutes)

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _channel.stream.listen((message) {
      final data = message.split(',');
      final x = double.parse(data[0]);
      final y = double.parse(data[1]);
      final z = double.parse(data[2]);

      setState(() {
        xPos = x;
        yPos = y;
        zPos = z;

        // Calculate HSL values based on x, y, and z
        final hue = (x - y) * 360;
        final saturation = z;
        final lightness = (x + y) / 2;

        orbColor = HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
        final now = DateTime.now();
        colorHistory.add(ColorEntry(orbColor, now));

        // Remove old colors from history
        colorHistory.removeWhere((entry) {
          return now.difference(entry.timestamp).inSeconds > historyDuration;
        });
      });

      _animationController.forward(from: 0.0);
    });
  }

  @override
  void dispose() {
    _channel.sink.close();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connected to ${widget.deviceName}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // Color bar on the left
          ColorBar(colorHistory: colorHistory, historyDuration: historyDuration),
          // Orb in the center
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: OrbPainter(xPos, yPos, zPos, orbColor),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrbPainter extends CustomPainter {
  final double xPos, yPos, zPos;
  final Color orbColor;

  OrbPainter(this.xPos, this.yPos, this.zPos, this.orbColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [orbColor.withOpacity(0.5), orbColor],
        stops: [0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: 100));
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 100, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ColorEntry {
  final Color color;
  final DateTime timestamp;

  ColorEntry(this.color, this.timestamp);
}

class ColorBar extends StatelessWidget {
  final List<ColorEntry> colorHistory;
  final int historyDuration;

  ColorBar({required this.colorHistory, required this.historyDuration});

  @override
  Widget build(BuildContext context) {
    // Calculate the percentage of each color in the history
    final colorCounts = <Color, int>{};
    for (var entry in colorHistory) {
      colorCounts[entry.color] = (colorCounts[entry.color] ?? 0) + 1;
    }

    final totalCount = colorHistory.length;
    final colorPercentages = colorCounts.map((color, count) {
      return MapEntry(color, count / totalCount);
    });

    return Container(
      width: 50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: colorPercentages.entries.map((entry) {
          return Expanded(
            flex: (entry.value * 100).toInt(),
            child: Container(
              color: entry.key,
            ),
          );
        }).toList(),
      ),
    );
  }
}