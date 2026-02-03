# EEG Recording App

Мобильное приложение для непрерывной записи электроэнцефалографических (ЭЭГ) данных с BLE-устройств в течение длительных сессий, с защитой от потери данных и мониторингом сигнала в реальном времени.

## Архитектура приложения

```
EEG Device (BLE)
    ↓ 
BleController (Subscribe)
    ↓
DataParser (Bytes → Float)
    ↓ 
CsvWriter (Append + Flush)
    ↓ 
Storage(/Documents/EEG_Records/)
```