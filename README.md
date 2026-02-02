# EEG Recording App

Это мобильное приложение, которое предназначено для непрерывной записи электроэнцефалографических (ЭЭГ) данных с BLE-устройств в течение длительных сессий, с защитой от потери данных и мониторингом сигнала в реальном времени


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

## Установка
```
# Клонирование репозитория
git clone <repository-url>
cd ble_flutter_app/ble_app

# Установка зависимостей
flutter pub get

# Запуск
flutter run
```