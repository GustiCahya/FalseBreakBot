//+------------------------------------------------------------------+
//|                              Inverse_Head_And_Shoulders.mq5      |
//|                        Chart Pattern Reversal - Bullish           |
//|                        Inverse Head and Shoulders Indicator       |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Chart Pattern Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow (bullish = blue arrow below)
#property indicator_label1  "Inverse H&S"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Input Parameters
input int    InpSwingLookback  = 5;     // Bars each side to confirm swing high/low
input int    InpPatternBars    = 80;    // Max bars to form a complete pattern
input double InpShoulderTol    = 0.003; // Shoulder depth tolerance (0.3% of price)

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 233);       // Up arrow
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 20);  // Below candle
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME, "Inv H&S");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
bool IsSwingHigh(int i, const double &high[], int n)
{
   if(i - n < 0 || i + n >= ArraySize(high)) return false;
   for(int k = 1; k <= n; k++)
      if(high[i] <= high[i-k] || high[i] <= high[i+k]) return false;
   return true;
}

bool IsSwingLow(int i, const double &low[], int n)
{
   if(i - n < 0 || i + n >= ArraySize(low)) return false;
   for(int k = 1; k <= n; k++)
      if(low[i] >= low[i-k] || low[i] >= low[i+k]) return false;
   return true;
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);
   ArraySetAsSeries(ArrowBuffer, false);

   int minBars = InpPatternBars + InpSwingLookback + 5;
   int start   = MathMax(prev_calculated - 1, minBars);

   for(int i = start; i < rates_total - InpSwingLookback; i++)
   {
      ArrowBuffer[i] = EMPTY_VALUE;

      //--- Collect swing lows within lookback (for Inverse H&S)
      int swingLowIdx[10];
      int swingHighIdx[10];
      int lCount = 0, hCount = 0;

      int rangeStart = MathMax(0, i - InpPatternBars);

      for(int j = rangeStart + InpSwingLookback; j < i - InpSwingLookback; j++)
      {
         if(lCount < 10 && IsSwingLow(j, low, InpSwingLookback))
            swingLowIdx[lCount++] = j;
         if(hCount < 10 && IsSwingHigh(j, high, InpSwingLookback))
            swingHighIdx[hCount++] = j;
      }

      if(lCount < 3 || hCount < 2) continue;

      //--- Identify Inverse H&S: LS_low, Head_low (lowest), RS_low
      //    LS ≈ RS depth, Head is lowest
      for(int a = 0; a < lCount - 2; a++)
      {
         for(int b = a + 1; b < lCount - 1; b++)
         {
            for(int c = b + 1; c < lCount; c++)
            {
               int   idxLS   = swingLowIdx[a];
               int   idxHead = swingLowIdx[b];
               int   idxRS   = swingLowIdx[c];

               double lLS   = low[idxLS];
               double lHead = low[idxHead];
               double lRS   = low[idxRS];

               //--- Head must be the lowest
               if(lHead >= lLS || lHead >= lRS) continue;

               //--- Shoulders roughly equal depth
               double shoulderDiff = MathAbs(lLS - lRS) / MathMin(lLS, lRS);
               if(shoulderDiff > InpShoulderTol * 10) continue;

               //--- Find neckline: high between LS-Head and Head-RS
               double neckLeft  = -1e10, neckRight = -1e10;
               int    idxNL = -1, idxNR = -1;
               for(int j = idxLS; j <= idxHead; j++)
               {
                  if(high[j] > neckLeft) { neckLeft = high[j]; idxNL = j; }
               }
               for(int j = idxHead; j <= idxRS; j++)
               {
                  if(high[j] > neckRight) { neckRight = high[j]; idxNR = j; }
               }
               if(idxNL < 0 || idxNR < 0) continue;

               //--- Interpolate neckline at bar i
               if(idxNR == idxNL) continue;
               double neckSlope    = (neckRight - neckLeft) / (idxNR - idxNL);
               double necklineAtI  = neckLeft + neckSlope * (i - idxNL);

               //--- Confirmation: close breaks above neckline
               if(close[i] > necklineAtI && low[idxRS] > low[idxHead])
               {
                  ArrowBuffer[i] = low[i] - (high[i] - low[i]) * 0.3;
                  break;
               }
            }
            if(ArrowBuffer[i] != EMPTY_VALUE) break;
         }
         if(ArrowBuffer[i] != EMPTY_VALUE) break;
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
