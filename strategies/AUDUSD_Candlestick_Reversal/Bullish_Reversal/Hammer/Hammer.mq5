//+------------------------------------------------------------------+
//|                                                       Hammer.mq5 |
//|                        Candlestick Reversal - Bullish            |
//|                        Hammer Pattern Indicator                  |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Candlestick Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow
#property indicator_label1  "Hammer"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters
input double InpBodyRatio     = 2.0;   // Min Shadow/Body Ratio (default 2.0)
input int    InpTrendBars     = 5;     // Bars to confirm downtrend

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 233);          // Arrow up symbol
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 20);     // Shift arrow below candle
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Hammer");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Check if there is a downtrend before the bar                      |
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
//| Custom indicator iteration function                               |
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
      double upperShadow = high[i] - MathMax(open[i], close[i]);
      double lowerShadow = MathMin(open[i], close[i]) - low[i];
      double totalRange   = high[i] - low[i];
      
      if(totalRange <= 0) continue;
      if(body < _Point)   body = _Point;  // prevent div-by-zero
      
      //--- Hammer: lower shadow >= ratio * body, upper shadow < body, body in upper third
      bool isHammer = (lowerShadow >= InpBodyRatio * body) &&
                      (upperShadow < body) &&
                      (MathMin(open[i], close[i]) - low[i] > totalRange * 0.5);
      
      if(isHammer && IsDowntrend(i, close, open))
      {
         ArrowBuffer[i] = low[i] - totalRange * 0.3;  // place arrow below low
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
