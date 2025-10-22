import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Monitoring Slot Parkir',
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String broker = 'io.adafruit.com';
  final String username = 'fanol';
  final String key = const String.fromEnvironment('ADAFRUIT_KEY');
  final String topic = 'fanol/feeds/sensor-data';

  late MqttServerClient client;
  bool isConnected = false;
  List<int> parkingStatus = List.filled(6, 0);

  @override
  void initState() {
    super.initState();
    _connectToMQTT();
  }

  Future<void> _connectToMQTT() async {
    client = MqttServerClient(broker, '');
    client.port = 1883;
    client.logging(on: false);
    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;

    final MqttConnectMessage connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .authenticateAs(username, key)
        .startClean();
    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } catch (e) {
      print('Error: $e');
      client.disconnect();
    }

    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage message = c[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(message.payload.message);
      _updateParkingStatus(payload);
    });
  }

  void _onConnected() {
    setState(() {
      isConnected = true;
    });
    client.subscribe(topic, MqttQos.atMostOnce);
  }

  void _onDisconnected() {
    setState(() {
      isConnected = false;
    });
  }

  void _updateParkingStatus(String payload) {
    final List<int> updatedStatus =
        payload.split(',').map((e) => int.tryParse(e) ?? 0).toList();
    if (updatedStatus.length == 6) {
      setState(() {
        parkingStatus = updatedStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Monitoring Slot Parkir',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 1, 55, 109),
      ),
      body: Stack(
        children: [
          _buildBackground(),
          isConnected
              ? _buildParkingSlots()
              : const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      color: const Color.fromARGB(255, 1, 55, 109),
    );
  }

  Widget _buildParkingSlots() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: SingleChildScrollView( // Menghindari overflow
        child: Column(
          children: [
            GridView.builder(
              shrinkWrap: true, // Pastikan grid tidak melebihi ukuran
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.9, // Mengurangi rasio agar tidak overflow
              ),
              itemCount: parkingStatus.length,
              itemBuilder: (context, index) {
                final isOccupied = parkingStatus[index] == 1;
                final slotLabel = 'P${index + 1}';
                return _buildParkingSlotContainer(slotLabel, isOccupied);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParkingSlotContainer(String slotLabel, bool isOccupied) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 228, 244, 252),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding( // Menambahkan padding agar konten tidak berdesakan
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Mencegah overflow
          children: [
            _buildSlotLabel(slotLabel),
            _buildCarIcon(),
            const SizedBox(height: 8),
            _buildSlotStatusText(isOccupied),
            const SizedBox(height: 8),
            _buildCheckmarkAnimation(isOccupied),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotLabel(String slotLabel) {
    return Text(
      slotLabel,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.bold,
        fontSize: 18, // Mengurangi ukuran agar tidak overflow
        color: Color.fromARGB(255, 35, 34, 34),
      ),
    );
  }

  Widget _buildCarIcon() {
    return const Icon(
      Icons.directions_car_filled_rounded,
      color: Color.fromARGB(255, 35, 34, 34),
      size: 40, // Mengurangi ukuran agar lebih pas
    );
  }

  Widget _buildSlotStatusText(bool isOccupied) {
    return Text(
      isOccupied ? 'Slot Terisi' : 'Slot Kosong',
      style: TextStyle(
        fontFamily: 'Poppins',
        color: isOccupied
            ? const Color.fromARGB(255, 2, 106, 167)
            : const Color.fromARGB(255, 0, 0, 0),
        fontWeight: FontWeight.w600,
        fontSize: 14, // Mengurangi ukuran agar tidak overflow
      ),
    );
  }

  Widget _buildCheckmarkAnimation(bool isOccupied) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isOccupied
          ? const Icon(
              Icons.check_circle,
              key: ValueKey('check'),
              color: Colors.green,
              size: 28, // Mengurangi ukuran agar lebih pas
            )
          : const SizedBox.shrink(
              key: ValueKey('empty'),
            ),
    );
  }
}
