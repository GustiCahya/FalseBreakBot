//+------------------------------------------------------------------+
//|                                               Triple_Top.mq5     |
//|                        Chart Pattern Reversal - Bearish           |
//|                        Triple Top Pattern Indicator               |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Chart Pattern Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow
#property indicator_label1  "Triple Top"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDarkRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Input Parameters
input int    InpSwingLookback  = 5;      // Bars each side to confirm swing
input int    InpPatternBars    = 100;    // Max bars to form pattern
input double InpPeakTolerance  = 0.006;  // Max difference between peaks (0.6%)

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 234);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -20);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME, "Triple Top");
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

      int rangeStart = MathMax(0, i - InpPatternBars);

      //--- Collect swing highs in window
      int   peakIdx[20];
      int   pCount = 0;

      for(int j = rangeStart + InpSwingLookback; j < i - InpSwingLookback; j++)
      {
         if(pCount < 20 && IsSwingHigh(j, high, InpSwingLookback))
            peakIdx[pCount++] = j;
      }

      if(pCount < 3) continue;

      //--- Check any 3 peaks that are nearly equal
      for(int a = 0; a < pCount - 2; a++)
      {
         for(int b = a + 1; b < pCount - 1; b++)
         {
            for(int c = b + 1; c < pCount; c++)
            {
               int   idxP1 = peakIdx[a];
               int   idxP2 = peakIdx[b];
               int   idxP3 = peakIdx[c];
               double h1   = high[idxP1];
               double h2   = high[idxP2];
               double h3   = high[idxP3];

               double avgH = (h1 + h2 + h3) / 3.0;
               if(avgH <= 0) continue;

               //--- All three peaks roughly equal
               if(MathAbs(h1 - avgH) / avgH > InpPeakTolerance) continue;
               if(MathAbs(h2 - avgH) / avgH > InpPeakTolerance) continue;
               if(MathAbs(h3 - avgH) / avgH > InpPeakTolerance) continue;

               //--- Neckline = lowest low between first and last peak
               double neckline = 1e10;
               for(int j = idxP1; j <= idxP3; j++)
                  if(low[j] < neckline) neckline = low[j];

               //--- Confirmation: close below neckline
               if(close[i] < neckline)
               {
                  ArrowBuffer[i] = high[i] + (high[i] - low[i]) * 0.35;
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
