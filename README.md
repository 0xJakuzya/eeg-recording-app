# EEG Recording App

Mobile application for real-time recording of EEG data from BLE devices during long sessions

## Application Architecture

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
