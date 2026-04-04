import 'dart:async';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Discovered Bluetooth thermal printer.
class PrinterDevice {
  final String id;
  final String name;
  final int rssi;

  const PrinterDevice({
    required this.id,
    required this.name,
    this.rssi = 0,
  });
}

/// Connection state exposed to the UI.
enum PrinterConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

/// Manages Bluetooth Low Energy (BLE) discovery, connection, and raw byte
/// transmission to ESC/POS thermal printers.
class PrinterService {
  static const String _lastPrinterKey = 'last_bt_printer_id';
  static const String _lastPrinterNameKey = 'last_bt_printer_name';

  // Common BLE SPP / printer service & characteristic UUIDs.
  static const String _printerServiceUuid =
      '000018f0-0000-1000-8000-00805f9b34fb';
  static const String _printerCharUuid =
      '00002af1-0000-1000-8000-00805f9b34fb';

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;

  PrinterConnectionState _state = PrinterConnectionState.disconnected;
  PrinterConnectionState get state => _state;

  final _stateController =
      StreamController<PrinterConnectionState>.broadcast();
  Stream<PrinterConnectionState> get stateStream => _stateController.stream;

  final _devicesController =
      StreamController<List<PrinterDevice>>.broadcast();
  Stream<List<PrinterDevice>> get devicesStream => _devicesController.stream;

  final List<PrinterDevice> _discoveredDevices = [];

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  /// Scan for nearby BLE printers. Results arrive via [devicesStream].
  /// Scanning stops automatically after [timeout].
  Future<void> scanForPrinters({Duration timeout = const Duration(seconds: 8)}) async {
    _discoveredDevices.clear();
    _setState(PrinterConnectionState.scanning);

    try {
      // Ensure Bluetooth is on.
      if (await FlutterBluePlus.adapterState.first !=
          BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
      }

      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: true,
      );

      FlutterBluePlus.scanResults.listen((results) {
        _discoveredDevices.clear();
        for (final r in results) {
          if (r.device.platformName.isNotEmpty) {
            _discoveredDevices.add(PrinterDevice(
              id: r.device.remoteId.str,
              name: r.device.platformName,
              rssi: r.rssi,
            ));
          }
        }
        _devicesController.add(List.unmodifiable(_discoveredDevices));
      });

      // Wait for the scan to complete.
      await Future<void>.delayed(timeout);
    } catch (e) {
      dev.log('PrinterService.scan error: $e');
      _setState(PrinterConnectionState.error);
    } finally {
      await FlutterBluePlus.stopScan();
      if (_state == PrinterConnectionState.scanning) {
        _setState(PrinterConnectionState.disconnected);
      }
    }
  }

  /// Stop any ongoing scan.
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  /// Connect to a printer by its Bluetooth remote ID.
  Future<bool> connect(String deviceId, {String? deviceName}) async {
    _setState(PrinterConnectionState.connecting);

    try {
      final device = BluetoothDevice.fromId(deviceId);
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 10));

      // Discover services and locate the writable characteristic.
      final services = await device.discoverServices();
      BluetoothCharacteristic? writeCh;

      for (final service in services) {
        for (final ch in service.characteristics) {
          if (ch.properties.write || ch.properties.writeWithoutResponse) {
            writeCh = ch;
            break;
          }
        }
        if (writeCh != null) break;
      }

      if (writeCh == null) {
        dev.log('PrinterService: no writable characteristic found');
        await device.disconnect();
        _setState(PrinterConnectionState.error);
        return false;
      }

      _connectedDevice = device;
      _writeCharacteristic = writeCh;
      _setState(PrinterConnectionState.connected);

      // Persist for auto-reconnect.
      await _saveLastPrinter(deviceId, deviceName ?? device.platformName);

      // Listen for disconnection.
      _connectionSub?.cancel();
      _connectionSub =
          device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _writeCharacteristic = null;
          _setState(PrinterConnectionState.disconnected);
        }
      });

      return true;
    } catch (e) {
      dev.log('PrinterService.connect error: $e');
      _setState(PrinterConnectionState.error);
      return false;
    }
  }

  /// Disconnect from the current printer.
  Future<void> disconnect() async {
    _connectionSub?.cancel();
    _connectionSub = null;
    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}
    _connectedDevice = null;
    _writeCharacteristic = null;
    _setState(PrinterConnectionState.disconnected);
  }

  /// Attempt to reconnect to the last known printer. Returns `true` if
  /// successful.
  Future<bool> autoReconnect() async {
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString(_lastPrinterKey);
    final lastName = prefs.getString(_lastPrinterNameKey);
    if (lastId == null || lastId.isEmpty) return false;
    return connect(lastId, deviceName: lastName);
  }

  // ---------------------------------------------------------------------------
  // Printing
  // ---------------------------------------------------------------------------

  /// Send raw bytes (ESC/POS commands) to the connected printer.
  ///
  /// Large payloads are chunked into 512-byte segments to avoid BLE MTU
  /// overflow.
  Future<bool> printReceipt(List<int> bytes) async {
    if (_writeCharacteristic == null || _connectedDevice == null) {
      dev.log('PrinterService: not connected');
      return false;
    }

    try {
      const chunkSize = 512;
      for (var i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize > bytes.length) ? bytes.length : i + chunkSize;
        final chunk = bytes.sublist(i, end);
        await _writeCharacteristic!.write(
          Uint8List.fromList(chunk),
          withoutResponse: _writeCharacteristic!.properties.writeWithoutResponse,
        );
        // Small delay between chunks to let the printer buffer.
        if (end < bytes.length) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
      return true;
    } catch (e) {
      dev.log('PrinterService.print error: $e');
      return false;
    }
  }

  /// Whether a printer is currently connected and ready.
  bool get isConnected => _state == PrinterConnectionState.connected;

  /// Info about the currently connected device, if any.
  PrinterDevice? get connectedPrinter {
    if (_connectedDevice == null) return null;
    return PrinterDevice(
      id: _connectedDevice!.remoteId.str,
      name: _connectedDevice!.platformName,
    );
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Release all resources.
  void dispose() {
    _connectionSub?.cancel();
    _stateController.close();
    _devicesController.close();
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  void _setState(PrinterConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  Future<void> _saveLastPrinter(String id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPrinterKey, id);
    await prefs.setString(_lastPrinterNameKey, name);
  }
}

// -----------------------------------------------------------------------------
// Riverpod providers
// -----------------------------------------------------------------------------

final printerServiceProvider = Provider<PrinterService>((ref) {
  final service = PrinterService();
  ref.onDispose(() => service.dispose());
  return service;
});

final printerStateProvider = StreamProvider<PrinterConnectionState>((ref) {
  final service = ref.watch(printerServiceProvider);
  return service.stateStream;
});

final discoveredPrintersProvider = StreamProvider<List<PrinterDevice>>((ref) {
  final service = ref.watch(printerServiceProvider);
  return service.devicesStream;
});
