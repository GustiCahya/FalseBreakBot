//+------------------------------------------------------------------+
//|                                       Head_And_Shoulders.mq5     |
//|                        Chart Pattern Reversal - Bearish           |
//|                        Head and Shoulders Pattern Indicator        |
//+------------------------------------------------------------------+
#property copyright "AUDUSD Chart Pattern Reversal"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot Arrow (bearish = red arrow above)
#property indicator_label1  "Head & Shoulders"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrOrangeRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Input Parameters
input int    InpSwingLookback  = 5;     // Bars each side to confirm swing high/low
input int    InpPatternBars    = 80;    // Max bars to form a complete H&S pattern
input double InpShoulderTol    = 0.003; // Shoulder height tolerance (0.3% of price)
input double InpNecklineTol    = 0.002; // Neckline slope tolerance

//--- Indicator Buffer
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 234);        // Down arrow
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -15);  // Above candle
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME, "H&S");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Find swing high at index i                                        |
//+------------------------------------------------------------------+
bool IsSwingHigh(int i, const double &high[], int n)
{
   if(i - n < 0 || i + n >= ArraySize(high)) return false;
   for(int k = 1; k <= n; k++)
      if(high[i] <= high[i-k] || high[i] <= high[i+k]) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Find swing low at index i                                         |
//+------------------------------------------------------------------+
bool IsSwingLow(int i, const double &low[], int n)
{
   if(i - n < 0 || i + n >= ArraySize(low)) return false;
   for(int k = 1; k <= n; k++)
      if(low[i] >= low[i-k] || low[i] >= low[i+k]) return false;
   return true;
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
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);
   ArraySetAsSeries(ArrowBuffer, false);

   int minBars = InpPatternBars + InpSwingLookback + 5;
   int start   = MathMax(prev_calculated - 1, minBars);

   for(int i = start; i < rates_total - InpSwingLookback; i++)
      ArrowBuffer[i] = EMPTY_VALUE;

   //--- Scan each bar as potential right shoulder breakout bar
   for(int i = start; i < rates_total - InpSwingLookback; i++)
   {
      ArrowBuffer[i] = EMPTY_VALUE;

      //--- Collect swing highs within lookback
      int swingHighIdx[10];
      int swingLowIdx[10];
      int hCount = 0, lCount = 0;

      int rangeStart = MathMax(0, i - InpPatternBars);

      for(int j = rangeStart + InpSwingLookback; j < i - InpSwingLookback; j++)
      {
         if(hCount < 10 && IsSwingHigh(j, high, InpSwingLookback))
            swingHighIdx[hCount++] = j;
         if(lCount < 10 && IsSwingLow(j, low, InpSwingLookback))
            swingLowIdx[lCount++] = j;
      }

      if(hCount < 3 || lCount < 2) continue;

      //--- Try to identify H&S: LS, Head, RS
      //    We need: swingHigh[a] < swingHigh[b] > swingHigh[c]
      //    and swingHigh[a] ≈ swingHigh[c] (shoulders similar)
      for(int a = 0; a < hCount - 2; a++)
      {
         for(int b = a + 1; b < hCount - 1; b++)
         {
            for(int c = b + 1; c < hCount; c++)
            {
               int idxLS   = swingHighIdx[a]; // Left shoulder
               int idxHead = swingHighIdx[b]; // Head
               int idxRS   = swingHighIdx[c]; // Right shoulder

               double hLS   = high[idxLS];
               double hHead = high[idxHead];
               double hRS   = high[idxRS];

               //--- Head must be highest
               if(hHead <= hLS || hHead <= hRS) continue;

               //--- Shoulders roughly equal
               double shoulderDiff = MathAbs(hLS - hRS) / hHead;
               if(shoulderDiff > InpShoulderTol * 10) continue;

               //--- Find neckline: low between LS-Head and Head-RS
               double neckLeft  = 1e10, neckRight = 1e10;
               int    idxNL = -1, idxNR = -1;
               for(int j = idxLS; j <= idxHead; j++)
               {
                  if(low[j] < neckLeft) { neckLeft = low[j]; idxNL = j; }
               }
               for(int j = idxHead; j <= idxRS; j++)
               {
                  if(low[j] < neckRight) { neckRight = low[j]; idxNR = j; }
               }
               if(idxNL < 0 || idxNR < 0) continue;

               //--- Interpolate neckline at bar i
               if(idxNR == idxNL) continue;
               double neckSlope = (neckRight - neckLeft) / (idxNR - idxNL);
               double necklineAtI = neckLeft + neckSlope * (i - idxNL);

               //--- Confirmation: current close breaks below neckline
               if(close[i] < necklineAtI && high[idxRS] < high[idxHead])
               {
                  ArrowBuffer[i] = high[i] + (high[i] - low[i]) * 0.3;
                  break;
               }
            }
            if(ArrowBuffer[i] != EMPTY_VALUE) break;
         }
         if(ArrowBuffer[i] != EMPTY_VALUE) break;
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
