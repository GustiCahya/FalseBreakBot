//+------------------------------------------------------------------+
//|                                              Inverted_Hammer.mq5 |
//|                        Candlestick Reversal - Bullish            |
//|                        Inverted Hammer Pattern Indicator          |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Candlestick Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow
#property indicator_label1  "Inverted Hammer"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters
input double InpBodyRatio     = 2.0;   // Min Upper Shadow/Body Ratio
input int    InpTrendBars     = 5;     // Bars to confirm downtrend
input bool   InpRequireConfirm = true; // Require bullish confirmation candle

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 20);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Inverted Hammer");
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
   
   int start = MathMax(prev_calculated - 1, InpTrendBars + 2);
   
   for(int i = start; i < rates_total; i++)
   {
      ArrowBuffer[i] = EMPTY_VALUE;
      
      //--- We check bar i-1 as the inverted hammer, and bar i as confirmation
      int signalBar = i;
      if(InpRequireConfirm)
         signalBar = i - 1;
      
      if(signalBar < InpTrendBars + 1) continue;
      
      double body        = MathAbs(close[signalBar] - open[signalBar]);
      double upperShadow = high[signalBar] - MathMax(open[signalBar], close[signalBar]);
      double lowerShadow = MathMin(open[signalBar], close[signalBar]) - low[signalBar];
      double totalRange   = high[signalBar] - low[signalBar];
      
      if(totalRange <= 0) continue;
      if(body < _Point)   body = _Point;
      
      //--- Inverted Hammer: upper shadow >= ratio * body, lower shadow small
      bool isInvertedHammer = (upperShadow >= InpBodyRatio * body) &&
                              (lowerShadow < body);
      
      //--- Confirmation: next candle is bullish and closes above inverted hammer high
      bool confirmed = true;
      if(InpRequireConfirm && i < rates_total)
      {
         confirmed = (close[i] > open[i]) && (close[i] > high[signalBar]);
      }
      
      if(isInvertedHammer && confirmed && IsDowntrend(signalBar, close, open))
      {
         ArrowBuffer[i] = low[signalBar] - totalRange * 0.3;
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
