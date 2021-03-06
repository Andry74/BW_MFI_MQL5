//+--------------------------------------------------------------------------+
//| Индикатор Билла Вильямса MFI с учётом 10% фильтра (как описано у автора) |
//|                                                         Evgeny Andrianov |
//|                                             http://trading.andrianovi.ru |
//|                                   https://github.com/Andry74/BW_MFI_MQL5 |
//+--------------------------------------------------------------------------+
#property copyright "Evgeny Andrianov"
#property link      "http://trading.andrianovi.ru/"
#property version   "1.2"

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  LightGreen,Black,Blue,Red
#property indicator_width1  4

ENUM_APPLIED_VOLUME InpVolumeType=VOLUME_TICK; // Объём


// Настраиваемые параметры

input int pPrecent=10;         // Порог значимого изменения, %
input int pIndicatorHeight=15; // Высота окна индикатора (0=произвольная)
input bool pHeight = true;     // Одинаковая высота столбцов

double ExtMFIBuffer[];         // для вывода
double ExtColorBuffer[];       // выбор цвета для вывода
double ExtMFIBuffer_tmp[];     // для расчёта


//+------------------------------------------------------------------+
void OnInit() {

   SetIndexBuffer(0,ExtMFIBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,ExtColorBuffer,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,ExtMFIBuffer_tmp,INDICATOR_CALCULATIONS);
   
   IndicatorSetString(INDICATOR_SHORTNAME,"BW MFI 10+");
   IndicatorSetInteger(INDICATOR_DIGITS,0); // _Digits
   
   // высота окна индикатора
   if (pIndicatorHeight>0) {
     IndicatorSetInteger(INDICATOR_HEIGHT, pIndicatorHeight);
   }
   // единая столбиков индикатора или нет
   if (pHeight) {
     IndicatorSetDouble(INDICATOR_MAXIMUM, 1.0);
   }
   
}
//+------------------------------------------------------------------+


void CalculateMFI(const int start,
                  const int rates_total,
                  const double &High[],
                  const double &Low[],
                  const long &Volume[])
  {
   int  i=start;
   bool mfi_up=true,vol_up=true;
   double dMFI;
   double dVOL, t1,t0;
   
//--- calculate first values of mfi_up and vol_up
   if(i>0)
     {
      int n=i;
      while(n>0)
        {
         if(ExtMFIBuffer_tmp[n]>ExtMFIBuffer_tmp[n-1]) { mfi_up=true;  break; }
         if(ExtMFIBuffer_tmp[n]<ExtMFIBuffer_tmp[n-1]) { mfi_up=false; break; }
         //--- if mfi values are equal continue
         n--;
        }
      n=i;
      while(n>0)
        {
         if(Volume[n]>Volume[n-1]) { vol_up=true;  break; }
         if(Volume[n]<Volume[n-1]) { vol_up=false; break; }
         //--- if real volumes are equal continue
         n--;
        }
     }

//---
   while(i<rates_total && !IsStopped()) {
      if(Volume[i]==0) {
         if(i>0) ExtMFIBuffer_tmp[i]=ExtMFIBuffer_tmp[i-1];
         else    ExtMFIBuffer_tmp[i]=0;
         if (pHeight) {
           ExtMFIBuffer[i]=1;
         } else {
           ExtMFIBuffer[i]=0;
         }
      } else {
        ExtMFIBuffer_tmp[i]=(High[i]-Low[i])/_Point/Volume[i];
         if (pHeight) {
           ExtMFIBuffer[i]=1;
         } else {
           ExtMFIBuffer[i]=ExtMFIBuffer_tmp[i];
         }
      }
      
      //--- calculate changes
      if(i>0) {

         // Вычисляем изменение в объёме, в %
         t1 = NormalizeDouble (Volume[i],0);
         t0 = NormalizeDouble (Volume[i-1],0);
         
         if (!t1) {
            if (t0>0) {
               t1 = t0;
            } else {
               t1 = 1;
            }
         }
         
         if (!ExtMFIBuffer[i]) {
            if (ExtMFIBuffer[i-1]>0) {
               ExtMFIBuffer[i] = ExtMFIBuffer[i-1];
            } else {
               ExtMFIBuffer[i] = 1;
            }
         }
         
         dVOL = (t1 - t0 ) / t1 * 100;

         // Вычисляем изменение в MFI, в %
         if (ExtMFIBuffer_tmp[i] && ExtMFIBuffer_tmp[i-1]) dMFI = (ExtMFIBuffer_tmp[i] - ExtMFIBuffer_tmp[i-1] ) / ExtMFIBuffer_tmp[i] * 100;

         // Определяем наличие значимого отклонения, в %
         if (dMFI>=pPrecent) mfi_up=true;
         else mfi_up=false;
         if (dVOL>=pPrecent) vol_up=true;
         else vol_up=false;
      // Рисуем бары по цветам
      if( mfi_up &&  vol_up)  ExtColorBuffer[i]=0.0;
      if(!mfi_up && !vol_up)  ExtColorBuffer[i]=1.0;
      if( mfi_up && !vol_up)  ExtColorBuffer[i]=2.0;
      if(!mfi_up &&  vol_up)  ExtColorBuffer[i]=3.0;         
      }


      i++;
      
     }
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &Time[],
                const double &Open[],
                const double &High[],
                const double &Low[],
                const double &Close[],
                const long &TickVolume[],
                const long &Volume[],
                const int &Spread[])
  {
//---
   int start=0;
//---
   if(start<prev_calculated) start=prev_calculated-1;
//--- calculate with tick or real volumes
   if(InpVolumeType==VOLUME_TICK)
      CalculateMFI(start,rates_total,High,Low,TickVolume);
   else
      CalculateMFI(start,rates_total,High,Low,Volume);
//--- normalize last mfi value
   if(rates_total>1)
     {
      datetime ctm=TimeTradeServer(),lasttm=Time[rates_total-1],nexttm=lasttm+datetime(PeriodSeconds());
      if(ctm<nexttm && ctm>=lasttm && nexttm!=lasttm)
        {
         double correction_koef=double(1+ctm-lasttm)/double(nexttm-lasttm);
         ExtMFIBuffer_tmp[rates_total-1]*=correction_koef;
        }
     }

   return(rates_total);
  }
