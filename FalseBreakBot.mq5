//+------------------------------------------------------------------+
//|                        FalseBreakBot.mq5                         |
//|  Strategi: False Break / Swept pada level resistance             |
//|  1) Deteksi level resistance dari swing high                     |
//|  2) Jika wick candle menembus level ke atas (swept)              |
//|     TAPI close candle kembali DI BAWAH level -> False Break      |
//|  3) Pasang Sell Stop di bawah low candle swept tsb               |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.01"
#include <Trade\Trade.mqh>

//---------------- Input Parameters ----------------
enum ENUM_LOT_TYPE
{
   LOT_FIXED = 0, // Fixed Lot Size
   LOT_RISK  = 1  // Risk % of Initial Balance
};

input bool   TrendFilterEnabled    = false;      // Aktifkan filter uptrend (blokir sell saat uptrend)
input int    PivotRightBars        = 3;         // Bar kanan untuk konfirmasi swing high
input int    PivotLeftBars         = 11;         // Bar kiri untuk konfirmasi swing high
input int    TrendPivotBars        = 13;         // Bar kiri+kanan untuk deteksi swing pivot trend
input int    MaxActiveLevels       = 211;        // Batas level aktif dipantau bersamaan
input int    TrendLookback         = 210;       // Berapa bar ke belakang untuk mencari 2 swing high/low
input bool   TriggerOnlyOnRetest   = false;     // false=setiap dot. true=hanya saat retest (equal high)
input double EntryBufferPips       = 14.7;         // Jarak Sell Stop di bawah low candle swept (pips)
input int    HistoryBarsBackfill   = 4421;       // Jumlah bar history di-scan saat EA pertama nempel
input double LotSize               = 0.10;      // Lot tetap (jika LOT_FIXED)
input ulong  MagicNumber           = 778899;    // Magic Number
input ENUM_LOT_TYPE LotType        = LOT_FIXED; // Metode perhitungan lot
input double SweepMinPips          = 11;         // Minimum wick di atas level agar dianggap swept (pips)
input int    PendingExpirationBars = 6;         // Order pending dibatalkan otomatis jika belum kena dlm N bar
input double RiskPercent           = 0.5;       // Risk % per trade (jika LOT_RISK)
input bool   OnlyOnePendingAtATime = false;     // Skip sinyal baru jika masih ada posisi/pending terbuka
input double SL_Pips               = 45;        // Stop Loss (pips)
input double TP_Pips               = 70;        // Take Profit (pips)
input bool   ShowLevelsOnChart     = true;      // Tampilkan level di chart
input double TolerancePips         = 15;        // Toleransi harga dianggap "level sama" (pips)
input color  DotColor              = clrRed;    // Warna dot biasa
input color  SweepDotColor         = clrOrange; // Warna dot untuk false break / swept
input color  ActiveLineColor       = clrSilver; // Warna garis level aktif
input color  RetestColor           = clrRed;    // Warna garis retest

//---------------- Struct level resistance ----------------
struct SLevel
{
   long     id;
   double   price;
   datetime originTime;
   datetime lastTouchTime;
   bool     active;
   bool     swept;          // sudah pernah di-swept, hindari sinyal ganda
};

SLevel   g_levels[];
long     g_nextId = 1;
double   g_pip;
datetime g_lastBarTime = 0;
CTrade   trade;
double   g_initialBalance = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   int digitsAdjust = (_Digits == 3 || _Digits == 5) ? 10 : 1;
   g_pip = _Point * digitsAdjust;

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol);

   ArrayResize(g_levels, 0);
   BackfillHistory();

   g_lastBarTime = iTime(_Symbol, _Period, 0);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(ShowLevelsOnChart) ObjectsDeleteAll(0, "EQH_");
}

//+------------------------------------------------------------------+
//| Bangun level dari history yang sudah ada, TANPA memicu order      |
//+------------------------------------------------------------------+
void BackfillHistory()
{
   int bars = MathMin(HistoryBarsBackfill, iBars(_Symbol, _Period) - PivotRightBars - 2);
   if(bars <= PivotLeftBars + PivotRightBars) return;

   for(int shift = bars; shift >= PivotRightBars + 1; shift--)
   {
      double c = iClose(_Symbol, _Period, shift);
      datetime t = iTime(_Symbol, _Period, shift);

      // Cek false break di history (tanpa trigger order)
      CheckFalseBreak(shift, false);

      // Cek breakout murni (close di atas level -> nonaktifkan)
      ProcessBreakout(c, t, false);

      if(IsPivotHighAtShift(shift))
         HandleNewPivot(t, iHigh(_Symbol, _Period, shift), iLow(_Symbol, _Period, shift), false);
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 == g_lastBarTime) return; // proses hanya sekali per bar baru
   g_lastBarTime = t0;

   // Bar yang baru saja CLOSE adalah shift 1
   double closedClose  = iClose(_Symbol, _Period, 1);
   datetime closedTime = iTime(_Symbol, _Period, 1);

   // 1) UTAMA: Cek FALSE BREAK (swept) - wick di atas level tapi close di bawah
   CheckFalseBreak(1, true);

   // 2) Cek breakout murni (close DI ATAS level) -> nonaktifkan level
   ProcessBreakout(closedClose, closedTime, true);

   // 3) Konfirmasi pivot baru (bar yang baru menjadi confirmable = shift PivotRightBars+1)
   int pivotShift = PivotRightBars + 1;
   if(IsPivotHighAtShift(pivotShift))
   {
      datetime pt = iTime(_Symbol, _Period, pivotShift);
      double   pp = iHigh(_Symbol, _Period, pivotShift);
      double   pl = iLow(_Symbol, _Period, pivotShift);
      HandleNewPivot(pt, pp, pl, true);
   }
}

//+------------------------------------------------------------------+
//| CEK FALSE BREAK (SWEPT): wick menembus level ke atas,            |
//| tapi close candle kembali DI BAWAH level -> sinyal SELL          |
//+------------------------------------------------------------------+
void CheckFalseBreak(int shift, bool doTrade)
{
   double hi  = iHigh(_Symbol, _Period, shift);
   double cl  = iClose(_Symbol, _Period, shift);
   double lo  = iLow(_Symbol, _Period, shift);
   datetime t = iTime(_Symbol, _Period, shift);

   int n = ArraySize(g_levels);
   for(int i = 0; i < n; i++)
   {
      if(!g_levels[i].active) continue;

      double lvlPrice = g_levels[i].price;

      // Kondisi false break:
      // 1. High candle MELEWATI level (wick swept ke atas)
      // 2. Close candle kembali DI BAWAH level (false break terkonfirmasi)
      // 3. Minimum wick di atas level >= SweepMinPips
      bool wickAbove  = (hi > lvlPrice + SweepMinPips * g_pip);
      bool closeBelow = (cl < lvlPrice);

      if(wickAbove && closeBelow)
      {
         if(g_levels[i].swept) continue; // sudah swept sebelumnya, skip
         g_levels[i].swept = true;
         g_levels[i].lastTouchTime = t;

         if(doTrade && ShowLevelsOnChart)
            DrawSweepDot(t, hi, g_levels[i].id);

         Print("FALSE BREAK di level ", lvlPrice,
               " | High=", hi, " Close=", cl, " Low=", lo, " @", TimeToString(t));

         if(doTrade)
            PlaceSellStop(lo, t);
      }
   }
}

//+------------------------------------------------------------------+
bool IsPivotHighAtShift(int shift)
{
   double val = iHigh(_Symbol, _Period, shift);
   for(int k = 1; k <= PivotLeftBars; k++)
      if(iHigh(_Symbol, _Period, shift + k) > val) return(false); // bar lebih lama (kiri)
   for(int k = 1; k <= PivotRightBars; k++)
      if(iHigh(_Symbol, _Period, shift - k) > val) return(false); // bar lebih baru (kanan)
   return(true);
}

//+------------------------------------------------------------------+
//| Update status breakout semua level aktif                          |
//| Breakout MURNI = close JELAS di atas level (bukan sekedar swept)  |
//+------------------------------------------------------------------+
void ProcessBreakout(double closePrice, datetime t, bool draw)
{
   for(int i = ArraySize(g_levels) - 1; i >= 0; i--)
   {
      if(!g_levels[i].active) continue;
      // Nonaktifkan hanya jika close secara signifikan di atas level
      // (bukan sekedar wick swept yang langsung berbalik)
      if(closePrice > g_levels[i].price + SweepMinPips * g_pip)
      {
         g_levels[i].active = false;
         if(draw && ShowLevelsOnChart) FinalizeLine(g_levels[i], t);
      }
   }
}

//+------------------------------------------------------------------+
//| Pivot baru -> cocokkan ke level aktif (retest) atau bikin baru     |
//+------------------------------------------------------------------+
void HandleNewPivot(datetime t, double price, double lowAtPivot, bool draw)
{
   int matchIdx = -1;
   double bestDiff = DBL_MAX;
   for(int i = 0; i < ArraySize(g_levels); i++)
   {
      if(!g_levels[i].active) continue;
      double diff = MathAbs(g_levels[i].price - price);
      if(diff <= TolerancePips * g_pip && diff < bestDiff){ bestDiff = diff; matchIdx = i; }
   }

   bool isRetest = (matchIdx >= 0);

   if(isRetest)
   {
      g_levels[matchIdx].lastTouchTime = t;
      // Reset flag swept agar false break berikutnya bisa terdeteksi
      g_levels[matchIdx].swept = false;
      if(draw && ShowLevelsOnChart){ DrawDot(t, price, g_levels[matchIdx].id); DrawRetestLine(g_levels[matchIdx]); }
   }
   else
   {
      SLevel lvl;
      lvl.id            = g_nextId++;
      lvl.price         = price;
      lvl.originTime    = t;
      lvl.lastTouchTime = t;
      lvl.active        = true;
      lvl.swept         = false;
      int n = ArraySize(g_levels);
      ArrayResize(g_levels, n+1);
      g_levels[n] = lvl;
      if(draw && ShowLevelsOnChart){ DrawDot(t, price, lvl.id); DrawActiveLine(lvl); }
      PruneOldLevels();
   }

   // Sell Stop dari pivot biasa (untuk sinyal non-false-break)
   // False break ditangani sepenuhnya di CheckFalseBreak()
   if(draw && !TriggerOnlyOnRetest && !isRetest)
      PlaceSellStop(lowAtPivot, t);
   else if(draw && TriggerOnlyOnRetest && isRetest)
      PlaceSellStop(lowAtPivot, t);
}

//+------------------------------------------------------------------+
//| Deteksi uptrend dengan Higher High + Higher Low                   |
//| Uptrend = swing high terakhir > swing high sebelumnya            |
//|        AND swing low terakhir > swing low sebelumnya             |
//+------------------------------------------------------------------+
bool IsUptrend()
{
   if(!TrendFilterEnabled) return(false);

   int maxBars = MathMin(TrendLookback, iBars(_Symbol, _Period) - TrendPivotBars - 2);

   // Kumpulkan 2 swing high dan 2 swing low terakhir
   double swingHigh[2]; int swingHighCount = 0;
   double swingLow[2];  int swingLowCount  = 0;

   for(int shift = TrendPivotBars + 1; shift <= maxBars && (swingHighCount < 2 || swingLowCount < 2); shift++)
   {
      // Cek swing high
      if(swingHighCount < 2)
      {
         double h = iHigh(_Symbol, _Period, shift);
         bool isHigh = true;
         for(int k = 1; k <= TrendPivotBars && isHigh; k++)
         {
            if(iHigh(_Symbol, _Period, shift + k) >= h) isHigh = false;
            if(iHigh(_Symbol, _Period, shift - k) >= h) isHigh = false;
         }
         if(isHigh) swingHigh[swingHighCount++] = h;
      }

      // Cek swing low
      if(swingLowCount < 2)
      {
         double l = iLow(_Symbol, _Period, shift);
         bool isLow = true;
         for(int k = 1; k <= TrendPivotBars && isLow; k++)
         {
            if(iLow(_Symbol, _Period, shift + k) <= l) isLow = false;
            if(iLow(_Symbol, _Period, shift - k) <= l) isLow = false;
         }
         if(isLow) swingLow[swingLowCount++] = l;
      }
   }

   if(swingHighCount < 2 || swingLowCount < 2) return(false); // data tidak cukup

   // swingHigh[0] = swing high terbaru, swingHigh[1] = swing high sebelumnya
   bool higherHigh = (swingHigh[0] > swingHigh[1]);
   bool higherLow  = (swingLow[0]  > swingLow[1]);

   return(higherHigh && higherLow);
}

//+------------------------------------------------------------------+
void PlaceSellStop(double candleLow, datetime signalTime)
{
   if(OnlyOnePendingAtATime && HasOpenOrPending()) return;

   // Filter trend: skip sell jika pasar sedang uptrend (HH + HL)
   if(IsUptrend())
   {
      Print("Sinyal SELL dilewati: pasar dalam kondisi UPTREND (HH+HL).");
      return;
   }

   double entry = NormalizeDouble(candleLow - EntryBufferPips * g_pip, _Digits);
   double sl    = NormalizeDouble(entry + SL_Pips * g_pip, _Digits);
   double tp    = NormalizeDouble(entry - TP_Pips * g_pip, _Digits);

   // Validasi jarak minimum broker (stops level)
   double stopsLevelPts = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Jika harga sudah melewati entry atau terlalu dekat -> Sell Market langsung
   if(bid <= entry + stopsLevelPts)
   {
      double slMkt = NormalizeDouble(bid + SL_Pips * g_pip, _Digits);
      double tpMkt = NormalizeDouble(bid - TP_Pips * g_pip, _Digits);
      double vol = CalculateLotSize();
      bool ok = trade.Sell(vol, _Symbol, bid, slMkt, tpMkt,
                           "False Break Sell Market");
      if(!ok)
         Print("Gagal Sell Market: ", trade.ResultRetcodeDescription());
      else
         Print("Sell Market @", bid, " SL=", slMkt, " TP=", tpMkt);
      return;
   }

   double vol = CalculateLotSize();
   datetime expiration = signalTime + (datetime)(PendingExpirationBars * PeriodSeconds(_Period));

   bool ok = trade.SellStop(vol, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration,
                             "False Break SellStop");
   if(!ok)
      Print("Gagal pasang Sell Stop: ", trade.ResultRetcodeDescription());
   else
      Print("Sell Stop dipasang @", entry, " SL=", sl, " TP=", tp);
}

//+------------------------------------------------------------------+
bool HasOpenOrPending()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == (long)MagicNumber) return(true);
   }
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetString(ORDER_SYMBOL) == _Symbol &&
         OrderGetInteger(ORDER_MAGIC) == (long)MagicNumber) return(true);
   }
   return(false);
}

//+------------------------------------------------------------------+
double CalculateLotSize()
{
   if(LotType == LOT_FIXED)
      return NormalizeVolume(LotSize);
      
   double riskAmount = g_initialBalance * (RiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickSize == 0 || tickValue == 0) return NormalizeVolume(LotSize); // fallback
   
   double slDistance = SL_Pips * g_pip;
   double slTicks = slDistance / tickSize;
   
   if(slTicks == 0) return NormalizeVolume(LotSize); // fallback
   
   double lot = riskAmount / (slTicks * tickValue);
   return NormalizeVolume(lot);
}

//+------------------------------------------------------------------+
double NormalizeVolume(double vol)
{
   double minVol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   vol = MathRound(vol / stepVol) * stepVol;
   vol = MathMax(minVol, MathMin(maxVol, vol));
   return(vol);
}

//+------------------------------------------------------------------+
//| Buang level aktif paling lama kalau kepenuhan                     |
//+------------------------------------------------------------------+
void PruneOldLevels()
{
   int activeCount = 0;
   for(int i = 0; i < ArraySize(g_levels); i++) if(g_levels[i].active) activeCount++;
   while(activeCount > MaxActiveLevels)
   {
      int oldestIdx = -1; datetime oldestTime = 0;
      for(int i = 0; i < ArraySize(g_levels); i++)
      {
         if(!g_levels[i].active) continue;
         if(oldestIdx == -1 || g_levels[i].originTime < oldestTime){ oldestIdx = i; oldestTime = g_levels[i].originTime; }
      }
      if(oldestIdx == -1) break;
      g_levels[oldestIdx].active = false;
      activeCount--;
   }
}

//+------------------------------------------------------------------+
//| Visualisasi                                                        |
//+------------------------------------------------------------------+
string LineName(long id)   { return "EQH_LINE_"   + IntegerToString(id); }
string RetestName(long id) { return "EQH_RETEST_" + IntegerToString(id); }
string DotName(long id, datetime t) { return "EQH_DOT_" + IntegerToString(id) + "_" + IntegerToString((long)t); }
string SweepDotName(long id, datetime t) { return "EQH_SWEEP_" + IntegerToString(id) + "_" + IntegerToString((long)t); }

void DrawActiveLine(SLevel &lvl)
{
   string name = LineName(lvl.id);
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TREND, 0, lvl.originTime, lvl.price, lvl.originTime, lvl.price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, ActiveLineColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

void FinalizeLine(SLevel &lvl, datetime breakTime)
{
   string name = LineName(lvl.id);
   if(ObjectFind(0, name) >= 0)
   {
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectMove(0, name, 1, breakTime, lvl.price);
   }
}

void DrawRetestLine(SLevel &lvl)
{
   string name = RetestName(lvl.id);
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TREND, 0, lvl.originTime, lvl.price, lvl.lastTouchTime, lvl.price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, RetestColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
}

void DrawDot(datetime t, double price, long id)
{
   string name = DotName(id, t);
   if(ObjectFind(0, name) >= 0) return;
   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
   ObjectSetInteger(0, name, OBJPROP_COLOR, DotColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
}

// Dot khusus false break / swept (tampil di HIGH candle swept, panah ke bawah)
void DrawSweepDot(datetime t, double highPrice, long id)
{
   string name = SweepDotName(id, t);
   if(ObjectFind(0, name) >= 0) return;
   ObjectCreate(0, name, OBJ_ARROW, 0, t, highPrice);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 218); // panah bawah
   ObjectSetInteger(0, name, OBJPROP_COLOR, SweepDotColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_TOP);
}
//+------------------------------------------------------------------+