//+------------------------------------------------------------------+
//|                                            Double_Bottom.mq5     |
//|                        Chart Pattern Reversal - Bullish           |
//|                        Double Bottom (W Pattern) Indicator        |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Chart Pattern Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow
#property indicator_label1  "Double Bottom"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLimeGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Input Parameters
input int    InpSwingLookback  = 5;      // Bars each side to confirm swing
input int    InpPatternBars    = 60;     // Max bars to form pattern
input double InpTroughTol      = 0.005;  // Max difference between troughs (0.5%)

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 20);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME, "Double Bottom");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
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

      //--- Collect swing lows in window
      int   troughIdx[20];
      int   tCount = 0;

      for(int j = rangeStart + InpSwingLookback; j < i - InpSwingLookback; j++)
      {
         if(tCount < 20 && IsSwingLow(j, low, InpSwingLookback))
            troughIdx[tCount++] = j;
      }

      if(tCount < 2) continue;

      //--- Check any 2 troughs that are nearly equal
      for(int a = 0; a < tCount - 1; a++)
      {
         for(int b = a + 1; b < tCount; b++)
         {
            int   idxT1 = troughIdx[a];
            int   idxT2 = troughIdx[b];
            double l1   = low[idxT1];
            double l2   = low[idxT2];

            //--- Troughs must be nearly equal
            double diff = MathAbs(l1 - l2) / MathMin(l1, l2);
            if(diff > InpTroughTol) continue;

            //--- Second trough should not be significantly lower
            if(l2 < l1 * (1.0 - InpTroughTol * 2)) continue;

            //--- Neckline = highest high between the two troughs
            double neckline = -1e10;
            for(int j = idxT1; j <= idxT2; j++)
               if(high[j] > neckline) neckline = high[j];

            //--- Confirmation: current bar close breaks above neckline
            if(close[i] > neckline)
            {
               ArrowBuffer[i] = low[i] - (high[i] - low[i]) * 0.3;
               break;
            }
         }
         if(ArrowBuffer[i] != EMPTY_VALUE) break;
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
