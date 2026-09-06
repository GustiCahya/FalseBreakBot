//+------------------------------------------------------------------+
//|                         Hammer_DragonFly_EA.mq5                  |
//|                        Bullish Reversal EA                        |
//|                        Hammer + Dragonfly Doji Only               |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Candlestick Reversal"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//=== GENERAL SETTINGS ===
input string   Sep0               = "=== General Settings ===";        // ---
input double   InpLotSize         = 0.01;     // Fixed Lot Size
input int      InpMagicNumber     = 20260907; // Magic Number
input int      InpMaxOpenTrades   = 3;        // Max Simultaneous Open Trades
input int      InpTrendBars       = 5;        // Bars to Confirm Downtrend

//=== EXIT MODE ===
input string   Sep1               = "=== Exit Mode ===";               // ---
input bool     InpUsePipsMode     = false;    // Use SL/TP in Pips (true) or RR Ratio (false)
// --- Mode 1: RR Ratio (when InpUsePipsMode = false)
input double   InpRiskReward      = 1.3;      // Risk-Reward Ratio (e.g. 1.3 = 1:1.3)
// --- Mode 2: Fixed Pips (when InpUsePipsMode = true)
input double   InpSLPips          = 30.0;     // Stop Loss in Pips (Pips Mode)
input double   InpTPPips          = 40.0;     // Take Profit in Pips (Pips Mode)

//=== SL BUFFER (applies to both modes) ===
input double   InpSLBufferPips    = 5.0;      // Stop Loss Buffer (pips, below wick low)

//=== PATTERN SETTINGS ===
input string   Sep2               = "=== Pattern Settings ===";        // ---
input bool     InpUseHammer       = true;     // Use Hammer Pattern
input bool     InpUseDragonflyDoji = true;    // Use Dragonfly Doji Pattern
// --- Hammer thresholds
input double   InpHammerRatio     = 2.0;      // Hammer: Min Lower Shadow / Body Ratio
// --- Dragonfly Doji thresholds
input double   InpDojiMaxBodyPct  = 0.1;      // Dragonfly Doji: Max Body % of Total Range
input double   InpDojiLowerShadow = 0.7;      // Dragonfly Doji: Min Lower Shadow % of Total Range

//--- Global objects
CTrade trade;
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   string exitMode = InpUsePipsMode
      ? StringFormat("Pips Mode (SL=%.0f pips, TP=%.0f pips)", InpSLPips, InpTPPips)
      : StringFormat("RR Mode (1:%.2f)", InpRiskReward);

   Print("Hammer & Dragonfly EA initialized | Symbol=", _Symbol,
         " | TF=", EnumToString(_Period),
         " | Exit=", exitMode);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Helper: pip value                                                 |
//+------------------------------------------------------------------+
double PipValue()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return (digits == 3 || digits == 5) ? _Point * 10 : _Point;
}

//+------------------------------------------------------------------+
//| Count open positions + pending orders by this EA                  |
//+------------------------------------------------------------------+
int CountActiveTrades()
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
//| Downtrend check                                                   |
//+------------------------------------------------------------------+
bool IsDowntrend(int bar)
{
   int downCount = 0;
   for(int i = bar + 1; i <= bar + InpTrendBars; i++)
   {
      if(iClose(_Symbol, _Period, i) < iOpen(_Symbol, _Period, i))
         downCount++;
   }
   return (downCount >= (int)MathCeil(InpTrendBars * 0.6));
}

//+------------------------------------------------------------------+
//| PATTERN DETECTION                                                 |
//+------------------------------------------------------------------+

//--- Hammer
bool DetectHammer(int bar)
{
   double o = iOpen(_Symbol, _Period, bar);
   double h = iHigh(_Symbol, _Period, bar);
   double l = iLow(_Symbol, _Period, bar);
   double c = iClose(_Symbol, _Period, bar);

   double body        = MathAbs(c - o);
   double lowerShadow = MathMin(o, c) - l;
   double upperShadow = h - MathMax(o, c);
   double totalRange  = h - l;

   if(totalRange <= 0) return false;
   if(body < _Point)   body = _Point;

   return (lowerShadow >= InpHammerRatio * body) &&
          (upperShadow < body) &&
          (lowerShadow > totalRange * 0.5) &&
          IsDowntrend(bar);
}

//--- Dragonfly Doji
bool DetectDragonflyDoji(int bar)
{
   double o = iOpen(_Symbol, _Period, bar);
   double h = iHigh(_Symbol, _Period, bar);
   double l = iLow(_Symbol, _Period, bar);
   double c = iClose(_Symbol, _Period, bar);

   double body        = MathAbs(c - o);
   double totalRange  = h - l;
   double lowerShadow = MathMin(o, c) - l;
   double upperShadow = h - MathMax(o, c);

   if(totalRange <= 0) return false;

   return (body / totalRange <= InpDojiMaxBodyPct) &&
          (lowerShadow / totalRange >= InpDojiLowerShadow) &&
          (upperShadow < body + _Point * 5) &&
          IsDowntrend(bar);
}

//+------------------------------------------------------------------+
//| Place Buy Stop — supports both RR and Pips exit modes             |
//+------------------------------------------------------------------+
bool PlaceBuyStop(double entryPrice, double slBasePrice, string patternName)
{
   double pip     = PipValue();
   double buffer  = InpSLBufferPips * pip;
   double sl, tp;

   if(InpUsePipsMode)
   {
      //--- Pips Mode: SL and TP defined in pips from entry
      sl = entryPrice - InpSLPips * pip;
      tp = entryPrice + InpTPPips * pip;
   }
   else
   {
      //--- RR Mode: SL at pattern low minus buffer, TP at entry + SL_dist * RR
      sl = slBasePrice - buffer;
      double slDist = entryPrice - sl;
      if(slDist <= 0) return false;
      tp = entryPrice + slDist * InpRiskReward;
   }

   entryPrice = NormalizeDouble(entryPrice, _Digits);
   sl         = NormalizeDouble(sl, _Digits);
   tp         = NormalizeDouble(tp, _Digits);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entryPrice <= ask)
   {
      Print("BUY STOP skipped (entry below ask): ", patternName,
            " Entry=", entryPrice, " Ask=", ask);
      return false;
   }

   datetime expiry = TimeCurrent() + PeriodSeconds(_Period) * 2;

   if(trade.BuyStop(InpLotSize, entryPrice, _Symbol, sl, tp,
                    ORDER_TIME_SPECIFIED, expiry, patternName))
   {
      string modeStr = InpUsePipsMode
         ? StringFormat("SL=%.0fpips TP=%.0fpips", InpSLPips, InpTPPips)
         : StringFormat("RR=1:%.2f", InpRiskReward);

      Print("BUY STOP [", patternName, "] ",
            "Entry=", entryPrice, " SL=", sl, " TP=", tp, " | ", modeStr);
      return true;
   }

   Print("BUY STOP FAILED [", patternName, "] Error=", GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Only process on new bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastBarTime) return;
   lastBarTime = currentBarTime;

   //--- Check trade limit
   if(CountActiveTrades() >= InpMaxOpenTrades) return;

   //--- Analyze completed bar (bar index 1)
   int    bar      = 1;
   double barHigh  = iHigh(_Symbol, _Period, bar);
   double barLow   = iLow(_Symbol, _Period, bar);

   //--- Hammer
   if(InpUseHammer && DetectHammer(bar))
   {
      //--- Entry: Buy Stop above Hammer's high
      //--- SL base: Hammer's low (buffer added inside PlaceBuyStop in RR mode)
      PlaceBuyStop(barHigh + _Point, barLow, "Hammer");
      return;
   }

   //--- Dragonfly Doji
   if(InpUseDragonflyDoji && DetectDragonflyDoji(bar))
   {
      //--- Entry: Buy Stop above Dragonfly's high
      //--- SL base: Dragonfly's low
      PlaceBuyStop(barHigh + _Point, barLow, "Dragonfly Doji");
      return;
   }
}
//+------------------------------------------------------------------+
