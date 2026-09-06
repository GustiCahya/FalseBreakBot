//+------------------------------------------------------------------+
//|                                              Evening_Star.mq5    |
//|                        Candlestick Reversal - Bearish            |
//|                        Evening Star Pattern Indicator             |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Candlestick Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow
#property indicator_label1  "Evening Star"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrGold
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Input Parameters
input double InpDojiMaxBodyPct = 0.3;   // Max body % of range for middle candle (doji)
input double InpMinBodyPct     = 0.5;   // Min body % of range for candles 1 & 3
input int    InpTrendBars      = 5;     // Bars to confirm uptrend

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 234);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -20);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Evening Star");
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
   
   int start = MathMax(prev_calculated - 1, InpTrendBars + 3);
   
   for(int i = start; i < rates_total; i++)
   {
      ArrowBuffer[i] = EMPTY_VALUE;
      
      if(i < 2) continue;
      
      //--- Candle 1 (i-2): Large bullish candle
      double body1  = MathAbs(close[i-2] - open[i-2]);
      double range1 = high[i-2] - low[i-2];
      bool candle1Bullish = (close[i-2] > open[i-2]) &&
                            (range1 > 0) &&
                            (body1 / range1 >= InpMinBodyPct);
      
      //--- Candle 2 (i-1): Small body / Doji
      double body2  = MathAbs(close[i-1] - open[i-1]);
      double range2 = high[i-1] - low[i-1];
      bool candle2Doji = (range2 > 0) && (body2 / range2 <= InpDojiMaxBodyPct);
      
      //--- Candle 3 (i): Large bearish candle
      double body3  = MathAbs(close[i] - open[i]);
      double range3 = high[i] - low[i];
      bool candle3Bearish = (close[i] < open[i]) &&
                            (range3 > 0) &&
                            (body3 / range3 >= InpMinBodyPct);
      
      //--- Candle 3 closes below midpoint of Candle 1's body
      double midBody1 = (open[i-2] + close[i-2]) / 2.0;
      bool closesBelowMid = (close[i] < midBody1);
      
      if(candle1Bullish && candle2Doji && candle3Bearish && closesBelowMid &&
         IsUptrend(i - 2, close, open))
      {
         double highestHigh = MathMax(MathMax(high[i-2], high[i-1]), high[i]);
         double totalRange = highestHigh - low[i];
         ArrowBuffer[i] = highestHigh + totalRange * 0.2;
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
