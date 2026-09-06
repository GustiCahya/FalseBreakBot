//+------------------------------------------------------------------+
//|                                          Bearish_Engulfing.mq5   |
//|                        Candlestick Reversal - Bearish            |
//|                        Bearish Engulfing Pattern Indicator        |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Candlestick Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow
#property indicator_label1  "Bearish Engulfing"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters
input int InpTrendBars = 5;   // Bars to confirm uptrend

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 234);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -20);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Bearish Engulfing");
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
      
      if(i < 1) continue;
      
      //--- Previous candle must be bullish
      bool prevBullish = (close[i-1] > open[i-1]);
      //--- Current candle must be bearish
      bool currBearish = (close[i] < open[i]);
      
      double prevBodyHigh = MathMax(open[i-1], close[i-1]);
      double prevBodyLow  = MathMin(open[i-1], close[i-1]);
      double currBodyHigh = MathMax(open[i], close[i]);
      double currBodyLow  = MathMin(open[i], close[i]);
      
      //--- Engulfing: current body fully engulfs previous body
      bool isEngulfing = prevBullish && currBearish &&
                         (currBodyHigh >= prevBodyHigh) &&
                         (currBodyLow <= prevBodyLow) &&
                         (MathAbs(close[i] - open[i]) > MathAbs(close[i-1] - open[i-1]));
      
      if(isEngulfing && IsUptrend(i - 1, close, open))
      {
         double totalRange = high[i] - low[i];
         ArrowBuffer[i] = high[i] + totalRange * 0.3;
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
