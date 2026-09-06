//+------------------------------------------------------------------+
//|                          AUDUSD_CandlestickReversal_EA.mq5       |
//|                        Candlestick Reversal Expert Advisor        |
//|                        All 14 Patterns Combined                   |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Candlestick Reversal"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//=== GENERAL SETTINGS ===
input string   Sep0                = "=== General Settings ===";           // ---
input double   InpLotSize          = 0.01;    // Fixed Lot Size
input double   InpRiskReward       = 1.06;     // Risk-Reward Ratio (e.g. 1.3 = 1:1.3)
input double   InpSLBufferPips     = 5.0;     // Stop Loss Buffer (pips)
input int      InpMagicNumber      = 20260906;// Magic Number
input int      InpMaxOpenTrades    = 3;       // Max simultaneous open trades
input int      InpTrendBars        = 5;       // Bars to confirm trend context

//=== BULLISH PATTERNS ON/OFF ===
input string   Sep1                = "=== Bullish Patterns ===";           // ---
input bool     InpUseHammer        = true;    // Use Hammer
input bool     InpUseInvHammer     = false;    // Use Inverted Hammer
input bool     InpUseBullEngulf    = false;    // Use Bullish Engulfing
input bool     InpUseMorningStar   = false;    // Use Morning Star
input bool     InpUsePiercingLine  = false;    // Use Piercing Line
input bool     InpUseBullHarami    = false;    // Use Bullish Harami
input bool     InpUseDragonflyDoji = true;    // Use Dragonfly Doji

//=== BEARISH PATTERNS ON/OFF ===
input string   Sep2                = "=== Bearish Patterns ===";           // ---
input bool     InpUseShootStar     = false;    // Use Shooting Star
input bool     InpUseHangingMan    = false;    // Use Hanging Man
input bool     InpUseBearEngulf    = false;    // Use Bearish Engulfing
input bool     InpUseEveningStar   = false;    // Use Evening Star
input bool     InpUseDarkCloud     = false;    // Use Dark Cloud Cover
input bool     InpUseBearHarami    = false;    // Use Bearish Harami
input bool     InpUseGravestDoji   = false;    // Use Gravestone Doji

//=== PATTERN THRESHOLDS ===
input string   Sep3                = "=== Pattern Thresholds ===";         // ---
input double   InpPinBarRatio      = 2.0;     // Pin Bar shadow/body ratio
input double   InpDojiMaxBodyPct   = 0.41;     // Doji max body % of range
input double   InpDojiShadowPct    = 1.19;     // Doji min dominant shadow % of range
input double   InpMinBodyPct       = 0.5;     // Min body % for large candles (Star)
input double   InpPiercePct        = 0.5;     // Piercing/Dark Cloud min penetration %
input double   InpHaramiMotherPct  = 0.5;     // Harami mother min body % of range

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
   
   Print("AUDUSD Candlestick Reversal EA initialized on ", _Symbol, " ", EnumToString(_Period));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Count open positions by this EA                                    |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
            PositionGetString(POSITION_SYMBOL) == _Symbol)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Count pending orders by this EA                                    |
//+------------------------------------------------------------------+
int CountPendingOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
            OrderGetString(ORDER_SYMBOL) == _Symbol)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Get pip value for current symbol                                   |
//+------------------------------------------------------------------+
double PipValue()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return _Point * 10;
   return _Point;
}

//+------------------------------------------------------------------+
//| TREND DETECTION                                                    |
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

bool IsUptrend(int bar)
{
   int upCount = 0;
   for(int i = bar + 1; i <= bar + InpTrendBars; i++)
   {
      if(iClose(_Symbol, _Period, i) > iOpen(_Symbol, _Period, i))
         upCount++;
   }
   return (upCount >= (int)MathCeil(InpTrendBars * 0.6));
}

//+------------------------------------------------------------------+
//| Place Buy Stop Order                                              |
//+------------------------------------------------------------------+
bool PlaceBuyStop(double entryPrice, double slPrice, string patternName)
{
   double buffer = InpSLBufferPips * PipValue();
   slPrice -= buffer;
   
   double slDist = entryPrice - slPrice;
   if(slDist <= 0) return false;
   
   double tpPrice = entryPrice + slDist * InpRiskReward;
   
   //--- Normalize prices
   entryPrice = NormalizeDouble(entryPrice, _Digits);
   slPrice    = NormalizeDouble(slPrice, _Digits);
   tpPrice    = NormalizeDouble(tpPrice, _Digits);
   
   //--- Validate
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entryPrice <= ask) return false;  // Buy Stop must be above current ask
   
   datetime expiration = TimeCurrent() + PeriodSeconds(_Period) * 2; // expire after 2 bars
   
   if(trade.BuyStop(InpLotSize, entryPrice, _Symbol, slPrice, tpPrice, 
                     ORDER_TIME_SPECIFIED, expiration, patternName))
   {
      Print("BUY STOP placed: ", patternName, 
            " Entry=", entryPrice, " SL=", slPrice, " TP=", tpPrice);
      return true;
   }
   
   Print("BUY STOP failed: ", patternName, " Error=", GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| Place Sell Stop Order                                             |
//+------------------------------------------------------------------+
bool PlaceSellStop(double entryPrice, double slPrice, string patternName)
{
   double buffer = InpSLBufferPips * PipValue();
   slPrice += buffer;
   
   double slDist = slPrice - entryPrice;
   if(slDist <= 0) return false;
   
   double tpPrice = entryPrice - slDist * InpRiskReward;
   
   //--- Normalize prices
   entryPrice = NormalizeDouble(entryPrice, _Digits);
   slPrice    = NormalizeDouble(slPrice, _Digits);
   tpPrice    = NormalizeDouble(tpPrice, _Digits);
   
   //--- Validate
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entryPrice >= bid) return false;  // Sell Stop must be below current bid
   
   datetime expiration = TimeCurrent() + PeriodSeconds(_Period) * 2;
   
   if(trade.SellStop(InpLotSize, entryPrice, _Symbol, slPrice, tpPrice, 
                      ORDER_TIME_SPECIFIED, expiration, patternName))
   {
      Print("SELL STOP placed: ", patternName,
            " Entry=", entryPrice, " SL=", slPrice, " TP=", tpPrice);
      return true;
   }
   
   Print("SELL STOP failed: ", patternName, " Error=", GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| PATTERN DETECTION FUNCTIONS                                        |
//+------------------------------------------------------------------+

//--- Hammer (bullish)
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
   if(body < _Point) body = _Point;
   
   return (lowerShadow >= InpPinBarRatio * body) &&
          (upperShadow < body) &&
          (lowerShadow > totalRange * 0.5) &&
          IsDowntrend(bar);
}

//--- Inverted Hammer (bullish)
bool DetectInvertedHammer(int bar)
{
   double o = iOpen(_Symbol, _Period, bar);
   double h = iHigh(_Symbol, _Period, bar);
   double l = iLow(_Symbol, _Period, bar);
   double c = iClose(_Symbol, _Period, bar);
   
   double body        = MathAbs(c - o);
   double upperShadow = h - MathMax(o, c);
   double lowerShadow = MathMin(o, c) - l;
   
   if(body < _Point) body = _Point;
   
   return (upperShadow >= InpPinBarRatio * body) &&
          (lowerShadow < body) &&
          IsDowntrend(bar);
}

//--- Bullish Engulfing
bool DetectBullishEngulfing(int bar)
{
   double o0 = iOpen(_Symbol, _Period, bar);
   double c0 = iClose(_Symbol, _Period, bar);
   double o1 = iOpen(_Symbol, _Period, bar + 1);
   double c1 = iClose(_Symbol, _Period, bar + 1);
   
   bool prevBearish = (c1 < o1);
   bool currBullish = (c0 > o0);
   
   double prevBodyH = MathMax(o1, c1);
   double prevBodyL = MathMin(o1, c1);
   double currBodyH = MathMax(o0, c0);
   double currBodyL = MathMin(o0, c0);
   
   return prevBearish && currBullish &&
          (currBodyL <= prevBodyL) &&
          (currBodyH >= prevBodyH) &&
          (MathAbs(c0 - o0) > MathAbs(c1 - o1)) &&
          IsDowntrend(bar + 1);
}

//--- Morning Star (3-candle)
bool DetectMorningStar(int bar)
{
   if(bar + 2 >= iBars(_Symbol, _Period)) return false;
   
   double o2 = iOpen(_Symbol, _Period, bar + 2);
   double h2 = iHigh(_Symbol, _Period, bar + 2);
   double l2 = iLow(_Symbol, _Period, bar + 2);
   double c2 = iClose(_Symbol, _Period, bar + 2);
   
   double o1 = iOpen(_Symbol, _Period, bar + 1);
   double h1 = iHigh(_Symbol, _Period, bar + 1);
   double l1 = iLow(_Symbol, _Period, bar + 1);
   double c1 = iClose(_Symbol, _Period, bar + 1);
   
   double o0 = iOpen(_Symbol, _Period, bar);
   double h0 = iHigh(_Symbol, _Period, bar);
   double l0 = iLow(_Symbol, _Period, bar);
   double c0 = iClose(_Symbol, _Period, bar);
   
   double body2 = MathAbs(c2 - o2), range2 = h2 - l2;
   double body1 = MathAbs(c1 - o1), range1 = h1 - l1;
   double body0 = MathAbs(c0 - o0), range0 = h0 - l0;
   
   if(range2 <= 0 || range1 <= 0 || range0 <= 0) return false;
   
   bool c2Bearish = (c2 < o2) && (body2 / range2 >= InpMinBodyPct);
   bool c1Doji    = (body1 / range1 <= InpDojiMaxBodyPct * 3);  // relaxed for star
   bool c0Bullish = (c0 > o0) && (body0 / range0 >= InpMinBodyPct);
   
   double midBody2 = (o2 + c2) / 2.0;
   
   return c2Bearish && c1Doji && c0Bullish &&
          (c0 > midBody2) &&
          IsDowntrend(bar + 2);
}

//--- Piercing Line
bool DetectPiercingLine(int bar)
{
   double o0 = iOpen(_Symbol, _Period, bar);
   double c0 = iClose(_Symbol, _Period, bar);
   double o1 = iOpen(_Symbol, _Period, bar + 1);
   double c1 = iClose(_Symbol, _Period, bar + 1);
   
   bool prevBearish = (c1 < o1);
   bool currBullish = (c0 > o0);
   
   if(!prevBearish || !currBullish) return false;
   
   double prevBody = o1 - c1;
   if(prevBody <= 0) return false;
   
   bool gapDown = (o0 <= c1);
   double midPrev = c1 + prevBody * InpPiercePct;
   bool pierces = (c0 > midPrev) && (c0 < o1);
   
   return gapDown && pierces && IsDowntrend(bar + 1);
}

//--- Bullish Harami
bool DetectBullishHarami(int bar)
{
   double o0 = iOpen(_Symbol, _Period, bar);
   double h0 = iHigh(_Symbol, _Period, bar);
   double l0 = iLow(_Symbol, _Period, bar);
   double c0 = iClose(_Symbol, _Period, bar);
   double o1 = iOpen(_Symbol, _Period, bar + 1);
   double h1 = iHigh(_Symbol, _Period, bar + 1);
   double l1 = iLow(_Symbol, _Period, bar + 1);
   double c1 = iClose(_Symbol, _Period, bar + 1);
   
   double motherBody  = MathAbs(c1 - o1);
   double motherRange = h1 - l1;
   
   if(motherRange <= 0) return false;
   
   bool motherBearish = (c1 < o1) && (motherBody / motherRange >= InpHaramiMotherPct);
   
   double mBodyH = MathMax(o1, c1);
   double mBodyL = MathMin(o1, c1);
   double cBodyH = MathMax(o0, c0);
   double cBodyL = MathMin(o0, c0);
   
   bool childInside = (c0 > o0) &&
                      (cBodyH <= mBodyH) &&
                      (cBodyL >= mBodyL) &&
                      (MathAbs(c0 - o0) < motherBody);
   
   return motherBearish && childInside && IsDowntrend(bar + 1);
}

//--- Dragonfly Doji (bullish)
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
          (lowerShadow / totalRange >= InpDojiShadowPct) &&
          (upperShadow < body + _Point * 5) &&
          IsDowntrend(bar);
}

//--- Shooting Star (bearish)
bool DetectShootingStar(int bar)
{
   double o = iOpen(_Symbol, _Period, bar);
   double h = iHigh(_Symbol, _Period, bar);
   double l = iLow(_Symbol, _Period, bar);
   double c = iClose(_Symbol, _Period, bar);
   
   double body        = MathAbs(c - o);
   double upperShadow = h - MathMax(o, c);
   double lowerShadow = MathMin(o, c) - l;
   double totalRange  = h - l;
   
   if(totalRange <= 0) return false;
   if(body < _Point) body = _Point;
   
   return (upperShadow >= InpPinBarRatio * body) &&
          (lowerShadow < body) &&
          (upperShadow > totalRange * 0.5) &&
          IsUptrend(bar);
}

//--- Hanging Man (bearish)
bool DetectHangingMan(int bar)
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
   if(body < _Point) body = _Point;
   
   return (lowerShadow >= InpPinBarRatio * body) &&
          (upperShadow < body) &&
          (lowerShadow > totalRange * 0.5) &&
          IsUptrend(bar);
}

//--- Bearish Engulfing
bool DetectBearishEngulfing(int bar)
{
   double o0 = iOpen(_Symbol, _Period, bar);
   double c0 = iClose(_Symbol, _Period, bar);
   double o1 = iOpen(_Symbol, _Period, bar + 1);
   double c1 = iClose(_Symbol, _Period, bar + 1);
   
   bool prevBullish = (c1 > o1);
   bool currBearish = (c0 < o0);
   
   double prevBodyH = MathMax(o1, c1);
   double prevBodyL = MathMin(o1, c1);
   double currBodyH = MathMax(o0, c0);
   double currBodyL = MathMin(o0, c0);
   
   return prevBullish && currBearish &&
          (currBodyH >= prevBodyH) &&
          (currBodyL <= prevBodyL) &&
          (MathAbs(c0 - o0) > MathAbs(c1 - o1)) &&
          IsUptrend(bar + 1);
}

//--- Evening Star (3-candle)
bool DetectEveningStar(int bar)
{
   if(bar + 2 >= iBars(_Symbol, _Period)) return false;
   
   double o2 = iOpen(_Symbol, _Period, bar + 2);
   double h2 = iHigh(_Symbol, _Period, bar + 2);
   double l2 = iLow(_Symbol, _Period, bar + 2);
   double c2 = iClose(_Symbol, _Period, bar + 2);
   
   double o1 = iOpen(_Symbol, _Period, bar + 1);
   double h1 = iHigh(_Symbol, _Period, bar + 1);
   double l1 = iLow(_Symbol, _Period, bar + 1);
   double c1 = iClose(_Symbol, _Period, bar + 1);
   
   double o0 = iOpen(_Symbol, _Period, bar);
   double h0 = iHigh(_Symbol, _Period, bar);
   double l0 = iLow(_Symbol, _Period, bar);
   double c0 = iClose(_Symbol, _Period, bar);
   
   double body2 = MathAbs(c2 - o2), range2 = h2 - l2;
   double body1 = MathAbs(c1 - o1), range1 = h1 - l1;
   double body0 = MathAbs(c0 - o0), range0 = h0 - l0;
   
   if(range2 <= 0 || range1 <= 0 || range0 <= 0) return false;
   
   bool c2Bullish = (c2 > o2) && (body2 / range2 >= InpMinBodyPct);
   bool c1Doji    = (body1 / range1 <= InpDojiMaxBodyPct * 3);
   bool c0Bearish = (c0 < o0) && (body0 / range0 >= InpMinBodyPct);
   
   double midBody2 = (o2 + c2) / 2.0;
   
   return c2Bullish && c1Doji && c0Bearish &&
          (c0 < midBody2) &&
          IsUptrend(bar + 2);
}

//--- Dark Cloud Cover
bool DetectDarkCloudCover(int bar)
{
   double o0 = iOpen(_Symbol, _Period, bar);
   double c0 = iClose(_Symbol, _Period, bar);
   double o1 = iOpen(_Symbol, _Period, bar + 1);
   double c1 = iClose(_Symbol, _Period, bar + 1);
   
   bool prevBullish = (c1 > o1);
   bool currBearish = (c0 < o0);
   
   if(!prevBullish || !currBearish) return false;
   
   double prevBody = c1 - o1;
   if(prevBody <= 0) return false;
   
   bool gapUp = (o0 >= c1);
   double midPrev = c1 - prevBody * InpPiercePct;
   bool pierces = (c0 < midPrev) && (c0 > o1);
   
   return gapUp && pierces && IsUptrend(bar + 1);
}

//--- Bearish Harami
bool DetectBearishHarami(int bar)
{
   double o0 = iOpen(_Symbol, _Period, bar);
   double h0 = iHigh(_Symbol, _Period, bar);
   double l0 = iLow(_Symbol, _Period, bar);
   double c0 = iClose(_Symbol, _Period, bar);
   double o1 = iOpen(_Symbol, _Period, bar + 1);
   double h1 = iHigh(_Symbol, _Period, bar + 1);
   double l1 = iLow(_Symbol, _Period, bar + 1);
   double c1 = iClose(_Symbol, _Period, bar + 1);
   
   double motherBody  = MathAbs(c1 - o1);
   double motherRange = h1 - l1;
   
   if(motherRange <= 0) return false;
   
   bool motherBullish = (c1 > o1) && (motherBody / motherRange >= InpHaramiMotherPct);
   
   double mBodyH = MathMax(o1, c1);
   double mBodyL = MathMin(o1, c1);
   double cBodyH = MathMax(o0, c0);
   double cBodyL = MathMin(o0, c0);
   
   bool childInside = (c0 < o0) &&
                      (cBodyH <= mBodyH) &&
                      (cBodyL >= mBodyL) &&
                      (MathAbs(c0 - o0) < motherBody);
   
   return motherBullish && childInside && IsUptrend(bar + 1);
}

//--- Gravestone Doji (bearish)
bool DetectGravestoneDoji(int bar)
{
   double o = iOpen(_Symbol, _Period, bar);
   double h = iHigh(_Symbol, _Period, bar);
   double l = iLow(_Symbol, _Period, bar);
   double c = iClose(_Symbol, _Period, bar);
   
   double body        = MathAbs(c - o);
   double totalRange  = h - l;
   double upperShadow = h - MathMax(o, c);
   double lowerShadow = MathMin(o, c) - l;
   
   if(totalRange <= 0) return false;
   
   return (body / totalRange <= InpDojiMaxBodyPct) &&
          (upperShadow / totalRange >= InpDojiShadowPct) &&
          (lowerShadow < body + _Point * 5) &&
          IsUptrend(bar);
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
   
   //--- Check max trades
   if(CountOpenPositions() + CountPendingOrders() >= InpMaxOpenTrades)
      return;
   
   //--- Analyze completed bar (bar index 1)
   int bar = 1;
   
   double barHigh = iHigh(_Symbol, _Period, bar);
   double barLow  = iLow(_Symbol, _Period, bar);
   double barOpen = iOpen(_Symbol, _Period, bar);
   double barClose = iClose(_Symbol, _Period, bar);
   
   //=== BULLISH PATTERNS → BUY STOP ===
   
   //--- Hammer
   if(InpUseHammer && DetectHammer(bar))
   {
      PlaceBuyStop(barHigh + _Point, barLow, "Hammer");
      return;
   }
   
   //--- Inverted Hammer (check bar 2 for pattern, bar 1 as confirmation)
   if(InpUseInvHammer && DetectInvertedHammer(bar + 1))
   {
      // Confirmation: bar 1 is bullish and closes above inverted hammer's high
      double ihHigh = iHigh(_Symbol, _Period, bar + 1);
      if(barClose > barOpen && barClose > ihHigh)
      {
         PlaceBuyStop(barHigh + _Point, iLow(_Symbol, _Period, bar + 1), "Inv Hammer");
         return;
      }
   }
   
   //--- Bullish Engulfing
   if(InpUseBullEngulf && DetectBullishEngulfing(bar))
   {
      PlaceBuyStop(barHigh + _Point, barLow, "Bull Engulfing");
      return;
   }
   
   //--- Morning Star (bar is the 3rd candle)
   if(InpUseMorningStar && DetectMorningStar(bar))
   {
      double lowestLow = MathMin(MathMin(iLow(_Symbol, _Period, bar),
                                          iLow(_Symbol, _Period, bar+1)),
                                  iLow(_Symbol, _Period, bar+2));
      PlaceBuyStop(barHigh + _Point, lowestLow, "Morning Star");
      return;
   }
   
   //--- Piercing Line
   if(InpUsePiercingLine && DetectPiercingLine(bar))
   {
      PlaceBuyStop(barHigh + _Point, iLow(_Symbol, _Period, bar + 1), "Piercing Line");
      return;
   }
   
   //--- Bullish Harami (bar is child; check bar+1 confirmation needed per PRD)
   if(InpUseBullHarami && DetectBullishHarami(bar))
   {
      PlaceBuyStop(barHigh + _Point, iLow(_Symbol, _Period, bar + 1), "Bull Harami");
      return;
   }
   
   //--- Dragonfly Doji
   if(InpUseDragonflyDoji && DetectDragonflyDoji(bar))
   {
      PlaceBuyStop(barHigh + _Point, barLow, "Dragonfly Doji");
      return;
   }
   
   //=== BEARISH PATTERNS → SELL STOP ===
   
   //--- Shooting Star
   if(InpUseShootStar && DetectShootingStar(bar))
   {
      PlaceSellStop(barLow - _Point, barHigh, "Shooting Star");
      return;
   }
   
   //--- Hanging Man (check bar 2, bar 1 as confirmation)
   if(InpUseHangingMan && DetectHangingMan(bar + 1))
   {
      double hmHigh = iHigh(_Symbol, _Period, bar + 1);
      double hmLow  = iLow(_Symbol, _Period, bar + 1);
      if(barClose < barOpen && barClose < hmLow)
      {
         PlaceSellStop(barLow - _Point, hmHigh, "Hanging Man");
         return;
      }
   }
   
   //--- Bearish Engulfing
   if(InpUseBearEngulf && DetectBearishEngulfing(bar))
   {
      PlaceSellStop(barLow - _Point, barHigh, "Bear Engulfing");
      return;
   }
   
   //--- Evening Star
   if(InpUseEveningStar && DetectEveningStar(bar))
   {
      double highestHigh = MathMax(MathMax(iHigh(_Symbol, _Period, bar),
                                            iHigh(_Symbol, _Period, bar+1)),
                                    iHigh(_Symbol, _Period, bar+2));
      PlaceSellStop(barLow - _Point, highestHigh, "Evening Star");
      return;
   }
   
   //--- Dark Cloud Cover
   if(InpUseDarkCloud && DetectDarkCloudCover(bar))
   {
      PlaceSellStop(barLow - _Point, iHigh(_Symbol, _Period, bar + 1), "Dark Cloud");
      return;
   }
   
   //--- Bearish Harami
   if(InpUseBearHarami && DetectBearishHarami(bar))
   {
      PlaceSellStop(barLow - _Point, iHigh(_Symbol, _Period, bar + 1), "Bear Harami");
      return;
   }
   
   //--- Gravestone Doji
   if(InpUseGravestDoji && DetectGravestoneDoji(bar))
   {
      PlaceSellStop(barLow - _Point, barHigh, "Gravestone Doji");
      return;
   }
}
//+------------------------------------------------------------------+
