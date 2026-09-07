//+------------------------------------------------------------------+
//|                                               Double_Top.mq5     |
//|                        Chart Pattern Reversal - Bearish           |
//|                        Double Top (M Pattern) Indicator           |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Chart Pattern Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow
#property indicator_label1  "Double Top"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Input Parameters
input int    InpSwingLookback  = 5;      // Bars each side to confirm swing
input int    InpPatternBars    = 60;     // Max bars to form pattern
input double InpPeakTolerance  = 0.005;  // Max difference between peaks (0.5%)

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 234);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -15);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME, "Double Top");
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

      //--- Collect swing highs and swing lows in window
      int   peakIdx[20];
      int   troughIdx[20];
      int   pCount = 0, tCount = 0;

      for(int j = rangeStart + InpSwingLookback; j < i - InpSwingLookback; j++)
      {
         if(pCount < 20 && IsSwingHigh(j, high, InpSwingLookback))
            peakIdx[pCount++] = j;
         if(tCount < 20 && IsSwingLow(j, low, InpSwingLookback))
            troughIdx[tCount++] = j;
      }

      if(pCount < 2 || tCount < 1) continue;

      //--- Check latest two peaks
      for(int a = 0; a < pCount - 1; a++)
      {
         for(int b = a + 1; b < pCount; b++)
         {
            int   idxP1 = peakIdx[a];
            int   idxP2 = peakIdx[b];
            double h1   = high[idxP1];
            double h2   = high[idxP2];

            //--- Peaks must be nearly equal
            double diff = MathAbs(h1 - h2) / MathMax(h1, h2);
            if(diff > InpPeakTolerance) continue;

            //--- Neckline = lowest low between the two peaks
            double neckline = 1e10;
            for(int j = idxP1; j <= idxP2; j++)
               if(low[j] < neckline) neckline = low[j];

            //--- Second peak should not exceed first significantly
            if(h2 > h1 * (1.0 + InpPeakTolerance * 2)) continue;

            //--- Confirmation: current bar close breaks below neckline
            if(close[i] < neckline)
            {
               ArrowBuffer[i] = high[i] + (high[i] - low[i]) * 0.3;
               break;
            }
         }
         if(ArrowBuffer[i] != EMPTY_VALUE) break;
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
