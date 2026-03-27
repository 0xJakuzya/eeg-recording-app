import 'dart:typed_data';

import 'package:ble_app/core/common/eeg_sample.dart';
import 'package:ble_app/core/constants/recording_constants.dart';

// EEG frame (7 bytes):
// [0] 0xAA - header
// [1] battery_level (0..100)
// [2] sample_counter (0..255)
// [3] adc[23:16]
// [4] adc[15:8]
// [5] adc[7:0]
// [6] 0x55 - footer
class EegStreamParser {
  EegStreamParser({this.vRef = 1.2});

  final double vRef;

  static const int _headerMarker = 0xAA;
  static const int _footerMarker = 0x55;
  static const int _packetSize = 7;

  int _lastSeq = -1;
  Uint8List _carry = Uint8List(0);

  List<EegSample> parseChunk(Uint8List chunk, int startTimeMs) {
    if (chunk.isEmpty && _carry.isEmpty) return [];

    final data = _mergeCarry(chunk);
    final samples = <EegSample>[];
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final timestampMs = nowMs - startTimeMs;

    int offset = 0;
    final length = data.length;

    while (offset + _packetSize <= length) {
      if (data[offset] != _headerMarker) {
        _lastSeq = -1; // reset loss detector after desync
        final next = _findNextHeader(data, offset + 1);
        if (RecordingConstants.eegDataFlowDebug) {
          print('[EEG] PARSER: sync error at offset $offset, byte=0x${data[offset].toRadixString(16)}, resync->${next >= 0 ? next : "end"}');
        }
        if (next < 0) {
          offset = length;
          break;
        }
        offset = next;
        continue;
      }

      if (data[offset + 6] != _footerMarker) {
        _lastSeq = -1; // reset loss detector after desync
        if (RecordingConstants.eegDataFlowDebug) {
          print('[EEG] PARSER: bad footer at offset $offset, footer=0x${data[offset + 6].toRadixString(16)}');
        }
        offset++;
        continue;
      }

      final battery = data[offset + 1] & 0xFF;
      final sequence = data[offset + 2] & 0xFF;
      final d2 = data[offset + 3] & 0xFF;
      final d1 = data[offset + 4] & 0xFF;
      final d0 = data[offset + 5] & 0xFF;

      if (_lastSeq >= 0) {
        final expected = (_lastSeq + 1) & 0xFF;
        final diff = (sequence - expected) & 0xFF;
        if (diff != 0) {
          print('[PACKET_LOSS] expected_seq=$expected received_seq=$sequence gap=$diff');
        }
      }
      _lastSeq = sequence;

      int raw = (d2 << 16) | (d1 << 8) | d0;
      if (raw >= 0x800000) raw -= 0x1000000;

      final volts = raw * (vRef / 8388608.0);

      samples.add(EegSample(
        header: _headerMarker,
        sequence: sequence,
        battery: battery,
        dataMsb: d2,
        dataMid: d1,
        dataLsb: d0,
        footer: _footerMarker,
        rawValue: raw,
        volts: volts,
        timestampMs: timestampMs,
      ));

      offset += _packetSize;
    }

    if (offset < length) {
      _carry = data.sublist(offset);
    } else {
      _carry = Uint8List(0);
    }

    return samples;
  }

  void reset() {
    _lastSeq = -1;
    _carry = Uint8List(0);
  }

  Uint8List _mergeCarry(Uint8List chunk) {
    if (_carry.isEmpty) return chunk;
    final merged = Uint8List(_carry.length + chunk.length);
    merged.setRange(0, _carry.length, _carry);
    merged.setRange(_carry.length, merged.length, chunk);  
    _carry = Uint8List(0);
    return merged;
  }

  int _findNextHeader(Uint8List data, int start) {
    for (int i = start; i < data.length; i++) {
      if (data[i] == _headerMarker) return i;
    }
    return -1;
  }
}
