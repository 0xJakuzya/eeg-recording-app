import 'package:flutter_test/flutter_test.dart';
import 'package:ble_app/models/eeg_sample.dart';
import 'package:ble_app/services/eeg_parser_service.dart';
import 'package:ble_app/services/csv_stream_writer.dart';
import 'package:ble_app/widgets/eeg_plots.dart';

void main() {
  // ==================== EegSample Tests ====================
  group('EegSample', () {
    test('create with 1 channel', () {
      final sample = EegSample(
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        channels: [100.0],
      );
      expect(sample.channelCount, 1);
    });

    test('create with 2 channels', () {
      final sample = EegSample(
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        channels: [100.0, 200.0],
      );
      expect(sample.channelCount, 2);
    });

    test('create with 8 channels', () {
      final sample = EegSample(
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        channels: [1, 2, 3, 4, 5, 6, 7, 8],
      );
      expect(sample.channelCount, 8);
    });

    test('toCsvLine format (1 channel)', () {
      final sample = EegSample(
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        channels: [100.5],
      );
      expect(sample.toCsvLine(), '1000,100.5');
    });

    test('toCsvLine format (2 channels)', () {
      final sample = EegSample(
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        channels: [100.5, 200.5],
      );
      expect(sample.toCsvLine(), '1000,100.5,200.5');
    });

    test('fromCsvLine parsing (1 channel)', () {
      final sample = EegSample.fromCsvLine('1000,100.5');
      expect(sample.timestamp.millisecondsSinceEpoch, 1000);
      expect(sample.channelCount, 1);
      expect(sample.channels[0], 100.5);
    });

    test('fromCsvLine parsing (2 channels)', () {
      final sample = EegSample.fromCsvLine('1000,100.5,200.5');
      expect(sample.channelCount, 2);
      expect(sample.channels[0], 100.5);
      expect(sample.channels[1], 200.5);
    });

    test('roundtrip csv', () {
      final original = EegSample(
        timestamp: DateTime.fromMillisecondsSinceEpoch(5000),
        channels: [10.5, 20.5],
      );
      final restored = EegSample.fromCsvLine(original.toCsvLine());
      expect(restored.timestamp.millisecondsSinceEpoch, 5000);
      expect(restored.channels, original.channels);
    });
  });

  // ==================== EegParserService Tests ====================
  group('EegParserService', () {
    test('1 channel parser', () {
      final parser = EegParserService(channelCount: 1);
      expect(parser.channelCount, 1);
      expect(parser.expectedPacketSize, 2);
    });

    test('2 channel parser', () {
      final parser = EegParserService(channelCount: 2);
      expect(parser.channelCount, 2);
      expect(parser.expectedPacketSize, 4);
    });

    test('8 channel parser', () {
      final parser = EegParserService(channelCount: 8);
      expect(parser.channelCount, 8);
      expect(parser.expectedPacketSize, 16);
    });

    test('parse 1 channel data', () {
      final parser = EegParserService(channelCount: 1);
      final bytes = [0xE8, 0x03]; // 1000
      final sample = parser.parseBytes(bytes);
      expect(sample.channelCount, 1);
      expect(sample.channels[0], 1000.0);
    });

    test('parse 2 channel data', () {
      final parser = EegParserService(channelCount: 2);
      final bytes = [0xE8, 0x03, 0xD0, 0x07]; // 1000, 2000
      final sample = parser.parseBytes(bytes);
      expect(sample.channelCount, 2);
      expect(sample.channels[0], 1000.0);
      expect(sample.channels[1], 2000.0);
    });

    test('parse negative values', () {
      final parser = EegParserService(channelCount: 1);
      final bytes = [0xFF, 0xFF]; // -1
      final sample = parser.parseBytes(bytes);
      expect(sample.channels[0], -1.0);
    });

    test('parse min/max int16 values', () {
      final parser = EegParserService(channelCount: 2);
      final bytes = [
        0x00, 0x80, // -32768 (min)
        0xFF, 0x7F, // 32767 (max)
      ];
      final sample = parser.parseBytes(bytes);
      expect(sample.channels[0], -32768.0);
      expect(sample.channels[1], 32767.0);
    });
  });

  // ==================== CsvStreamWriter Tests ====================
  group('CsvStreamWriter', () {
    test('1 channel writer', () {
      final writer = CsvStreamWriter(channelCount: 1);
      expect(writer.channelCount, 1);
    });

    test('2 channel writer', () {
      final writer = CsvStreamWriter(channelCount: 2);
      expect(writer.channelCount, 2);
    });

    test('buffer size constant', () {
      expect(CsvStreamWriter.bufferSize, 100);
    });

    test('isRecording initially false', () {
      final writer = CsvStreamWriter();
      expect(writer.isRecording, false);
    });

    test('writeSample adds to buffer', () {
      final writer = CsvStreamWriter(channelCount: 1);
      final sample = EegSample(
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        channels: [100.0],
      );
      writer.writeSample(sample);
      expect(writer.buffer.length, 1);
      expect(writer.buffer[0], '1000,100.0');
    });

    test('writeRawData adds to buffer', () {
      final writer = CsvStreamWriter(channelCount: 2);
      writer.writeRawData(
        DateTime.fromMillisecondsSinceEpoch(1000),
        [100.0, 200.0],
      );
      expect(writer.buffer.length, 1);
      expect(writer.buffer[0], '1000,100.0,200.0');
    });

    test('buffer accumulates until flush', () {
      final writer = CsvStreamWriter(channelCount: 1);
      for (int i = 0; i < 50; i++) {
        writer.writeSample(EegSample(
          timestamp: DateTime.fromMillisecondsSinceEpoch(i * 100),
          channels: [i.toDouble()],
        ));
      }
      expect(writer.buffer.length, 50);
    });
  });

  // ==================== EegDataPoint Tests ====================
  group('EegDataPoint', () {
    test('create with time and amplitude', () {
      final point = EegDataPoint(time: 1.5, amplitude: 100.0);
      expect(point.time, 1.5);
      expect(point.amplitude, 100.0);
    });

    test('create with negative amplitude', () {
      final point = EegDataPoint(time: 0.0, amplitude: -50.0);
      expect(point.amplitude, -50.0);
    });
  });

  // ==================== Channel Colors Tests ====================
  group('ChannelColors', () {
    test('has 8 colors', () {
      expect(channelColors.length, 8);
    });

    test('all colors are different', () {
      final uniqueColors = channelColors.toSet();
      expect(uniqueColors.length, 8);
    });
  });
}
