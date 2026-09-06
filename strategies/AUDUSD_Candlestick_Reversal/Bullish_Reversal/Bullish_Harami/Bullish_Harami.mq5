//+------------------------------------------------------------------+
//|                                            Bullish_Harami.mq5    |
//|                        Candlestick Reversal - Bullish            |
//|                        Bullish Harami Pattern Indicator           |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Candlestick Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow
#property indicator_label1  "Bullish Harami"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrCornflowerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input Parameters
input double InpMinMotherBodyPct = 0.5;   // Min mother candle body % of range
input int    InpTrendBars        = 5;     // Bars to confirm downtrend
input bool   InpRequireConfirm   = true;  // Require bullish confirmation candle

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, 20);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Bullish Harami");
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
   
   int start = MathMax(prev_calculated - 1, InpTrendBars + 3);
   
   for(int i = start; i < rates_total; i++)
   {
      ArrowBuffer[i] = EMPTY_VALUE;
      
      if(i < 2) continue;
      
      //--- Determine signal bar and check bar
      int motherBar = i - 1;
      int childBar  = i;
      
      if(InpRequireConfirm)
      {
         if(i < 3) continue;
         motherBar = i - 2;
         childBar  = i - 1;
      }
      
      //--- Mother candle: large bearish
      double motherBody = MathAbs(close[motherBar] - open[motherBar]);
      double motherRange = high[motherBar] - low[motherBar];
      bool motherBearish = (close[motherBar] < open[motherBar]) &&
                           (motherRange > 0) &&
                           (motherBody / motherRange >= InpMinMotherBodyPct);
      
      //--- Child candle: small bullish, inside mother's body
      double motherBodyHigh = MathMax(open[motherBar], close[motherBar]);
      double motherBodyLow  = MathMin(open[motherBar], close[motherBar]);
      double childBodyHigh  = MathMax(open[childBar], close[childBar]);
      double childBodyLow   = MathMin(open[childBar], close[childBar]);
      double childBody      = MathAbs(close[childBar] - open[childBar]);
      
      bool childInside = (close[childBar] > open[childBar]) &&      // bullish
                         (childBodyHigh <= motherBodyHigh) &&         // inside
                         (childBodyLow >= motherBodyLow) &&           // inside
                         (childBody < motherBody);                    // smaller
      
      //--- Confirmation candle
      bool confirmed = true;
      if(InpRequireConfirm)
      {
         confirmed = (close[i] > open[i]) && (close[i] > high[childBar]);
      }
      
      if(motherBearish && childInside && confirmed && IsDowntrend(motherBar, close, open))
      {
         double lowestLow = MathMin(low[motherBar], low[childBar]);
         double totalRange = high[i] - lowestLow;
         ArrowBuffer[i] = lowestLow - totalRange * 0.2;
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
