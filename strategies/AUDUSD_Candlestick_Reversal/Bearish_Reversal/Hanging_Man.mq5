//+------------------------------------------------------------------+
//|                                              Hanging_Man.mq5     |
//|                        Candlestick Reversal - Bearish            |
//|                        Hanging Man Pattern Indicator              |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Candlestick Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow
#property indicator_label1  "Hanging Man"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrOrangeRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters
input double InpBodyRatio      = 2.0;   // Min Lower Shadow/Body Ratio
input int    InpTrendBars      = 5;     // Bars to confirm uptrend
input bool   InpRequireConfirm = true;  // Require bearish confirmation candle

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 234);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -20);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Hanging Man");
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
   
   int start = MathMax(prev_calculated - 1, InpTrendBars + 2);
   
   for(int i = start; i < rates_total; i++)
   {
      ArrowBuffer[i] = EMPTY_VALUE;
      
      int signalBar = i;
      if(InpRequireConfirm)
         signalBar = i - 1;
      
      if(signalBar < InpTrendBars + 1) continue;
      
      double body        = MathAbs(close[signalBar] - open[signalBar]);
      double upperShadow = high[signalBar] - MathMax(open[signalBar], close[signalBar]);
      double lowerShadow = MathMin(open[signalBar], close[signalBar]) - low[signalBar];
      double totalRange  = high[signalBar] - low[signalBar];
      
      if(totalRange <= 0) continue;
      if(body < _Point)   body = _Point;
      
      //--- Hanging Man: same shape as Hammer but at top of uptrend
      bool isHangingMan = (lowerShadow >= InpBodyRatio * body) &&
                          (upperShadow < body) &&
                          (MathMin(open[signalBar], close[signalBar]) - low[signalBar] > totalRange * 0.5);
      
      //--- Confirmation: next candle is bearish and closes below hanging man low
      bool confirmed = true;
      if(InpRequireConfirm && i < rates_total)
      {
         confirmed = (close[i] < open[i]) && (close[i] < low[signalBar]);
      }
      
      if(isHangingMan && confirmed && IsUptrend(signalBar, close, open))
      {
         ArrowBuffer[i] = high[signalBar] + totalRange * 0.3;
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
