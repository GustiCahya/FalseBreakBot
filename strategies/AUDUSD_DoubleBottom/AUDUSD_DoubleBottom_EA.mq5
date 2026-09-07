//+------------------------------------------------------------------+
//|                            AUDUSD_DoubleBottom_EA.mq5             |
//|                        Double Bottom + S/R + Rejection Entry       |
//|                                                                    |
//|  Strategy:                                                         |
//|  1. Identify Double Bottom pattern (two equal swing lows)          |
//|  2. Detect Strong Support & Resistance zones                       |
//|  3. Wait for rejection candle at the 2nd bottom                    |
//|  4. Entry:  Buy Stop above rejection candle's high                 |
//|  5. SL:     Nearest strong support below the 2nd bottom            |
//|  6. TP:     Nearest strong resistance above entry                  |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Double Bottom Strategy"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//=== GENERAL SETTINGS ===
input string   Sep0                = "=== General Settings ===";            // ---
input double   InpLotSize          = 0.01;     // Fixed Lot Size
input int      InpMagicNumber      = 20260908; // Magic Number
input int      InpMaxOpenTrades    = 2;        // Max Simultaneous Open Trades
input double   InpSLBufferPips     = 5.0;      // SL Buffer below support (pips)
input double   InpMinRR            = 1.5;      // Min Risk-Reward to take trade

//=== DOUBLE BOTTOM DETECTION ===
input string   Sep1                = "=== Double Bottom Settings ===";      // ---
input int      InpSwingLookback    = 5;        // Bars each side to confirm swing
input int      InpPatternBars      = 80;       // Max bars to look back for pattern
input double   InpTroughTolerance  = 0.005;    // Trough equality tolerance (0.5%)
input int      InpMinBarsBetween   = 10;       // Min bars between two bottoms

//=== SUPPORT / RESISTANCE ===
input string   Sep2                = "=== S/R Detection ===";              // ---
input int      InpSRLookback       = 200;      // Bars to scan for S/R zones
input int      InpSRSwingN         = 3;        // Bars each side for S/R swing point
input double   InpSRZonePips       = 15.0;     // Zone width in pips (touches within this merge)
input int      InpMinTouches       = 2;        // Min touches to be "Strong" S/R

//=== REJECTION CANDLE ===
input string   Sep3                = "=== Rejection Candle ===";           // ---
input double   InpPinBarRatio      = 1.5;      // Min lower-shadow / body ratio for pin bar
input double   InpDojiMaxBodyPct   = 0.15;     // Doji: max body % of total range
input double   InpDojiShadowPct    = 0.60;     // Doji: min lower shadow % of total range
input double   InpRejZonePips      = 20.0;     // Max distance from 1st bottom to consider rejection

//--- Global objects
CTrade   trade;
datetime lastBarTime = 0;

//--- S/R level storage
#define MAX_SR_LEVELS 50
double   gSRLevels[MAX_SR_LEVELS];
int      gSRTouches[MAX_SR_LEVELS];
int      gSRCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   Print("DoubleBottom EA initialized | Symbol=", _Symbol,
         " | TF=", EnumToString(_Period),
         " | MinRR=", DoubleToString(InpMinRR, 2));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("DoubleBottom EA deinitialized. Reason: ", reason);
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
//| Count active positions + pending orders by this EA               |
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
//| SWING POINT DETECTION                                             |
//+------------------------------------------------------------------+
bool IsSwingHigh(int bar, int n)
{
   int totalBars = iBars(_Symbol, _Period);
   if(bar - n < 0 || bar + n >= totalBars) return false;
   for(int k = 1; k <= n; k++)
   {
      if(iHigh(_Symbol, _Period, bar) <= iHigh(_Symbol, _Period, bar + k)) return false;
      if(iHigh(_Symbol, _Period, bar) <= iHigh(_Symbol, _Period, bar - k)) return false;
   }
   return true;
}

bool IsSwingLow(int bar, int n)
{
   int totalBars = iBars(_Symbol, _Period);
   if(bar - n < 0 || bar + n >= totalBars) return false;
   for(int k = 1; k <= n; k++)
   {
      if(iLow(_Symbol, _Period, bar) >= iLow(_Symbol, _Period, bar + k)) return false;
      if(iLow(_Symbol, _Period, bar) >= iLow(_Symbol, _Period, bar - k)) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//|  BUILD STRONG SUPPORT / RESISTANCE ZONES                          |
//|                                                                    |
//|  Logic:                                                            |
//|  1. Scan InpSRLookback bars for all swing highs + swing lows       |
//|  2. Cluster nearby swing levels within InpSRZonePips into zones    |
//|  3. Count "touches" per zone                                       |
//|  4. Only keep zones with touches >= InpMinTouches ("Strong")       |
//|                                                                    |
//|  Stored in gSRLevels[] / gSRTouches[] / gSRCount                  |
//+------------------------------------------------------------------+
void BuildSRZones()
{
   gSRCount = 0;
   double pip = PipValue();
   double zoneWidth = InpSRZonePips * pip;
   int totalBars = iBars(_Symbol, _Period);
   int lookback  = MathMin(InpSRLookback, totalBars - InpSRSwingN - 1);

   //--- Step 1: Collect all swing levels (raw)
   double rawLevels[500];
   int    rawCount = 0;

   for(int bar = InpSRSwingN; bar <= lookback && rawCount < 500; bar++)
   {
      if(IsSwingHigh(bar, InpSRSwingN))
         rawLevels[rawCount++] = iHigh(_Symbol, _Period, bar);
      if(IsSwingLow(bar, InpSRSwingN) && rawCount < 500)
         rawLevels[rawCount++] = iLow(_Symbol, _Period, bar);
   }

   if(rawCount == 0) return;

   //--- Step 2: Sort raw levels ascending (simple insertion sort)
   for(int i = 1; i < rawCount; i++)
   {
      double key = rawLevels[i];
      int j = i - 1;
      while(j >= 0 && rawLevels[j] > key)
      {
         rawLevels[j + 1] = rawLevels[j];
         j--;
      }
      rawLevels[j + 1] = key;
   }

   //--- Step 3: Cluster into zones
   double zoneLevels[500];
   int    zoneTouches[500];
   double zoneSum[500];
   int    zCount = 0;

   zoneLevels[0]  = rawLevels[0];
   zoneTouches[0] = 1;
   zoneSum[0]     = rawLevels[0];
   zCount = 1;

   for(int i = 1; i < rawCount; i++)
   {
      //--- If this level is within zoneWidth of the current cluster, merge
      if(rawLevels[i] - (zoneSum[zCount-1] / zoneTouches[zCount-1]) <= zoneWidth)
      {
         zoneTouches[zCount-1]++;
         zoneSum[zCount-1] += rawLevels[i];
         zoneLevels[zCount-1] = zoneSum[zCount-1] / zoneTouches[zCount-1]; // average
      }
      else
      {
         //--- Start new cluster
         if(zCount < 500)
         {
            zoneLevels[zCount]  = rawLevels[i];
            zoneTouches[zCount] = 1;
            zoneSum[zCount]     = rawLevels[i];
            zCount++;
         }
      }
   }

   //--- Step 4: Keep only "strong" zones (>= InpMinTouches)
   for(int i = 0; i < zCount && gSRCount < MAX_SR_LEVELS; i++)
   {
      if(zoneTouches[i] >= InpMinTouches)
      {
         gSRLevels[gSRCount]  = zoneLevels[i];
         gSRTouches[gSRCount] = zoneTouches[i];
         gSRCount++;
      }
   }

   Print("S/R Zones built: ", gSRCount, " strong levels from ", rawCount, " raw swing points");
}

//+------------------------------------------------------------------+
//| Find nearest strong SUPPORT below a given price                   |
//+------------------------------------------------------------------+
double FindNearestSupportBelow(double price)
{
   double bestLevel = -1;
   int    bestTouches = 0;
   for(int i = 0; i < gSRCount; i++)
   {
      if(gSRLevels[i] < price)
      {
         //--- Pick closest below, or if same distance pick most touches
         if(bestLevel < 0 || gSRLevels[i] > bestLevel)
         {
            bestLevel   = gSRLevels[i];
            bestTouches = gSRTouches[i];
         }
      }
   }
   return bestLevel;
}

//+------------------------------------------------------------------+
//| Find nearest strong RESISTANCE above a given price                |
//+------------------------------------------------------------------+
double FindNearestResistanceAbove(double price)
{
   double bestLevel = -1;
   int    bestTouches = 0;
   for(int i = 0; i < gSRCount; i++)
   {
      if(gSRLevels[i] > price)
      {
         //--- Pick closest above
         if(bestLevel < 0 || gSRLevels[i] < bestLevel)
         {
            bestLevel   = gSRLevels[i];
            bestTouches = gSRTouches[i];
         }
      }
   }
   return bestLevel;
}

//+------------------------------------------------------------------+
//| REJECTION CANDLE DETECTION at a given bar                         |
//|                                                                    |
//| Checks for:                                                        |
//|  - Hammer (long lower shadow, small body at top)                   |
//|  - Dragonfly Doji (open ≈ close at top, long lower shadow)         |
//|  - Bullish pin bar (any candle with dominant lower wick rejection)  |
//+------------------------------------------------------------------+
bool IsRejectionCandle(int bar)
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

   //--- Dragonfly Doji
   if(body / totalRange <= InpDojiMaxBodyPct &&
      lowerShadow / totalRange >= InpDojiShadowPct &&
      upperShadow < body + _Point * 5)
      return true;

   //--- Hammer / Pin Bar
   if(body < _Point) body = _Point;  // prevent div-by-zero
   if(lowerShadow >= InpPinBarRatio * body &&
      upperShadow < body &&
      lowerShadow > totalRange * 0.5)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| DOUBLE BOTTOM DETECTION + REJECTION at 2nd bottom                 |
//|                                                                    |
//|  Scans for two swing lows that are approximately equal.            |
//|  Then checks that bar 1 (latest completed bar) is a rejection      |
//|  candle whose low is near the second bottom level.                 |
//|                                                                    |
//|  Returns: true + fills entryPrice, slPrice, tpPrice                |
//+------------------------------------------------------------------+
bool DetectDoubleBottomSetup(double &entryPrice, double &slPrice, double &tpPrice)
{
   double pip       = PipValue();
   double rejZone   = InpRejZonePips * pip;
   int    totalBars = iBars(_Symbol, _Period);
   int    endBar    = MathMin(InpPatternBars, totalBars - InpSwingLookback - 1);

   //--- Bar 1 must be a rejection candle first (fail fast)
   if(!IsRejectionCandle(1)) return false;

   double barLow  = iLow(_Symbol, _Period, 1);
   double barHigh = iHigh(_Symbol, _Period, 1);

   //--- Collect swing lows within pattern lookback (bar indexes: higher = older)
   int swingLowBar[30];
   int slCount = 0;
   for(int bar = InpSwingLookback + 1; bar <= endBar && slCount < 30; bar++)
   {
      if(IsSwingLow(bar, InpSwingLookback))
         swingLowBar[slCount++] = bar;
   }

   if(slCount < 1) return false;  // Need at least 1 historical swing low; bar 1 area is the 2nd bottom

   //--- Check each swing low as potential 1st bottom
   for(int i = 0; i < slCount; i++)
   {
      int    idxB1 = swingLowBar[i];
      double lowB1 = iLow(_Symbol, _Period, idxB1);

      //--- Min bars between the two bottoms
      if(idxB1 < InpMinBarsBetween) continue;

      //--- Two bottoms must be approximately equal
      double diff = MathAbs(lowB1 - barLow) / MathMin(lowB1, barLow);
      if(diff > InpTroughTolerance) continue;

      //--- Rejection candle low must be near the 1st bottom level
      if(MathAbs(barLow - lowB1) > rejZone) continue;

      //--- Ensure there was a swing high between the two bottoms (the "valley")
      double neckline = -1e10;
      for(int j = 1; j < idxB1; j++)
      {
         double h = iHigh(_Symbol, _Period, j);
         if(h > neckline) neckline = h;
      }

      //--- Neckline must be meaningfully above the bottoms
      double bottomAvg = (lowB1 + barLow) / 2.0;
      if(neckline <= bottomAvg) continue;

      //--- ENTRY: Buy Stop above rejection candle's high
      entryPrice = NormalizeDouble(barHigh + _Point, _Digits);

      //--- SL: Nearest strong support BELOW the 2nd bottom
      double support = FindNearestSupportBelow(barLow);
      if(support <= 0)
      {
         //--- Fallback: use 2nd bottom low minus buffer
         support = barLow;
      }
      slPrice = NormalizeDouble(support - InpSLBufferPips * pip, _Digits);

      //--- TP: Nearest strong resistance ABOVE the entry
      double resistance = FindNearestResistanceAbove(entryPrice);
      if(resistance <= 0)
      {
         //--- Fallback: use neckline as target
         resistance = neckline;
      }
      tpPrice = NormalizeDouble(resistance, _Digits);

      //--- Check minimum RR
      double slDist = entryPrice - slPrice;
      double tpDist = tpPrice - entryPrice;
      if(slDist <= 0 || tpDist <= 0) continue;
      double rr = tpDist / slDist;
      if(rr < InpMinRR) continue;

      Print("Double Bottom detected! B1=bar", idxB1, " Low=", lowB1,
            " | B2=bar1 Low=", barLow,
            " | Neckline=", neckline,
            " | Support=", support, " (", gSRCount, " S/R zones)",
            " | Resistance=", resistance,
            " | RR=1:", DoubleToString(rr, 2));
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Place Buy Stop Order                                              |
//+------------------------------------------------------------------+
bool PlaceBuyStop(double entryPrice, double slPrice, double tpPrice)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   //--- Buy Stop must be above current ask
   if(entryPrice <= ask)
   {
      Print("BUY STOP skipped (entry <= ask): Entry=", entryPrice, " Ask=", ask);
      return false;
   }

   //--- Expire after 3 bars (chart pattern = longer formation, give more time)
   datetime expiry = TimeCurrent() + PeriodSeconds(_Period) * 3;

   if(trade.BuyStop(InpLotSize, entryPrice, _Symbol, slPrice, tpPrice,
                    ORDER_TIME_SPECIFIED, expiry, "DoubleBottom"))
   {
      double slDist = entryPrice - slPrice;
      double tpDist = tpPrice - entryPrice;
      double rr     = (slDist > 0) ? tpDist / slDist : 0;

      Print("BUY STOP [DoubleBottom] Entry=", entryPrice,
            " SL=", slPrice, " TP=", tpPrice,
            " RR=1:", DoubleToString(rr, 2));
      return true;
   }

   Print("BUY STOP FAILED [DoubleBottom] Error=", GetLastError());
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

   //--- Rebuild S/R zones on each new bar (relatively cheap with capped lookback)
   BuildSRZones();

   //--- Check for Double Bottom + Rejection setup
   double entryPrice = 0, slPrice = 0, tpPrice = 0;
   if(DetectDoubleBottomSetup(entryPrice, slPrice, tpPrice))
   {
      PlaceBuyStop(entryPrice, slPrice, tpPrice);
   }
}
//+------------------------------------------------------------------+
