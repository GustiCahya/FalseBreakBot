//+------------------------------------------------------------------+
//|                   XAUUSD_MomentumCandle_EA.mq5                     |
//|                     Momentum Candle Strategy                       |
//|                                                                    |
//|  Strategy:                                                         |
//|  1. Detect Momentum Candle (big body, small wick)                  |
//|  2. Filter with Higher Timeframe EMA trend                         |
//|  3. Entry: Instant at close OR Fibonacci pullback limit order      |
//|  4. SL beyond Momentum Candle high/low + buffer                    |
//|  5. TP by R:R ratio, fixed pip, or Fibonacci extension             |
//|  6. Risk management: lot sizing, daily loss, drawdown guard        |
//+------------------------------------------------------------------+
#property copyright "Momentum Candle Strategy v1.1"
#property link      ""
#property version   "1.10"
#property description "Momentum Candle EA - Rizki Aditama Style"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| ENUMS                                                              |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_MODE
{
   MODE_INSTANT = 0,   // Instant Entry (setelah close)
   MODE_FIBO    = 1    // Fibonacci Pullback (recommended)
};

enum ENUM_TP_MODE
{
   TP_RR_BASED   = 0,  // Risk:Reward based
   TP_FIXED_PIP  = 1,  // Fixed Pip
   TP_FIBO_EXT   = 2   // Fibonacci Extension
};

enum ENUM_ENTRY_TF
{
   TF_M5  = 0,  // M5
   TF_M15 = 1,  // M15
   TF_H1  = 2,  // H1
   TF_H4  = 3,  // H4
   TF_D1  = 4   // D1
};

enum ENUM_HTF
{
   HTF_H1  = 0,  // H1
   HTF_H4  = 1,  // H4
   HTF_D1  = 2,  // D1
   HTF_W1  = 3,  // W1
   HTF_MN1 = 4   // MN1
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                   |
//+------------------------------------------------------------------+

//=== STRATEGY SETTINGS ===
input string            Sep_Strategy       = "=== Strategy Settings ===";           // ---
input ENUM_ENTRY_TF     InpEntryTF         = TF_M5;          // Entry Timeframe
input ENUM_HTF          InpHTF             = HTF_H1;         // Higher Timeframe
input double            InpBodyRatioMin    = 0.70;           // Min Body Ratio (0.0-1.0)
input double            InpWickRatioMax    = 0.30;           // Max Wick Ratio (0.0-1.0)
input int               InpMinBodySize     = 500;            // Min Body Size (points)
input ENUM_ENTRY_MODE   InpEntryMode       = MODE_FIBO;      // Entry Mode
input double            InpFiboLevel       = 0.382;          // Fibo Retrace Level (Primary)
input double            InpFiboLevelSec    = 0.236;          // Fibo Retrace Level (Secondary)
input bool              InpUseSecondFibo   = false;          // Use Secondary Fibo Level
input int               InpFiboValidBars   = 6;              // Fibo Valid Bars (max candles to retrace)
input double            InpMinRR           = 1.0;            // Min Risk:Reward (hard floor 0.5)
input int               InpSLBuffer        = 30;             // SL Buffer (points beyond MC high/low)
input bool              InpUseHTFFilter    = true;           // Use HTF Trend Filter
input int               InpHTF_EMA_Period  = 50;             // HTF EMA Period

//=== TP SETTINGS ===
input string            Sep_TP             = "=== Take Profit Settings ===";       // ---
input ENUM_TP_MODE      InpTPMode          = TP_RR_BASED;    // TP Mode
input int               InpFixedTPPips     = 100;            // Fixed TP (points)
input double            InpFiboExtLevel    = 1.618;          // Fibo Extension Level

//=== FILTER SETTINGS ===
input string            Sep_Filter         = "=== Filter Settings ===";            // ---
input int               InpMaxSpread       = 50;             // Max Spread (points)
input int               InpMaxDailyTrades  = 5;              // Max Daily Trades
input int               InpMaxConcurrent   = 2;              // Max Concurrent Positions
input bool              InpUseSessionFilter = false;         // Use Session Filter
input string            InpSessionStart    = "10:00";        // Session Start (server time HH:MM)
input string            InpSessionEnd      = "20:00";        // Session End (server time HH:MM)

//=== RISK MANAGEMENT ===
input string            Sep_Risk           = "=== Risk Management ===";            // ---
input double            InpRiskPercent     = 1.0;            // Risk Per Trade (% equity)
input bool              InpUseFixedLot     = true;           // Use Fixed Lot
input double            InpFixedLotSize    = 0.01;           // Fixed Lot Size
input double            InpMaxLot          = 1.00;           // Max Lot Size
input double            InpMaxDailyLoss    = 3.0;            // Max Daily Loss (% equity)
input double            InpMaxDrawdown     = 10.0;           // Max Drawdown (% equity)

//=== GENERAL SETTINGS ===
input string            Sep_General        = "=== General Settings ===";           // ---
input long              InpMagicNumber     = 20260908;       // Magic Number
input string            InpTradeComment    = "MomentumCandle"; // Trade Comment
input int               InpSlippage        = 3;              // Slippage (points)
input bool              InpEnableTrailing  = false;          // Enable Trailing Stop
input int               InpTrailingStart   = 100;            // Trailing Start (points profit)
input int               InpTrailingStep    = 30;             // Trailing Step (points)

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                   |
//+------------------------------------------------------------------+
CTrade      trade;
datetime    g_lastBarTime    = 0;
int         g_htfEmaHandle   = INVALID_HANDLE;
double      g_peakEquity     = 0;
bool        g_drawdownPaused = false;

struct FiboPendingInfo
{
   ulong    ticket;
   datetime expiryTime;
   bool     isActive;
};
FiboPendingInfo g_fiboPending;

//+------------------------------------------------------------------+
//| Helper: Convert input enum to ENUM_TIMEFRAMES                     |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetEntryTimeframe()
{
   switch(InpEntryTF)
   {
      case TF_M5:  return PERIOD_M5;
      case TF_M15: return PERIOD_M15;
      case TF_H1:  return PERIOD_H1;
      case TF_H4:  return PERIOD_H4;
      case TF_D1:  return PERIOD_D1;
      default:     return PERIOD_M5;
   }
}

ENUM_TIMEFRAMES GetHTFTimeframe()
{
   switch(InpHTF)
   {
      case HTF_H1:  return PERIOD_H1;
      case HTF_H4:  return PERIOD_H4;
      case HTF_D1:  return PERIOD_D1;
      case HTF_W1:  return PERIOD_W1;
      case HTF_MN1: return PERIOD_MN1;
      default:      return PERIOD_H1;
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpMinRR < 0.5)
      Print("WARNING: MinRR (", InpMinRR, ") di bawah hard floor 0.5. Akan digunakan 0.5.");

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   g_htfEmaHandle = iMA(_Symbol, GetHTFTimeframe(), InpHTF_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   if(g_htfEmaHandle == INVALID_HANDLE)
   {
      Print("ERROR: Gagal membuat HTF EMA indicator handle!");
      return(INIT_FAILED);
   }

   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_fiboPending.isActive = false;
   g_fiboPending.ticket   = 0;

   Print("=== Momentum Candle EA Initialized ===");
   Print("Symbol=", _Symbol,
         " | EntryTF=", EnumToString(GetEntryTimeframe()),
         " | HTF=", EnumToString(GetHTFTimeframe()),
         " | EntryMode=", (InpEntryMode == MODE_INSTANT ? "Instant" : "Fibo"),
         " | MinRR=", DoubleToString(GetEffectiveMinRR(), 2),
         " | HTFFilter=", (InpUseHTFFilter ? "ON" : "OFF"));

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_htfEmaHandle != INVALID_HANDLE)
      IndicatorRelease(g_htfEmaHandle);

   Print("Momentum Candle EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Get effective MinRR (enforced hard floor 0.5)                     |
//+------------------------------------------------------------------+
double GetEffectiveMinRR()
{
   return MathMax(InpMinRR, 0.5);
}

//+------------------------------------------------------------------+
//| Helper: Normalize lot size                                        |
//+------------------------------------------------------------------+
double NormalizeLot(double lots)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathMin(lots, InpMaxLot);
   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);
   lots = MathFloor(lots / lotStep) * lotStep;

   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk % and SL distance                |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistancePoints)
{
   if(InpUseFixedLot)
      return NormalizeLot(InpFixedLotSize);

   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * InpRiskPercent / 100.0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0 || tickSize <= 0 || slDistancePoints <= 0)
   {
      Print("WARNING: Invalid tick info for lot calc. Using fixed lot.");
      return NormalizeLot(InpFixedLotSize);
   }

   double slCostPerLot = (slDistancePoints * _Point / tickSize) * tickValue;

   if(slCostPerLot <= 0)
   {
      Print("WARNING: SL cost per lot <= 0. Using fixed lot.");
      return NormalizeLot(InpFixedLotSize);
   }

   double lots = riskAmount / slCostPerLot;

   Print("Lot Calc: Equity=", DoubleToString(equity, 2),
         " Risk=", DoubleToString(riskAmount, 2),
         " SLDist=", (int)slDistancePoints, "pts",
         " SLCost/lot=", DoubleToString(slCostPerLot, 2),
         " Lots=", DoubleToString(lots, 4));

   return NormalizeLot(lots);
}

//+------------------------------------------------------------------+
//| Count open positions by this EA                                   |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count pending orders by this EA                                   |
//+------------------------------------------------------------------+
int CountPendingOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 &&
         OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
         OrderGetString(ORDER_SYMBOL) == _Symbol)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count trades taken today                                          |
//+------------------------------------------------------------------+
int CountDailyTrades()
{
   int count = 0;

   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime todayStart = StructToTime(dt);

   if(!HistorySelect(todayStart, TimeCurrent()))
      return 0;

   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0 &&
         HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber &&
         HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
         HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
      {
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check daily loss limit                                            |
//+------------------------------------------------------------------+
bool IsDailyLossExceeded()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime todayStart = StructToTime(dt);

   if(!HistorySelect(todayStart, TimeCurrent()))
      return false;

   double dailyPL = 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0 &&
         HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber &&
         HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
      {
         dailyPL += HistoryDealGetDouble(ticket, DEAL_PROFIT)
                  + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
                  + HistoryDealGetDouble(ticket, DEAL_SWAP);
      }
   }

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         dailyPL += PositionGetDouble(POSITION_PROFIT)
                  + PositionGetDouble(POSITION_SWAP);
      }
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double maxLossAmount = equity * InpMaxDailyLoss / 100.0;

   if(dailyPL < 0 && MathAbs(dailyPL) >= maxLossAmount)
   {
      Print("DAILY LOSS LIMIT HIT: P/L=", DoubleToString(dailyPL, 2),
            " | Limit=", DoubleToString(-maxLossAmount, 2));
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check max drawdown                                                |
//+------------------------------------------------------------------+
bool IsMaxDrawdownExceeded()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(equity > g_peakEquity)
      g_peakEquity = equity;

   if(g_peakEquity <= 0) return false;

   double drawdownPct = (g_peakEquity - equity) / g_peakEquity * 100.0;

   if(drawdownPct >= InpMaxDrawdown)
   {
      if(!g_drawdownPaused)
      {
         Print("MAX DRAWDOWN HIT: ", DoubleToString(drawdownPct, 2),
               "% | Peak=", DoubleToString(g_peakEquity, 2),
               " | Current=", DoubleToString(equity, 2));
         g_drawdownPaused = true;
      }
      return true;
   }

   g_drawdownPaused = false;
   return false;
}

//+------------------------------------------------------------------+
//| Check session filter                                              |
//+------------------------------------------------------------------+
bool IsWithinSession()
{
   if(!InpUseSessionFilter) return true;

   int startHour = 0, startMin = 0, endHour = 0, endMin = 0;

   if(StringLen(InpSessionStart) >= 5)
   {
      startHour = (int)StringToInteger(StringSubstr(InpSessionStart, 0, 2));
      startMin  = (int)StringToInteger(StringSubstr(InpSessionStart, 3, 2));
   }
   if(StringLen(InpSessionEnd) >= 5)
   {
      endHour = (int)StringToInteger(StringSubstr(InpSessionEnd, 0, 2));
      endMin  = (int)StringToInteger(StringSubstr(InpSessionEnd, 3, 2));
   }

   MqlDateTime dt;
   TimeCurrent(dt);

   int currentMinutes = dt.hour * 60 + dt.min;
   int startMinutes   = startHour * 60 + startMin;
   int endMinutes     = endHour * 60 + endMin;

   if(startMinutes <= endMinutes)
      return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
   else
      return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
}

//+------------------------------------------------------------------+
//| Check spread filter                                               |
//+------------------------------------------------------------------+
bool IsSpreadOK()
{
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpread)
   {
      Print("SPREAD FILTER: Current=", spread, " > Max=", InpMaxSpread);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| MOMENTUM CANDLE DETECTION                                          |
//+------------------------------------------------------------------+
int IsMomentumCandle(int bar, ENUM_TIMEFRAMES tf)
{
   double o = iOpen(_Symbol, tf, bar);
   double h = iHigh(_Symbol, tf, bar);
   double l = iLow(_Symbol, tf, bar);
   double c = iClose(_Symbol, tf, bar);

   double totalRange = h - l;
   if(totalRange <= 0) return 0;

   double bodySize   = MathAbs(c - o);
   double bodyRatio  = bodySize / totalRange;
   double wickRatio  = 1.0 - bodyRatio;

   if(bodyRatio < InpBodyRatioMin) return 0;
   if(wickRatio > InpWickRatioMax) return 0;

   double bodySizePoints = bodySize / _Point;
   if(bodySizePoints < InpMinBodySize) return 0;

   int direction = 0;
   if(c > o) direction = +1;
   if(c < o) direction = -1;

   if(direction != 0)
   {
      Print("MOMENTUM CANDLE Detected [Bar ", bar, " ", EnumToString(tf), "]",
            " | Dir=", (direction > 0 ? "BULL" : "BEAR"),
            " | BodyRatio=", DoubleToString(bodyRatio, 3),
            " | WickRatio=", DoubleToString(wickRatio, 3),
            " | BodySize=", (int)bodySizePoints, "pts");
   }

   return direction;
}

//+------------------------------------------------------------------+
//| HTF TREND FILTER via EMA                                          |
//+------------------------------------------------------------------+
int GetHTFTrend()
{
   if(g_htfEmaHandle == INVALID_HANDLE) return 0;

   double emaValue[1];
   if(CopyBuffer(g_htfEmaHandle, 0, 0, 1, emaValue) != 1)
   {
      Print("WARNING: Gagal membaca HTF EMA buffer.");
      return 0;
   }

   double htfClose = iClose(_Symbol, GetHTFTimeframe(), 0);

   if(htfClose > emaValue[0]) return +1;
   if(htfClose < emaValue[0]) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate TP price                                                |
//+------------------------------------------------------------------+
double CalculateTP(int direction, double entryPrice, double slDistance,
                   double mcHigh, double mcLow)
{
   double tp = 0;
   double effectiveRR = GetEffectiveMinRR();

   switch(InpTPMode)
   {
      case TP_RR_BASED:
         if(direction > 0)
            tp = entryPrice + slDistance * effectiveRR;
         else
            tp = entryPrice - slDistance * effectiveRR;
         break;

      case TP_FIXED_PIP:
         if(direction > 0)
            tp = entryPrice + InpFixedTPPips * _Point;
         else
            tp = entryPrice - InpFixedTPPips * _Point;
         break;

      case TP_FIBO_EXT:
      {
         double mcRange = mcHigh - mcLow;
         if(direction > 0)
            tp = mcHigh + mcRange * (InpFiboExtLevel - 1.0);
         else
            tp = mcLow - mcRange * (InpFiboExtLevel - 1.0);
         break;
      }

      default:
         // Fallback ke RR based
         if(direction > 0)
            tp = entryPrice + slDistance * effectiveRR;
         else
            tp = entryPrice - slDistance * effectiveRR;
         break;
   }

   return NormalizeDouble(tp, _Digits);
}

//+------------------------------------------------------------------+
//| Place Market Order                                                |
//+------------------------------------------------------------------+
bool PlaceMarketOrder(int direction, double sl, double tp, double lots)
{
   bool result = false;

   if(direction > 0)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      result = trade.Buy(lots, _Symbol, ask, sl, tp, InpTradeComment);
      if(result)
      {
         double slDist = MathAbs(ask - sl);
         double tpDist = MathAbs(tp - ask);
         double rr = (slDist > 0) ? tpDist / slDist : 0;
         Print("BUY MARKET | Entry=", DoubleToString(ask, _Digits),
               " SL=", DoubleToString(sl, _Digits),
               " TP=", DoubleToString(tp, _Digits),
               " Lots=", DoubleToString(lots, 2),
               " RR=1:", DoubleToString(rr, 2));
      }
      else
         Print("BUY MARKET FAILED! Error=", GetLastError());
   }
   else
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      result = trade.Sell(lots, _Symbol, bid, sl, tp, InpTradeComment);
      if(result)
      {
         double slDist = MathAbs(sl - bid);
         double tpDist = MathAbs(bid - tp);
         double rr = (slDist > 0) ? tpDist / slDist : 0;
         Print("SELL MARKET | Entry=", DoubleToString(bid, _Digits),
               " SL=", DoubleToString(sl, _Digits),
               " TP=", DoubleToString(tp, _Digits),
               " Lots=", DoubleToString(lots, 2),
               " RR=1:", DoubleToString(rr, 2));
      }
      else
         Print("SELL MARKET FAILED! Error=", GetLastError());
   }

   return result;
}

//+------------------------------------------------------------------+
//| Place Limit Order (Fibonacci)                                     |
//+------------------------------------------------------------------+
bool PlaceLimitOrder(int direction, double entryPrice, double sl, double tp, double lots)
{
   bool result = false;
   ENUM_TIMEFRAMES entryTF = GetEntryTimeframe();
   datetime expiry = TimeCurrent() + PeriodSeconds(entryTF) * InpFiboValidBars;

   if(direction > 0)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entryPrice >= ask)
      {
         Print("BUY LIMIT skipped: entry already passed.");
         return false;
      }

      result = trade.BuyLimit(lots, entryPrice, _Symbol, sl, tp,
                              ORDER_TIME_SPECIFIED, expiry, InpTradeComment);
      if(result)
      {
         double slDist = MathAbs(entryPrice - sl);
         double tpDist = MathAbs(tp - entryPrice);
         double rr = (slDist > 0) ? tpDist / slDist : 0;
         Print("BUY LIMIT | Entry=", DoubleToString(entryPrice, _Digits),
               " SL=", DoubleToString(sl, _Digits),
               " TP=", DoubleToString(tp, _Digits),
               " Lots=", DoubleToString(lots, 2),
               " RR=1:", DoubleToString(rr, 2));

         g_fiboPending.ticket     = trade.ResultOrder();
         g_fiboPending.expiryTime = expiry;
         g_fiboPending.isActive   = true;
      }
      else
         Print("BUY LIMIT FAILED! Error=", GetLastError());
   }
   else
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entryPrice <= bid)
      {
         Print("SELL LIMIT skipped: entry already passed.");
         return false;
      }

      result = trade.SellLimit(lots, entryPrice, _Symbol, sl, tp,
                               ORDER_TIME_SPECIFIED, expiry, InpTradeComment);
      if(result)
      {
         double slDist = MathAbs(sl - entryPrice);
         double tpDist = MathAbs(entryPrice - tp);
         double rr = (slDist > 0) ? tpDist / slDist : 0;
         Print("SELL LIMIT | Entry=", DoubleToString(entryPrice, _Digits),
               " SL=", DoubleToString(sl, _Digits),
               " TP=", DoubleToString(tp, _Digits),
               " Lots=", DoubleToString(lots, 2),
               " RR=1:", DoubleToString(rr, 2));

         g_fiboPending.ticket     = trade.ResultOrder();
         g_fiboPending.expiryTime = expiry;
         g_fiboPending.isActive   = true;
      }
      else
         Print("SELL LIMIT FAILED! Error=", GetLastError());
   }

   return result;
}

//+------------------------------------------------------------------+
//| TRAILING STOP MANAGEMENT                                          |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(!InpEnableTrailing) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long   posType     = PositionGetInteger(POSITION_TYPE);
      double openPrice   = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL   = PositionGetDouble(POSITION_SL);
      double currentTP   = PositionGetDouble(POSITION_TP);

      if(posType == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double profitPoints = (bid - openPrice) / _Point;

         if(profitPoints >= InpTrailingStart)
         {
            double newSL = NormalizeDouble(bid - InpTrailingStep * _Point, _Digits);
            if(newSL > currentSL + _Point)
            {
               if(trade.PositionModify(ticket, newSL, currentTP))
                  Print("TRAILING SL UP | Ticket=", ticket, " NewSL=", DoubleToString(newSL, _Digits));
            }
         }
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profitPoints = (openPrice - ask) / _Point;

         if(profitPoints >= InpTrailingStart)
         {
            double newSL = NormalizeDouble(ask + InpTrailingStep * _Point, _Digits);
            if(currentSL == 0 || newSL < currentSL - _Point)
            {
               if(trade.PositionModify(ticket, newSL, currentTP))
                  Print("TRAILING SL DOWN | Ticket=", ticket, " NewSL=", DoubleToString(newSL, _Digits));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| PROCESS MOMENTUM CANDLE SIGNAL                                    |
//+------------------------------------------------------------------+
void ProcessSignal()
{
   ENUM_TIMEFRAMES entryTF = GetEntryTimeframe();

   int signal = IsMomentumCandle(1, entryTF);
   if(signal == 0) return;

   // HTF Filter
   if(InpUseHTFFilter)
   {
      int htfTrend = GetHTFTrend();
      if(htfTrend == 0)
      {
         Print("FILTER: HTF trend neutral. Skipping.");
         return;
      }
      if(signal != htfTrend)
      {
         Print("FILTER: Signal melawan HTF trend. Skipping.");
         return;
      }
      Print("HTF TREND OK: ", (htfTrend > 0 ? "BULLISH" : "BEARISH"));
   }

   double mcHigh  = iHigh(_Symbol, entryTF, 1);
   double mcLow   = iLow(_Symbol, entryTF, 1);
   double mcRange = mcHigh - mcLow;

   // SL
   double sl = 0;
   if(signal > 0)
      sl = NormalizeDouble(mcLow - InpSLBuffer * _Point, _Digits);
   else
      sl = NormalizeDouble(mcHigh + InpSLBuffer * _Point, _Digits);

   // Entry Price
   double entryPrice = 0;
   if(InpEntryMode == MODE_INSTANT)
   {
      if(signal > 0) entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      else           entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   else // MODE_FIBO
   {
      if(signal > 0)
         entryPrice = NormalizeDouble(mcHigh - mcRange * InpFiboLevel, _Digits);
      else
         entryPrice = NormalizeDouble(mcLow + mcRange * InpFiboLevel, _Digits);
   }

   double slDistance = MathAbs(entryPrice - sl);
   if(slDistance <= 0)
   {
      Print("ERROR: SL distance <= 0");
      return;
   }
   double slDistancePoints = slDistance / _Point;

   double tp = CalculateTP(signal, entryPrice, slDistance, mcHigh, mcLow);

   // RR Check
   double tpDistance = MathAbs(tp - entryPrice);
   double rr = tpDistance / slDistance;
   double effectiveRR = GetEffectiveMinRR();

   if(rr < 0.5 || rr < effectiveRR)
   {
      Print("RR CHECK FAILED: RR=", DoubleToString(rr, 2), " < required");
      return;
   }

   double lots = CalculateLotSize(slDistancePoints);
   if(lots <= 0) return;

   Print("=== ENTRY SIGNAL === Dir=", (signal > 0 ? "BUY" : "SELL"),
         " Mode=", (InpEntryMode == MODE_INSTANT ? "Instant" : "Fibo"),
         " Entry=", DoubleToString(entryPrice, _Digits),
         " SL=", DoubleToString(sl, _Digits),
         " TP=", DoubleToString(tp, _Digits),
         " RR=1:", DoubleToString(rr, 2),
         " Lots=", DoubleToString(lots, 2));

   if(InpEntryMode == MODE_INSTANT)
   {
      PlaceMarketOrder(signal, sl, tp, lots);
   }
   else
   {
      PlaceLimitOrder(signal, entryPrice, sl, tp, lots);

      // Secondary Fibo
      if(InpUseSecondFibo)
      {
         double entryPrice2 = 0;
         if(signal > 0)
            entryPrice2 = NormalizeDouble(mcHigh - mcRange * InpFiboLevelSec, _Digits);
         else
            entryPrice2 = NormalizeDouble(mcLow + mcRange * InpFiboLevelSec, _Digits);

         double slDist2 = MathAbs(entryPrice2 - sl);
         if(slDist2 > 0)
         {
            double tp2 = CalculateTP(signal, entryPrice2, slDist2, mcHigh, mcLow);
            double rr2 = MathAbs(tp2 - entryPrice2) / slDist2;

            if(rr2 >= effectiveRR && rr2 >= 0.5)
            {
               double lots2 = CalculateLotSize(slDist2 / _Point);
               Print("=== SECONDARY FIBO === Level=", DoubleToString(InpFiboLevelSec, 3));
               PlaceLimitOrder(signal, entryPrice2, sl, tp2, lots2);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   ManageTrailingStop();

   ENUM_TIMEFRAMES entryTF = GetEntryTimeframe();
   datetime currentBarTime = iTime(_Symbol, entryTF, 0);
   if(currentBarTime == g_lastBarTime)
      return;
   g_lastBarTime = currentBarTime;

   // Filters
   if(!IsSpreadOK()) return;

   if(CountDailyTrades() >= InpMaxDailyTrades)
   {
      Print("FILTER: Max daily trades reached");
      return;
   }

   if(CountOpenPositions() + CountPendingOrders() >= InpMaxConcurrent)
      return;

   if(IsDailyLossExceeded()) return;
   if(IsMaxDrawdownExceeded()) return;
   if(!IsWithinSession()) return;

   ProcessSignal();
}
//+------------------------------------------------------------------+