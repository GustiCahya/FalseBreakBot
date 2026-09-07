//+------------------------------------------------------------------+
//|                         ChartPattern_Reversal_EA.mq5             |
//|                        Chart Pattern Reversal Expert Advisor       |
//|                        All 8 Patterns Combined                    |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Chart Pattern Reversal"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//=== GENERAL SETTINGS ===
input string   Sep0               = "=== General Settings ===";           // ---
input double   InpLotSize         = 0.01;    // Fixed Lot Size
input double   InpRiskReward      = 2.0;     // Risk-Reward Ratio (e.g. 2.0 = 1:2)
input double   InpSLBufferPips    = 10.0;    // Stop Loss Buffer (pips)
input int      InpMagicNumber     = 20260907;// Magic Number
input int      InpMaxOpenTrades   = 2;       // Max simultaneous open trades

//=== PATTERN LOOKBACK ===
input string   Sep1               = "=== Pattern Lookback ===";           // ---
input int      InpSwingLookback   = 5;       // Bars each side to confirm swing high/low
input int      InpPatternBars     = 80;      // Max bars to look back for pattern formation
input double   InpPeakTolerance   = 0.005;   // Peak/Trough equality tolerance (0.5%)
input double   InpShoulderTol     = 0.030;   // H&S Shoulder tolerance (3% of Head)

//=== BULLISH PATTERNS ON/OFF ===
input string   Sep2               = "=== Bullish Patterns ===";           // ---
input bool     InpUseInvHnS       = true;    // Use Inverse Head & Shoulders
input bool     InpUseDoubleBottom = true;    // Use Double Bottom
input bool     InpUseTripleBottom = false;   // Use Triple Bottom
input bool     InpUseFallingWedge = true;    // Use Falling Wedge

//=== BEARISH PATTERNS ON/OFF ===
input string   Sep3               = "=== Bearish Patterns ===";           // ---
input bool     InpUseHnS          = true;    // Use Head & Shoulders
input bool     InpUseDoubleTop    = true;    // Use Double Top
input bool     InpUseTripleTop    = false;   // Use Triple Top
input bool     InpUseRisingWedge  = true;    // Use Rising Wedge

//--- Global objects
CTrade   trade;
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   Print("ChartPattern Reversal EA initialized | Symbol=", _Symbol,
         " | TF=", EnumToString(_Period),
         " | RR=1:", DoubleToString(InpRiskReward, 2));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("ChartPattern Reversal EA deinitialized. Reason: ", reason);
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
//| Get pip value for current symbol                                  |
//+------------------------------------------------------------------+
double PipValue()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return (digits == 3 || digits == 5) ? _Point * 10 : _Point;
}

//+------------------------------------------------------------------+
//| Place Buy Market Order                                            |
//+------------------------------------------------------------------+
bool PlaceBuy(double slPrice, double measuredMoveTarget, string patternName)
{
   double pip    = PipValue();
   double buffer = InpSLBufferPips * pip;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl  = NormalizeDouble(slPrice - buffer, _Digits);
   double slDist = ask - sl;
   if(slDist <= 0)
   {
      Print("BUY skipped (SL dist <= 0): ", patternName);
      return false;
   }

   //--- Use measured move if it gives better RR, else use RR ratio
   double tpByRR      = ask + slDist * InpRiskReward;
   double tpMeasured  = measuredMoveTarget;
   double tp = (tpMeasured > ask && tpMeasured > tpByRR) ? tpMeasured : tpByRR;
   tp = NormalizeDouble(tp, _Digits);

   if(trade.Buy(InpLotSize, _Symbol, ask, sl, tp, patternName))
   {
      Print("BUY [", patternName, "] Ask=", ask, " SL=", sl, " TP=", tp,
            " RR=1:", DoubleToString((tp - ask) / slDist, 2));
      return true;
   }
   Print("BUY FAILED [", patternName, "] Error=", GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| Place Sell Market Order                                           |
//+------------------------------------------------------------------+
bool PlaceSell(double slPrice, double measuredMoveTarget, string patternName)
{
   double pip    = PipValue();
   double buffer = InpSLBufferPips * pip;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl  = NormalizeDouble(slPrice + buffer, _Digits);
   double slDist = sl - bid;
   if(slDist <= 0)
   {
      Print("SELL skipped (SL dist <= 0): ", patternName);
      return false;
   }

   //--- Use measured move if it gives better RR, else use RR ratio
   double tpByRR     = bid - slDist * InpRiskReward;
   double tpMeasured = measuredMoveTarget;
   double tp = (tpMeasured < bid && tpMeasured < tpByRR) ? tpMeasured : tpByRR;
   tp = NormalizeDouble(tp, _Digits);

   if(trade.Sell(InpLotSize, _Symbol, bid, sl, tp, patternName))
   {
      Print("SELL [", patternName, "] Bid=", bid, " SL=", sl, " TP=", tp,
            " RR=1:", DoubleToString((bid - tp) / slDist, 2));
      return true;
   }
   Print("SELL FAILED [", patternName, "] Error=", GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| SWING POINT HELPERS                                               |
//+------------------------------------------------------------------+
bool IsSwingHigh(int bar)
{
   int n = InpSwingLookback;
   for(int k = 1; k <= n; k++)
   {
      if(iHigh(_Symbol, _Period, bar) <= iHigh(_Symbol, _Period, bar + k)) return false;
      if(bar - k >= 0 &&
         iHigh(_Symbol, _Period, bar) <= iHigh(_Symbol, _Period, bar - k)) return false;
   }
   return true;
}

bool IsSwingLow(int bar)
{
   int n = InpSwingLookback;
   for(int k = 1; k <= n; k++)
   {
      if(iLow(_Symbol, _Period, bar) >= iLow(_Symbol, _Period, bar + k)) return false;
      if(bar - k >= 0 &&
         iLow(_Symbol, _Period, bar) >= iLow(_Symbol, _Period, bar - k)) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Linear Regression: returns slope & intercept for swing bar array |
//+------------------------------------------------------------------+
bool LinReg(const int &idx[], int count, bool useHigh, double &slope, double &intercept)
{
   if(count < 2) return false;
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   for(int k = 0; k < count; k++)
   {
      double x = idx[k];
      double y = useHigh ? iHigh(_Symbol, _Period, idx[k]) : iLow(_Symbol, _Period, idx[k]);
      sumX  += x;
      sumY  += y;
      sumXY += x * y;
      sumX2 += x * x;
   }
   double denom = count * sumX2 - sumX * sumX;
   if(MathAbs(denom) < 1e-10) return false;
   slope     = (count * sumXY - sumX * sumY) / denom;
   intercept = (sumY - slope * sumX) / count;
   return true;
}

//+------------------------------------------------------------------+
//| PATTERN DETECTION FUNCTIONS                                        |
//+------------------------------------------------------------------+

//--- Collect swing highs / lows from bar range [startBar, endBar]
//    Returns count, fills idx array. Bars in EA are inverted (higher index = older)
int CollectSwingHighs(int startBar, int endBar, int &idx[], int maxCount)
{
   int count = 0;
   for(int b = startBar; b <= endBar && count < maxCount; b++)
   {
      if(IsSwingHigh(b)) idx[count++] = b;
   }
   return count;
}

int CollectSwingLows(int startBar, int endBar, int &idx[], int maxCount)
{
   int count = 0;
   for(int b = startBar; b <= endBar && count < maxCount; b++)
   {
      if(IsSwingLow(b)) idx[count++] = b;
   }
   return count;
}

//+------------------------------------------------------------------+
//| HEAD AND SHOULDERS (Bearish)                                      |
//| Returns true and fills slPrice + measuredTarget if found          |
//+------------------------------------------------------------------+
bool DetectHnS(int bar, double &slPrice, double &measuredTarget)
{
   int totalBars = iBars(_Symbol, _Period);
   int endBar    = MathMin(bar + InpPatternBars, totalBars - InpSwingLookback - 1);

   int highIdx[20];
   int lowIdx[20];
   int hCount = CollectSwingHighs(bar + InpSwingLookback + 1, endBar, highIdx, 20);
   int lCount = CollectSwingLows (bar + InpSwingLookback + 1, endBar, lowIdx,  20);

   if(hCount < 3 || lCount < 2) return false;

   //--- Reverse so oldest swing is at index 0
   for(int a = hCount - 1; a >= 2; a--)
   {
      for(int b = a - 1; b >= 1; b--)
      {
         for(int c = b - 1; c >= 0; c--)
         {
            // highIdx[a] = oldest (Left Shoulder), highIdx[b] = Head, highIdx[c] = Right Shoulder (newest)
            int   idxLS   = highIdx[a];
            int   idxHead = highIdx[b];
            int   idxRS   = highIdx[c];

            double hLS   = iHigh(_Symbol, _Period, idxLS);
            double hHead = iHigh(_Symbol, _Period, idxHead);
            double hRS   = iHigh(_Symbol, _Period, idxRS);

            //--- Head must be highest
            if(hHead <= hLS || hHead <= hRS) continue;

            //--- Shoulders roughly equal
            double shoulderDiff = MathAbs(hLS - hRS) / hHead;
            if(shoulderDiff > InpShoulderTol) continue;

            //--- Find neckline lows between LS-Head and Head-RS
            double neckLeft = 1e10, neckRight = 1e10;
            for(int j = idxLS; j >= idxHead; j--)
               if(iLow(_Symbol, _Period, j) < neckLeft) neckLeft = iLow(_Symbol, _Period, j);
            for(int j = idxHead; j >= idxRS; j--)
               if(iLow(_Symbol, _Period, j) < neckRight) neckRight = iLow(_Symbol, _Period, j);

            double neckline = (neckLeft + neckRight) / 2.0;

            //--- Confirmation: current bar (bar=1) close below neckline
            if(iClose(_Symbol, _Period, bar) < neckline)
            {
               //--- SL = above Right Shoulder high
               slPrice = hRS;
               //--- Measured move = Head to Neckline, projected below breakout
               double patternHeight = hHead - neckline;
               measuredTarget = neckline - patternHeight;
               return true;
            }
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| INVERSE HEAD AND SHOULDERS (Bullish)                              |
//+------------------------------------------------------------------+
bool DetectInvHnS(int bar, double &slPrice, double &measuredTarget)
{
   int totalBars = iBars(_Symbol, _Period);
   int endBar    = MathMin(bar + InpPatternBars, totalBars - InpSwingLookback - 1);

   int lowIdx[20];
   int highIdx[20];
   int lCount = CollectSwingLows (bar + InpSwingLookback + 1, endBar, lowIdx,  20);
   int hCount = CollectSwingHighs(bar + InpSwingLookback + 1, endBar, highIdx, 20);

   if(lCount < 3 || hCount < 2) return false;

   for(int a = lCount - 1; a >= 2; a--)
   {
      for(int b = a - 1; b >= 1; b--)
      {
         for(int c = b - 1; c >= 0; c--)
         {
            // lowIdx[a] = oldest (Left Shoulder), lowIdx[b] = Head, lowIdx[c] = Right Shoulder
            int   idxLS   = lowIdx[a];
            int   idxHead = lowIdx[b];
            int   idxRS   = lowIdx[c];

            double lLS   = iLow(_Symbol, _Period, idxLS);
            double lHead = iLow(_Symbol, _Period, idxHead);
            double lRS   = iLow(_Symbol, _Period, idxRS);

            //--- Head must be lowest
            if(lHead >= lLS || lHead >= lRS) continue;

            //--- Shoulders roughly equal
            double shoulderDiff = MathAbs(lLS - lRS) / MathMin(lLS, lRS);
            if(shoulderDiff > InpShoulderTol) continue;

            //--- Find neckline highs between LS-Head and Head-RS
            double neckLeft = -1e10, neckRight = -1e10;
            for(int j = idxLS; j >= idxHead; j--)
               if(iHigh(_Symbol, _Period, j) > neckLeft) neckLeft = iHigh(_Symbol, _Period, j);
            for(int j = idxHead; j >= idxRS; j--)
               if(iHigh(_Symbol, _Period, j) > neckRight) neckRight = iHigh(_Symbol, _Period, j);

            double neckline = (neckLeft + neckRight) / 2.0;

            //--- Confirmation: current close above neckline
            if(iClose(_Symbol, _Period, bar) > neckline)
            {
               //--- SL = below Right Shoulder low
               slPrice = lRS;
               //--- Measured move = Neckline to Head depth, projected above breakout
               double patternHeight = neckline - lHead;
               measuredTarget = neckline + patternHeight;
               return true;
            }
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| DOUBLE TOP (Bearish)                                              |
//+------------------------------------------------------------------+
bool DetectDoubleTop(int bar, double &slPrice, double &measuredTarget)
{
   int totalBars = iBars(_Symbol, _Period);
   int endBar    = MathMin(bar + InpPatternBars, totalBars - InpSwingLookback - 1);

   int highIdx[20];
   int hCount = CollectSwingHighs(bar + InpSwingLookback + 1, endBar, highIdx, 20);

   if(hCount < 2) return false;

   //--- Check any two peaks (most recent first)
   for(int a = 0; a < hCount - 1; a++)
   {
      for(int b = a + 1; b < hCount; b++)
      {
         int   idxP1 = highIdx[b]; // older peak
         int   idxP2 = highIdx[a]; // newer peak
         double h1   = iHigh(_Symbol, _Period, idxP1);
         double h2   = iHigh(_Symbol, _Period, idxP2);

         //--- Peaks must be nearly equal
         double diff = MathAbs(h1 - h2) / MathMax(h1, h2);
         if(diff > InpPeakTolerance) continue;

         //--- Neckline = lowest low between the two peaks (scan range)
         double neckline = 1e10;
         for(int j = idxP2; j <= idxP1; j++)
            if(iLow(_Symbol, _Period, j) < neckline) neckline = iLow(_Symbol, _Period, j);

         //--- Confirmation: close below neckline
         if(iClose(_Symbol, _Period, bar) < neckline)
         {
            slPrice        = MathMax(h1, h2);
            double height  = MathMax(h1, h2) - neckline;
            measuredTarget = neckline - height;
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| DOUBLE BOTTOM (Bullish)                                           |
//+------------------------------------------------------------------+
bool DetectDoubleBottom(int bar, double &slPrice, double &measuredTarget)
{
   int totalBars = iBars(_Symbol, _Period);
   int endBar    = MathMin(bar + InpPatternBars, totalBars - InpSwingLookback - 1);

   int lowIdx[20];
   int lCount = CollectSwingLows(bar + InpSwingLookback + 1, endBar, lowIdx, 20);

   if(lCount < 2) return false;

   for(int a = 0; a < lCount - 1; a++)
   {
      for(int b = a + 1; b < lCount; b++)
      {
         int   idxT1 = lowIdx[b]; // older trough
         int   idxT2 = lowIdx[a]; // newer trough
         double l1   = iLow(_Symbol, _Period, idxT1);
         double l2   = iLow(_Symbol, _Period, idxT2);

         //--- Troughs must be nearly equal
         double diff = MathAbs(l1 - l2) / MathMin(l1, l2);
         if(diff > InpPeakTolerance) continue;

         //--- Neckline = highest high between the two troughs
         double neckline = -1e10;
         for(int j = idxT2; j <= idxT1; j++)
            if(iHigh(_Symbol, _Period, j) > neckline) neckline = iHigh(_Symbol, _Period, j);

         //--- Confirmation: close above neckline
         if(iClose(_Symbol, _Period, bar) > neckline)
         {
            slPrice        = MathMin(l1, l2);
            double height  = neckline - MathMin(l1, l2);
            measuredTarget = neckline + height;
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| TRIPLE TOP (Bearish)                                              |
//+------------------------------------------------------------------+
bool DetectTripleTop(int bar, double &slPrice, double &measuredTarget)
{
   int totalBars = iBars(_Symbol, _Period);
   int endBar    = MathMin(bar + InpPatternBars * 2, totalBars - InpSwingLookback - 1);

   int highIdx[20];
   int hCount = CollectSwingHighs(bar + InpSwingLookback + 1, endBar, highIdx, 20);

   if(hCount < 3) return false;

   for(int a = 0; a < hCount - 2; a++)
   {
      for(int b = a + 1; b < hCount - 1; b++)
      {
         for(int c = b + 1; c < hCount; c++)
         {
            int   idxP3 = highIdx[a]; // newest
            int   idxP2 = highIdx[b];
            int   idxP1 = highIdx[c]; // oldest
            double h1   = iHigh(_Symbol, _Period, idxP1);
            double h2   = iHigh(_Symbol, _Period, idxP2);
            double h3   = iHigh(_Symbol, _Period, idxP3);

            double avgH = (h1 + h2 + h3) / 3.0;
            if(avgH <= 0) continue;
            if(MathAbs(h1 - avgH) / avgH > InpPeakTolerance) continue;
            if(MathAbs(h2 - avgH) / avgH > InpPeakTolerance) continue;
            if(MathAbs(h3 - avgH) / avgH > InpPeakTolerance) continue;

            double neckline = 1e10;
            for(int j = idxP3; j <= idxP1; j++)
               if(iLow(_Symbol, _Period, j) < neckline) neckline = iLow(_Symbol, _Period, j);

            if(iClose(_Symbol, _Period, bar) < neckline)
            {
               slPrice        = avgH;
               double height  = avgH - neckline;
               measuredTarget = neckline - height;
               return true;
            }
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| TRIPLE BOTTOM (Bullish)                                           |
//+------------------------------------------------------------------+
bool DetectTripleBottom(int bar, double &slPrice, double &measuredTarget)
{
   int totalBars = iBars(_Symbol, _Period);
   int endBar    = MathMin(bar + InpPatternBars * 2, totalBars - InpSwingLookback - 1);

   int lowIdx[20];
   int lCount = CollectSwingLows(bar + InpSwingLookback + 1, endBar, lowIdx, 20);

   if(lCount < 3) return false;

   for(int a = 0; a < lCount - 2; a++)
   {
      for(int b = a + 1; b < lCount - 1; b++)
      {
         for(int c = b + 1; c < lCount; c++)
         {
            int   idxT3 = lowIdx[a]; // newest
            int   idxT2 = lowIdx[b];
            int   idxT1 = lowIdx[c]; // oldest
            double l1   = iLow(_Symbol, _Period, idxT1);
            double l2   = iLow(_Symbol, _Period, idxT2);
            double l3   = iLow(_Symbol, _Period, idxT3);

            double avgL = (l1 + l2 + l3) / 3.0;
            if(avgL <= 0) continue;
            if(MathAbs(l1 - avgL) / avgL > InpPeakTolerance) continue;
            if(MathAbs(l2 - avgL) / avgL > InpPeakTolerance) continue;
            if(MathAbs(l3 - avgL) / avgL > InpPeakTolerance) continue;

            double neckline = -1e10;
            for(int j = idxT3; j <= idxT1; j++)
               if(iHigh(_Symbol, _Period, j) > neckline) neckline = iHigh(_Symbol, _Period, j);

            if(iClose(_Symbol, _Period, bar) > neckline)
            {
               slPrice        = avgL;
               double height  = neckline - avgL;
               measuredTarget = neckline + height;
               return true;
            }
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| RISING WEDGE (Bearish)                                            |
//+------------------------------------------------------------------+
bool DetectRisingWedge(int bar, double &slPrice, double &measuredTarget)
{
   int totalBars = iBars(_Symbol, _Period);
   int endBar    = MathMin(bar + InpPatternBars, totalBars - InpSwingLookback - 1);
   int startBar  = bar + InpSwingLookback + 1;

   int highIdx[20], lowIdx[20];
   int hCount = CollectSwingHighs(startBar, endBar, highIdx, 20);
   int lCount = CollectSwingLows (startBar, endBar, lowIdx,  20);

   if(hCount < 2 || lCount < 2) return false;

   double slopeH, intH, slopeL, intL;
   if(!LinReg(highIdx, hCount, true,  slopeH, intH)) return false;
   if(!LinReg(lowIdx,  lCount, false, slopeL, intL)) return false;

   //--- Rising Wedge: both trendlines slope up, upper TL is flatter (converging)
   if(slopeH <= 0 || slopeL <= 0) return false;
   if(slopeH >= slopeL)           return false;

   //--- Lower trendline at current bar
   double lowerTLAtBar = slopeL * bar + intL;
   double upperTLAtEnd = slopeH * endBar + intH;
   double lowerTLAtEnd = slopeL * endBar + intL;
   double wedgeHeight  = upperTLAtEnd - lowerTLAtEnd;

   if(iClose(_Symbol, _Period, bar) < lowerTLAtBar)
   {
      //--- SL = last swing high
      slPrice = iHigh(_Symbol, _Period, highIdx[0]);
      //--- Target = breakout minus wedge height
      measuredTarget = lowerTLAtBar - wedgeHeight;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| FALLING WEDGE (Bullish)                                           |
//+------------------------------------------------------------------+
bool DetectFallingWedge(int bar, double &slPrice, double &measuredTarget)
{
   int totalBars = iBars(_Symbol, _Period);
   int endBar    = MathMin(bar + InpPatternBars, totalBars - InpSwingLookback - 1);
   int startBar  = bar + InpSwingLookback + 1;

   int highIdx[20], lowIdx[20];
   int hCount = CollectSwingHighs(startBar, endBar, highIdx, 20);
   int lCount = CollectSwingLows (startBar, endBar, lowIdx,  20);

   if(hCount < 2 || lCount < 2) return false;

   double slopeH, intH, slopeL, intL;
   if(!LinReg(highIdx, hCount, true,  slopeH, intH)) return false;
   if(!LinReg(lowIdx,  lCount, false, slopeL, intL)) return false;

   //--- Falling Wedge: both trendlines slope down, lower TL falls faster (converging)
   if(slopeH >= 0 || slopeL >= 0) return false;
   if(slopeL >= slopeH)           return false;

   //--- Upper trendline at current bar
   double upperTLAtBar = slopeH * bar + intH;
   double upperTLAtEnd = slopeH * endBar + intH;
   double lowerTLAtEnd = slopeL * endBar + intL;
   double wedgeHeight  = upperTLAtEnd - lowerTLAtEnd;

   if(iClose(_Symbol, _Period, bar) > upperTLAtBar)
   {
      //--- SL = last swing low
      slPrice = iLow(_Symbol, _Period, lowIdx[0]);
      //--- Target = breakout plus wedge height
      measuredTarget = upperTLAtBar + wedgeHeight;
      return true;
   }
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

   //--- Check max trades
   if(CountActiveTrades() >= InpMaxOpenTrades) return;

   //--- Analyze completed bar (bar index 1)
   int bar = 1;

   double slPrice        = 0;
   double measuredTarget = 0;

   //============================================================
   //=== BULLISH PATTERNS → BUY ===
   //============================================================

   //--- Inverse Head & Shoulders
   if(InpUseInvHnS && DetectInvHnS(bar, slPrice, measuredTarget))
   {
      PlaceBuy(slPrice, measuredTarget, "Inv H&S");
      return;
   }

   //--- Double Bottom
   if(InpUseDoubleBottom && DetectDoubleBottom(bar, slPrice, measuredTarget))
   {
      PlaceBuy(slPrice, measuredTarget, "Double Bottom");
      return;
   }

   //--- Triple Bottom
   if(InpUseTripleBottom && DetectTripleBottom(bar, slPrice, measuredTarget))
   {
      PlaceBuy(slPrice, measuredTarget, "Triple Bottom");
      return;
   }

   //--- Falling Wedge
   if(InpUseFallingWedge && DetectFallingWedge(bar, slPrice, measuredTarget))
   {
      PlaceBuy(slPrice, measuredTarget, "Falling Wedge");
      return;
   }

   //============================================================
   //=== BEARISH PATTERNS → SELL ===
   //============================================================

   //--- Head & Shoulders
   if(InpUseHnS && DetectHnS(bar, slPrice, measuredTarget))
   {
      PlaceSell(slPrice, measuredTarget, "H&S");
      return;
   }

   //--- Double Top
   if(InpUseDoubleTop && DetectDoubleTop(bar, slPrice, measuredTarget))
   {
      PlaceSell(slPrice, measuredTarget, "Double Top");
      return;
   }

   //--- Triple Top
   if(InpUseTripleTop && DetectTripleTop(bar, slPrice, measuredTarget))
   {
      PlaceSell(slPrice, measuredTarget, "Triple Top");
      return;
   }

   //--- Rising Wedge
   if(InpUseRisingWedge && DetectRisingWedge(bar, slPrice, measuredTarget))
   {
      PlaceSell(slPrice, measuredTarget, "Rising Wedge");
      return;
   }
}
//+------------------------------------------------------------------+
