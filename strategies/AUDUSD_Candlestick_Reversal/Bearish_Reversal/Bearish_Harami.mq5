//+------------------------------------------------------------------+
//|                                            Bearish_Harami.mq5    |
//|                        Candlestick Reversal - Bearish            |
//|                        Bearish Harami Pattern Indicator           |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Candlestick Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow
#property indicator_label1  "Bearish Harami"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters
input double InpMinMotherBodyPct = 0.5;   // Min mother candle body % of range
input int    InpTrendBars        = 5;     // Bars to confirm uptrend
input bool   InpRequireConfirm   = true;  // Require bearish confirmation candle

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 234);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -20);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Bearish Harami");
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
      
      int motherBar = i - 1;
      int childBar  = i;
      
      if(InpRequireConfirm)
      {
         if(i < 3) continue;
         motherBar = i - 2;
         childBar  = i - 1;
      }
      
      //--- Mother candle: large bullish
      double motherBody  = MathAbs(close[motherBar] - open[motherBar]);
      double motherRange = high[motherBar] - low[motherBar];
      bool motherBullish = (close[motherBar] > open[motherBar]) &&
                           (motherRange > 0) &&
                           (motherBody / motherRange >= InpMinMotherBodyPct);
      
      //--- Child candle: small bearish, inside mother's body
      double motherBodyHigh = MathMax(open[motherBar], close[motherBar]);
      double motherBodyLow  = MathMin(open[motherBar], close[motherBar]);
      double childBodyHigh  = MathMax(open[childBar], close[childBar]);
      double childBodyLow   = MathMin(open[childBar], close[childBar]);
      double childBody      = MathAbs(close[childBar] - open[childBar]);
      
      bool childInside = (close[childBar] < open[childBar]) &&      // bearish
                         (childBodyHigh <= motherBodyHigh) &&         // inside
                         (childBodyLow >= motherBodyLow) &&           // inside
                         (childBody < motherBody);                    // smaller
      
      //--- Confirmation candle
      bool confirmed = true;
      if(InpRequireConfirm)
      {
         confirmed = (close[i] < open[i]) && (close[i] < low[childBar]);
      }
      
      if(motherBullish && childInside && confirmed && IsUptrend(motherBar, close, open))
      {
         double highestHigh = MathMax(high[motherBar], high[childBar]);
         double totalRange = highestHigh - low[i];
         ArrowBuffer[i] = highestHigh + totalRange * 0.2;
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
