# EEG Recording App

Мобильное Flutter‑приложение для регистрации ЭЭГ‑сигналов с BLE‑устройств, управления записями и интеграции с сервисом полисомнографии для анализа сна. Поддерживает подключение по Bluetooth Low Energy, приём и визуализацию данных в реальном времени, запись в txt/csv, просмотр файлов и получение предсказаний стадий сна.

## Структура экранов приложения

![Схема страниц приложения](assets/PageDiagram.png)

Схема навигации и страницы: подключение к устройствам, запись, управление файлами и обработанными сессиями.

## Основные возможности

- **Подключение к BLE‑устройствам**
  - Сканирование и подключение к EEG BLE‑устройствам
  - Отслеживание состояния подключения

- **Запись ЭЭГ в реальном времени**
  - Потоковая запись в txt/csv с буферизацией и ротацией по времени
  - Поддержка формата: int24Be (8 каналов при получении)
  - Фильтр Notch 50 Гц (подавление сетевой частоты) для полисомнографии
  - Foreground service для записи при свёрнутом экране

- **Онлайн‑визуализация сигналов**
  - Отображение сигналов в реальном времени (до 8 каналов)
  - Скользящее окно (3/5/10 с) и регулировка масштаба амплитуды

- **Работа с файлами**
  - Просмотр списка записей и директорий
  - Удаление файлов/папок с синхронизацией счётчика сессий
  - Шаринг и просмотр содержимого txt

- **Интеграция с полисомнографией**
  - **FilesPage**: загрузка выбранных файлов на сервер (POST `/users/save_user_file`)
  - **ProcessedFilesPage**: загрузка файлов сессии, автообработка предикта (POST `/users/save_predict_json`)
  - **SessionDetailsPage**: гипнограмма (GET `/users/sleep_graph?index=N`), интервалы стадий сна

- **Настройки**
  - Папка для записей, формат файла (TXT/CSV), количество каналов для записи (1–8), интервал ротации, частота дискретизации (100/250/500 Гц), формат данных (int24Be), адрес сервера полисомнографии, а также кастомные команды на устройство

## Требования для отправки в полисомнографию

Для корректного анализа данных модели необходимо соблюдать следующие условия:

### Одноканальные записи

- **TXT‑файлы**: убедитесь, что данные содержат только **один канал**. Запись через приложение пишет одноканальные данные по умолчанию.

### Параметры сигнала

| Параметр | Значение |
|----------|----------|
| **Частота дискретизации** | 100 Гц |
| **Фильтр подавления сетевой частоты** | 50 Гц (Notch‑фильтр) |

Рекомендуется задать частоту 100 Гц в настройках перед записью для TXT‑файлов. Фильтр 50 Гц применяется к данным при записи.

## Архитектура данных

### Запись ЭЭГ

```text
BLE Device (notify)
    ↓
BleController.selectedDataCharacteristic.lastValueStream
    ↓
RecordingController.onDataReceived(bytes)
    ↓
EegParserService.parseAllBytes() → List<EegSample> (int24Be)
    ↓
Notch50HzFilter.process() — подавление 50 Гц
    ↓
CsvStreamWriter.writeSample() → buffer → flush при 100 строках
    ↓
File: dd.MM.yyyy/session_N/session_N_dd.MM.yyyy_HH-mm.txt
```

### Интеграция с полисомнографией

```text
txt/edf файлы (одноканальные, 100 Гц, фильтр 50 Гц)
    ↓
POST /users/save_user_file (patient_id, patient_name, sampling_frequency для .txt)
    ↓
POST /users/save_predict_json (patient_id, file_index, channel для .edf)
    ↓
PredictResult(prediction, jsonIndex)
    ↓
GET /users/sleep_graph?index=N → PNG гипнограмма
    ↓
SessionDetailsPage: Image + chips с интервалами стадий
```

## Установка и запуск

1. Установите Flutter SDK (рекомендуется 3.10+)
2. Установите зависимости:

   ```bash
   flutter pub get
   ```

3. Запустите приложение:

   ```bash
   flutter run
   ```

Для интеграции с полисомнографией:
- **URL сервера**: Настройки → Полисомнография → Адрес сервера. Укажите адрес API, например `http://192.168.0.174:8000`. При смене Wi‑Fi IP компьютера может измениться — узнайте его командой `ipconfig` (Windows) и обновите в настройках.
- Дефолтный адрес задаётся в `lib/core/constants/polysomnography_constants.dart`.
- Перед записью TXT для анализа установите частоту дискретизации **100 Гц** в настройках (Bluetooth → Частота дискретизации) 

## Структура проекта

```text
lib/
├── main.dart
├── core/
│   ├── constants/
│   │   ├── ble_constants.dart
│   │   ├── recording_constants.dart
│   │   └── polysomnography_constants.dart
│   ├── theme/
│   │   └── app_theme.dart
│   ├── utils/
│   │   ├── format_extensions.dart   # DataFormat, DateTime.format, ...
│   │   └── signal_filters.dart     # Notch50HzFilter
│   └── common/
│       ├── eeg_sample.dart
│       └── recording_models.dart
│
└── features/
    ├── ble/
    │   ├── ble_controller.dart
    │   ├── connection_page.dart
    │   ├── device_details_page.dart
    │   └── widgets/
    │       ├── device_list.dart
    │       └── characteristic_list.dart
    │
    ├── recording/
    │   ├── recording_controller.dart
    │   ├── recording_page.dart
    │   ├── csv_stream_service.dart
    │   ├── eeg_parser_service.dart
    │   ├── eeg_foreground_service.dart
    │   └── widgets/
    │       ├── eeg_plots.dart
    │       └── recording_status_card.dart
    │
    ├── files/
    │   ├── files_controller.dart
    │   ├── files_page.dart
    │   ├── csv_view_page.dart
    │   └── widgets/
    │       └── files_selection_bar.dart
    │
    ├── polysomnography/
    │   ├── polysomnography_controller.dart
    │   ├── polysomnography_service.dart
    │   ├── processed_files_page.dart
    │   ├── session_details_page.dart
    │   └── processed_session.dart
    │
    ├── settings/
    │   ├── settings_controller.dart
    │   └── settings_page.dart
    │
    └── navigation/
        ├── navigation_controller.dart
        └── main_navigation.dart
```
