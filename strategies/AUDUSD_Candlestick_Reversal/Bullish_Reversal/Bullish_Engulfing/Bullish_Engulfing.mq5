//+------------------------------------------------------------------+
//|                                           Bullish_Engulfing.mq5  |
//|                        Candlestick Reversal - Bullish            |
//|                        Bullish Engulfing Pattern Indicator        |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Candlestick Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow
#property indicator_label1  "Bullish Engulfing"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters
input int InpTrendBars = 5;   // Bars to confirm downtrend

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 20);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Bullish Engulfing");
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
      
      if(i < 1) continue;
      
      //--- Previous candle must be bearish
      bool prevBearish = (close[i-1] < open[i-1]);
      //--- Current candle must be bullish
      bool currBullish = (close[i] > open[i]);
      
      double prevBodyHigh = MathMax(open[i-1], close[i-1]);
      double prevBodyLow  = MathMin(open[i-1], close[i-1]);
      double currBodyHigh = MathMax(open[i], close[i]);
      double currBodyLow  = MathMin(open[i], close[i]);
      
      //--- Engulfing: current body fully engulfs previous body
      bool isEngulfing = prevBearish && currBullish &&
                         (currBodyLow <= prevBodyLow) &&
                         (currBodyHigh >= prevBodyHigh) &&
                         (MathAbs(close[i] - open[i]) > MathAbs(close[i-1] - open[i-1]));
      
      if(isEngulfing && IsDowntrend(i - 1, close, open))
      {
         double totalRange = high[i] - low[i];
         ArrowBuffer[i] = low[i] - totalRange * 0.3;
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
