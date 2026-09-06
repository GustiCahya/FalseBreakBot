# Dukascopy AUD/USD Historical Data Retriever

Project Python untuk mengunduh data historis harga pasar (AUD/USD) selama 20 tahun terakhir dari Dukascopy dan mengubahnya menjadi format JSON yang kompatibel dengan MetaTrader 5 (MT5).

## FITUR
- Mengunduh data historis Dukascopy secara otomatis via paket `dukascopy-python`.
- Mengkonversi format data ke JSON array of objects (`[{"time": "...", "open": ..., ...}]`).
- Sangat cocok untuk diintegrasikan atau diparsing oleh EA/Script pada MT5.

## PRASYARAT
- Python 3.8+

## CARA PENGGUNAAN

1. **Aktivasi Virtual Environment (Opsional/Direkomendasikan)**:
   ```cmd
   venv\Scripts\activate
   ```

2. **Install Dependensi**:
   ```cmd
   pip install -r requirements.txt
   ```

3. **Jalankan Script Retriever**:
   ```cmd
   python main.py
   ```

## STRUKTUR OUTPUT (JSON)
Hasil unduhan akan disimpan pada file `AUDUSD_20years_Daily.json` dengan format:
```json
[
    {
        "time": "2006-09-08 00:00:00",
        "open": 0.7512,
        "high": 0.7540,
        "low": 0.7490,
        "close": 0.7525,
        "volume": 12500
    }
]
```

## KONFIGURASI
Anda dapat mengubah timeframe atau simbol instrumen pada file `main.py`:
- `interval`: Ubal `dukascopy_python.INTERVAL_DAY_1` ke `INTERVAL_HOUR_1` atau `INTERVAL_MIN_15` jika membutuhkan data yang lebih detail.
- `instrument`: Ubah `INSTRUMENT_FX_MAJORS_AUD_USD` ke instrumen lain jika diperlukan.
