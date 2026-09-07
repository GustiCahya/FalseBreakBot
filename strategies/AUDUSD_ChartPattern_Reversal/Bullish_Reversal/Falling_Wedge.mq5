//+------------------------------------------------------------------+
//|                                            Falling_Wedge.mq5     |
//|                        Chart Pattern Reversal - Bullish           |
//|                        Falling Wedge Pattern Indicator            |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Chart Pattern Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow
#property indicator_label1  "Falling Wedge"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Input Parameters
input int    InpSwingLookback  = 4;      // Bars each side to confirm swing
input int    InpPatternBars    = 80;     // Max bars to scan for wedge
input int    InpMinSwings      = 2;      // Min swing points on each trendline

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 20);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME, "Falling Wedge");
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
//| Linear regression slope and intercept over given swing points     |
//+------------------------------------------------------------------+
bool LinReg(const int &idx[], int count, const double &prices[], double &slope, double &intercept)
{
   if(count < 2) return false;
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   for(int k = 0; k < count; k++)
   {
      double x = idx[k];
      double y = prices[idx[k]];
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

      //--- Collect swing highs (upper TL) and swing lows (lower TL) in window
      int  highIdx[20], lowIdx[20];
      int  hCount = 0, lCount = 0;

      for(int j = rangeStart + InpSwingLookback; j < i - InpSwingLookback; j++)
      {
         if(hCount < 20 && IsSwingHigh(j, high, InpSwingLookback))
            highIdx[hCount++] = j;
         if(lCount < 20 && IsSwingLow(j, low, InpSwingLookback))
            lowIdx[lCount++] = j;
      }

      if(hCount < InpMinSwings || lCount < InpMinSwings) continue;

      //--- Fit trendlines via linear regression on swing highs and lows
      double slopeH, intH, slopeL, intL;
      if(!LinReg(highIdx, hCount, high, slopeH, intH)) continue;
      if(!LinReg(lowIdx,  lCount, low,  slopeL, intL)) continue;

      //--- Falling Wedge: both slopes negative, lower slope > upper slope (converging downward)
      if(slopeH >= 0 || slopeL >= 0)  continue;  // both must slope down
      if(slopeL >= slopeH)             continue;  // lower TL must fall faster → converging

      //--- Upper trendline at bar i
      double upperTLAtI = slopeH * i + intH;

      //--- Confirmation: close breaks above upper trendline
      if(close[i] > upperTLAtI)
      {
         ArrowBuffer[i] = low[i] - (high[i] - low[i]) * 0.3;
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
