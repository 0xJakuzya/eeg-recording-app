# EEG Recording App

Мобильное Flutter‑приложение для регистрации ЭЭГ‑сигналов с BLE‑устройств, управления записями и интеграции с сервисом полисомнографии для анализа сна. Поддерживает подключение по Bluetooth Low Energy, приём и визуализацию данных в реальном времени, запись в txt/csv, просмотр файлов и получение предсказаний стадий сна.

## Структура экранов приложения

![Схема страниц приложения](assets/PageDiagram.png)

Схема навигации и страницы: подключение к устройствам, запись, управление файлами и обработанными сессиями.

## Поток данных

![Диаграмма последовательности](assets/SequenceDiagram.png)

Диаграмма последовательности: от BLE‑устройства до сервиса полисомнографии (запись, загрузка, предикт, гипнограмма).

## Основные возможности

- **Подключение к BLE‑устройствам**
  - Сканирование и подключение к EEG BLE‑устройствам
  - Отслеживание состояния подключения

- **Запись ЭЭГ в реальном времени**
  - Потоковая запись в txt/csv с буферизацией и ротацией по времени
  - Поддержка форматов: int8, uint12Le, int24Be (8 каналов при получении, 1 канал при записи)
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
  - **FilesProcessedPage**: загрузка файлов сессии, автообработка предикта (POST `/users/save_predict_json`)
  - **SessionDetailsPage**: гипнограмма (GET `/users/sleep_graph?index=N`), интервалы стадий сна

- **Настройки**
  - Папка для записей, интервал ротации, частота дискретизации (100/250/500 Гц), формат данных (int8, uint12Le, int24Be), число каналов, адрес сервера полисомнографии, а также кастомные команды на устройство

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
- Дефолтный адрес задаётся в `lib/core/polysomnography_constants.dart`.
- Перед записью TXT для анализа установите частоту дискретизации **100 Гц** в настройках (Bluetooth → Частота дискретизации) 

## Структура проекта

```text
lib/
├── main.dart
├── controllers/
│   ├── ble_controller.dart              # BLE: сканирование, подключение
│   ├── recording_controller.dart        # запись, парсинг, фильтр, CsvStreamWriter
│   ├── settings_controller.dart         # настройки (SharedPreferences)
│   ├── files_controller.dart            # файлы, сессии
│   ├── navigation_controller.dart       # навигация (BottomNavigationBar)
│   └── polysomnography_controller.dart  # состояние полисомнографии (ID пациента, индекс гипнограммы)
│
├── services/
│   ├── csv_stream_service.dart     # потоковая запись txt с ротацией
│   ├── eeg_parser_service.dart     # парсинг bytes → EegSample (int8/12/24)
│   ├── eeg_foreground_service.dart # foreground task при записи
│   └── polysomnography_service.dart # API: uploadPatientFile, getPatientFilesList, savePredictJson, fetchSleepGraphImage
│
├── models/
│   ├── eeg_models.dart             # EegSample, DataFormat
│   ├── recording_models.dart       # RecordingFileInfo, CsvRecordingMetadata
│   └── processed_session_models.dart# ProcessedSession, PredictionStatus
│
├── views/
│   ├── main_navigation.dart       # BottomNavigationBar, IndexedStack
│   ├── connection_page.dart       # сканирование, список устройств
│   ├── device_details_page.dart   # характеристики, команды
│   ├── recording_page.dart        # график, управление записью
│   ├── files_page.dart            # файлы, загрузка в полисомнографию
│   ├── files_processed_page.dart  # сессии, предикт, переход к деталям
│   ├── session_details_page.dart  # гипнограмма, интервалы стадий
│   ├── csv_view_page.dart         # просмотр txt/csv
│   └── settings_page.dart         # настройки
│
├── widgets/
│   ├── device_list.dart
│   ├── characteristic_list.dart
│   ├── device_control_section.dart
│   ├── eeg_plots.dart
│   ├── recording_status_card.dart
│   └── files_selection_bar.dart
│
├── core/
│   ├── ble_constants.dart
│   ├── recording_constants.dart
│   ├── polysomnography_constants.dart
│   ├── app_theme.dart
│   └── app_keys.dart                    # GlobalKey для FilesPage, FilesProcessedPage
│
└── utils/
    ├── extension.dart             # DataFormat, DateTime.format, ...
    └── signal_filters.dart         # Notch50HzFilter
```
