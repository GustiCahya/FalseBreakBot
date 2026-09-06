//+------------------------------------------------------------------+
//|                                            Dragonfly_Doji.mq5    |
//|                        Candlestick Reversal - Bullish            |
//|                        Dragonfly Doji Pattern Indicator           |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Candlestick Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow
#property indicator_label1  "Dragonfly Doji"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrAqua
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters
input double InpDojiMaxBodyPct   = 0.1;   // Max body as % of total range (doji threshold)
input double InpMinLowerShadowPct = 0.7;  // Min lower shadow as % of total range
input int    InpTrendBars        = 5;     // Bars to confirm downtrend

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 20);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Dragonfly Doji");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
bool IsDowntrend(int bar, const double &close[], const double &open[])
{
   if(bar + InpTrendBars >= ArraySize(close))
      return false;
   int downCount = 0;
   for(int i = bar + 1; i <= bar + InpTrendBars; i++)
   {
      if(close[i] < open[i])
         downCount++;
   }
   return (downCount >= (int)MathCeil(InpTrendBars * 0.6));
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
      double lowerShadow = MathMin(open[i], close[i]) - low[i];
      double upperShadow = high[i] - MathMax(open[i], close[i]);
      
      if(totalRange <= 0) continue;
      
      //--- Dragonfly Doji: Open ≈ Close near high, long lower shadow
      bool isDragonfly = (body / totalRange <= InpDojiMaxBodyPct) &&
                         (lowerShadow / totalRange >= InpMinLowerShadowPct) &&
                         (upperShadow < body + _Point * 5);  // very little upper shadow
      
      if(isDragonfly && IsDowntrend(i, close, open))
      {
         ArrowBuffer[i] = low[i] - totalRange * 0.3;
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
