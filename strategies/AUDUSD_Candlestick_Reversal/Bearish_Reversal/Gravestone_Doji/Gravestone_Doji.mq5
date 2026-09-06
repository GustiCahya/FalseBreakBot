//+------------------------------------------------------------------+
//|                                           Gravestone_Doji.mq5    |
//|                        Candlestick Reversal - Bearish            |
//|                        Gravestone Doji Pattern Indicator          |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Candlestick Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow
#property indicator_label1  "Gravestone Doji"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrMagenta
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters
input double InpDojiMaxBodyPct    = 0.1;   // Max body as % of total range
input double InpMinUpperShadowPct = 0.7;   // Min upper shadow as % of total range
input int    InpTrendBars         = 5;     // Bars to confirm uptrend

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 234);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -20);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Gravestone Doji");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
bool IsUptrend(int bar, const double &close[], const double &open[])
{
   if(bar + InpTrendBars >= ArraySize(close))
      return false;
   int upCount = 0;
   for(int i = bar + 1; i <= bar + InpTrendBars; i++)
   {
      if(close[i] > open[i])
         upCount++;
   }
   return (upCount >= (int)MathCeil(InpTrendBars * 0.6));
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
   ArraySetAsSeries(open, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);
   ArraySetAsSeries(ArrowBuffer, false);
   
   int start = MathMax(prev_calculated - 1, InpTrendBars + 1);
   
   for(int i = start; i < rates_total; i++)
   {
      ArrowBuffer[i] = EMPTY_VALUE;
      
      double body        = MathAbs(close[i] - open[i]);
      double totalRange  = high[i] - low[i];
      double upperShadow = high[i] - MathMax(open[i], close[i]);
      double lowerShadow = MathMin(open[i], close[i]) - low[i];
      
      if(totalRange <= 0) continue;
      
      //--- Gravestone Doji: Open ≈ Close near low, long upper shadow
      bool isGravestone = (body / totalRange <= InpDojiMaxBodyPct) &&
                          (upperShadow / totalRange >= InpMinUpperShadowPct) &&
                          (lowerShadow < body + _Point * 5);
      
      if(isGravestone && IsUptrend(i, close, open))
      {
         ArrowBuffer[i] = high[i] + totalRange * 0.3;
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
