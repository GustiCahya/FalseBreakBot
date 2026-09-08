**PRD: Expert Advisor (EA) – Momentum Candle Strategy (Rizki Aditama Style)**

**Version:** 1.0  
**Date:** 8 September 2026  
**Platform Target:** MetaTrader 4 / MetaTrader 5  
**Strategy Source:** Momentum Candle (price action) ala Rizki Aditama / Sekolah Trading  
**Minimum Risk:Reward (RR):** **0.5** (1 : 0.5)

---

### 1. Tujuan Produk
Membuat EA yang secara otomatis mendeteksi **Momentum Candle** (body panjang + ekor pendek), entry sesuai aturan strategi, dengan Risk:Reward minimum **0.5**, risk management ketat, dan filter higher timeframe.

EA harus cocok untuk scalping (terutama XAUUSD), berjalan di M5 & M15, dan bisa di-backtest dengan mudah.

---

### 2. Core Strategy Rules

#### 2.1 Definisi Momentum Candle
Candle dianggap **Momentum Candle** jika memenuhi **semua** kondisi berikut:

- Body ratio ≥ **BodyRatioMin** (default: 0.70 / 70%)
- Wick ratio (total upper + lower wick) ≤ **WickRatioMax** (default: 0.30 / 30%)
- Body size (dalam point/pip) ≥ **MinBodySize** (input, default tergantung pair)
- Candle muncul setelah minimal **N** candle kecil sebelumnya (opsional filter, default off)

**Bullish Momentum:** Close > Open dan memenuhi kriteria di atas  
**Bearish Momentum:** Close < Open dan memenuhi kriteria di atas

#### 2.2 Timeframe & Higher Timeframe Filter
- Entry Timeframe: **M5** atau **M15** (user selectable)
- Higher Timeframe Filter (wajib):
  - H1 atau H4 (user selectable)
  - Hanya entry **searah** dengan trend HTF (Close > MA atau Higher High/Lower Low sederhana, atau EMA 50)

#### 2.3 Entry Logic
Ada 2 mode entry (user selectable):

**Mode 1 – Instant Entry (setelah close)**
- Setelah Momentum Candle close → entry market order searah.

**Mode 2 – Fibonacci Pullback (recommended)**
- Tarik Fibonacci dari Low → High (bullish) atau High → Low (bearish) pada Momentum Candle.
- Entry Limit/Stop di level:
  - Primary: **38.2%**
  - Secondary: **23.6%** (opsional)
- Hanya valid jika harga retrace ke level tersebut dalam **X candle** berikutnya (default 5–8 candle).

#### 2.4 Stop Loss
- Default: Di luar high/low Momentum Candle + buffer (input dalam point).
- Alternatif: Di level Fibonacci 100% + buffer.
- Minimum SL distance: sesuai broker (untuk XAU biasanya 20–50 point).

#### 2.5 Take Profit & Risk:Reward
- **Minimum RR = 0.5** (Reward minimal 0.5 × Risk).
- TP dihitung otomatis berdasarkan SL distance × RR.
- Contoh: SL 100 point → TP minimal 50 point (RR 0.5).
- User bisa set RR lebih tinggi (1.0 / 1.5 / 2.0), tapi **tidak boleh di bawah 0.5**.
- Opsi TP tambahan:
  - Fixed pip
  - Fibonacci Extension (1.272 / 1.618)
  - Nearest SNR (jika diaktifkan)

#### 2.6 Filter Tambahan (On/Off)
- Avoid Super Resistance/Support (simple swing high/low terakhir)
- Session Filter (London / New York / Asian)
- News Filter (opsional, via calendar atau hardcode jam berisiko)
- Max Spread
- Max Daily Trades
- Max Concurrent Positions

---

### 3. Money Management & Risk Control

| Parameter              | Default     | Keterangan                          |
|------------------------|-------------|-------------------------------------|
| Risk per trade         | 1.0%        | % dari equity                       |
| Fixed Lot              | on          | Jika Off, tidak gunakan fixed lot   |
| Max Lot                | 1.00        | Batas lot maksimum                  |
| Max Daily Loss         | 3%          | Stop trading hari itu               |
| Max Drawdown           | 10%         | Pause EA                            |
| Magic Number           | 20260908    | Unik                                |
| Slippage               | 3           | Point                               |

Lot size dihitung otomatis berdasarkan Risk % dan jarak SL.

---

### 4. Input Parameters (Yang Harus Ada)

**Strategy**
- EntryTimeframe (M5 / M15)
- HTF (H1 / H4)
- BodyRatioMin (0.70)
- WickRatioMax (0.30)
- MinBodySize (point)
- EntryMode (Instant / Fibo)
- FiboLevel (0.382 / 0.236)
- MinRR (0.1)
- SLBuffer (point)
- UseHTFFilter (true/false)

**Risk**
- RiskPercent
- UseFixedLot
- FixedLotSize
- MaxDailyTrades
- MaxSpread

**General**
- MagicNumber
- TradeComment
- EnableTrailing (opsional)
- TrailingStart / TrailingStep

---

### 5. Functional Requirements

1. Deteksi Momentum Candle secara akurat di timeframe entry.
2. Filter higher timeframe wajib (bisa di-disable).
3. Entry hanya jika RR yang dihasilkan ≥ 0.5.
4. SL & TP otomatis dipasang saat entry.
5. Hitung lot size berdasarkan risk %.
6. Log semua entry/exit dengan alasan (Momentum Candle detected, RR, dll).
7. Dashboard sederhana di chart (opsional): current bias HTF, last signal, daily P/L.
8. Compatible dengan XAUUSD, EURUSD, GBPUSD, dll (multi-pair).
9. Support backtesting + optimization di Strategy Tester.
10. Error handling: spread terlalu besar, no money, market closed, dll.

---

### 6. Non-Functional Requirements

- Latency rendah (scalping friendly).
- Tidak menggunakan DLL eksternal (kecuali user setuju).
- Kode bersih, modular, mudah di-maintain.
- Comment kode berbahasa Indonesia + Inggris.
- Versi MT4 dan MT5 (dua file terpisah atau conditional compile).

---

### 7. Acceptance Criteria

- [ ] EA berhasil mendeteksi Momentum Candle sesuai definisi (body ≥ 70%, wick ≤ 30%).
- [ ] Entry hanya terjadi jika RR ≥ 0.5.
- [ ] Lot size dihitung akurat sesuai risk %.
- [ ] SL selalu di luar high/low Momentum Candle.
- [ ] Tidak entry melawan HTF jika filter aktif.
- [ ] Berhasil backtest di XAUUSD M5/M15 tanpa error.
- [ ] Max Daily Loss & Max Drawdown berfungsi.
- [ ] Parameter MinRR tidak bisa diset di bawah 0.5 (hard limit di code).

---

### 8. Out of Scope (Versi 1.0)
- Multi-timeframe entry complex (hanya 1 entry TF + 1 HTF)
- Machine Learning / AI filter
- Partial close / scaling in-out
- Copy trading / signal service
- GUI panel yang rumit

---

### 9. Future Enhancement (Versi selanjutnya)
- Partial TP (50% di RR 0.5, sisanya trail)
- Order Block / FVG filter
- Volume confirmation
- Telegram notification

---

**Catatan Pengembangan:**
- Gunakan pure price action + Fibonacci (tidak bergantung indikator eksternal).
- Prioritaskan kestabilan dan risk control di atas frekuensi trade.
- Uji secara intensif di Strategy Tester dengan spread realistis (XAUUSD biasanya 20–40 point).

Apakah Anda ingin saya lanjutkan dengan:
1. Pseudocode / flowchart logic,
2. Daftar input parameter lengkap siap coding, atau
3. Versi PRD yang lebih detail (termasuk edge cases)?