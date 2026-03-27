// immutable single-channel EEG sample from 7-byte BLE packet
class EegSample {
  final int header;
  final int sequence;
  final int battery;
  final int dataMsb;
  final int dataMid;
  final int dataLsb;
  final int footer;
  final int rawValue;
  final double volts;
  final int timestampMs;

  EegSample({
    required this.header,
    required this.sequence,
    required this.battery,
    required this.dataMsb,
    required this.dataMid,
    required this.dataLsb,
    required this.footer,
    required this.rawValue,
    required this.volts,
    required this.timestampMs,
  });

  String toCsvLine(int absoluteTimestampMs) {
    return '$absoluteTimestampMs,'
        '$header,'
        '$battery,'
        '$sequence,'
        '$dataMsb,'
        '$dataMid,'
        '$dataLsb,'
        '$footer,'
        '$rawValue,'
        '${volts.toStringAsFixed(6)}';
  }

  factory EegSample.fromCsvLine(String line) {
    final parts = line.trim().split(',');
    final volts = parts.isNotEmpty ? double.parse(parts.last) : 0.0;
    return EegSample(
      header: 0,
      sequence: 0,
      battery: 0,
      dataMsb: 0,
      dataMid: 0,
      dataLsb: 0,
      footer: 0,
      rawValue: 0,
      volts: volts,
      timestampMs: 0,
    );
  }

  @override
  String toString() =>
      'EegSample(SEQ=$sequence BT=$battery RAW=$rawValue V=$volts ts=$timestampMs)';
}
