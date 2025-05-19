#property link          "https://www.earnforex.com/metatrader-indicators/trading-session-time/"
#property version       "1.03"
#property strict
#property copyright     "EarnForex.com - 2019-2025"
#property description   "Trading Session Time Indicator"
#property description   "Draw a vertical line, rectangle, or colored candles for the specified time and day."
#property description   ""
#property description   "WARNING: Use this software at your own risk."
#property description   "The creator of this indicator cannot be held responsible for any damage or loss."
#property description   ""
#property description   "Find More on www.EarnForex.com"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_label1 "High/Low"
#property indicator_type1  DRAW_HISTOGRAM
#property indicator_color1 clrLimeGreen
#property indicator_width1 1
#property indicator_label2 "Low/High"
#property indicator_type2  DRAW_HISTOGRAM
#property indicator_color2 clrRed
#property indicator_width2 1
#property indicator_label3 "Bearish"
#property indicator_type3  DRAW_HISTOGRAM
#property indicator_color3 clrRed
#property indicator_width3 3
#property indicator_label4 "Bullish"
#property indicator_type4  DRAW_HISTOGRAM
#property indicator_color4 clrLimeGreen
#property indicator_width4 3

input string Comment1 = "========================"; // MQLTA Trading Session Time
input string IndicatorName = "MQLTA-TST";           // Indicator Short Name
input string Comment2 = "========================"; // Indicator Parameters
input bool DrawCandles = false;                     // Candlesticks Display
input string TimeLineStart = "0000";                // Start Time To Draw (Format 24H HHMM)
input string TimeLineEnd = "";                      // End Time To Draw (Optional - Format HHMM)
input bool ShowMonday = true;                       // Show If Monday
input bool ShowTuesday = true;                      // Show If Tuesday
input bool ShowWednesday = true;                    // Show If Wednesday
input bool ShowThursday = true;                     // Show If Thursday
input bool ShowFriday = true;                       // Show If Friday
input bool ShowSaturday = false;                    // Show If Saturday
input bool ShowSunday = false;                      // Show If Sunday
input int BarsToScan = 1000;                        // Maximum Bars To Search (0=No Limit)
input bool ShowFutureSession = true;                // Show Future Sessions
input string SessionLabel = "";                     // Session Label
input bool ShowRange = false;                       // Show Range in Points
input string Comment_3 = "====================";    // Objects Options
input color LineColor = clrLightGray;               // Objects Color
input int LineThickness = 5;                        // Objects Thickness (For Line, Set 1 to 5)
input color	CandleColorBullish = clrLimeGreen;      // Bullish Color
input color	CandleColorBearish = clrRed;            // Bearish Color
input bool DrawRectangles = false;                  // Draw Rectangles Instead of Areas?

int StartHour = 0;
int StartMinute = 0;
int EndHour = 0;
int EndMinute = 0;
int BarsInChart = 0;
datetime LatestSessionStart = 0;
datetime LatestSessionEnd = 0;

double CandleOpen[], CandleClose[], CandleHigh[], CandleLow[];
int ChartScale = WRONG_VALUE;

int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, IndicatorName); // Set the indicator name.
    OnInitInitialization(); // Internal function to initialize other variables.
    if (!OnInitPreChecksPass()) // Check to see there are requirements that need to be met in order to run.
    {
        return INIT_FAILED;
    }
    
    if (DrawCandles)
    {
        SetIndexBuffer(0, CandleLow);
        SetIndexEmptyValue(0, 0);
        SetIndexBuffer(1, CandleHigh);
        SetIndexEmptyValue(1, 0);
        SetIndexBuffer(2, CandleOpen);
        SetIndexEmptyValue(2, 0);
        SetIndexBuffer(3, CandleClose);
        SetIndexEmptyValue(3, 0);
    
        SetIndexStyle(0, DRAW_HISTOGRAM, STYLE_SOLID, 1, CandleColorBullish);
        SetIndexStyle(1, DRAW_HISTOGRAM, STYLE_SOLID, 1, CandleColorBearish);

        UpdateCandleWidth();
    }
    else IndicatorBuffers(0);

    return INIT_SUCCEEDED;
}

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
    if (Bars != BarsInChart) // New bar or bars.
    {
        ArrayInitialize(CandleOpen, 0);
        ArrayInitialize(CandleHigh, 0);
        ArrayInitialize(CandleLow, 0);
        ArrayInitialize(CandleClose, 0);
        CleanChart();
        if (DrawCandles) DrawCandlesticks();
        else if (TimeLineEnd == "") DrawLines();
        else DrawAreas();
        BarsInChart = Bars;
    }
    else // No new bars.
    {
        // Updates related to the current candle.
        if (DrawCandles) UpdateCurrentCandlestick();
        else if (TimeLineEnd == "") UpdateCurrentLine();
        else UpdateCurrentArea();
    }
    return rates_total;
}

void OnDeinit(const int reason)
{
    CleanChart();
}

void OnInitInitialization()
{
    StartHour = (int)StringSubstr(TimeLineStart, 0, 2);
    EndHour = (int)StringSubstr(TimeLineEnd, 0, 2);
    StartMinute = (int)StringSubstr(TimeLineStart, 2, 2);
    EndMinute = (int)StringSubstr(TimeLineEnd, 2, 2);
}

bool OnInitPreChecksPass()
{
    if ((StartHour < 0) || (StartMinute < 0) || (StartHour > 23) || (StartMinute > 59))
    {
        Print("Time Start value invalid. It has to be in the following format: 0000-2359");
        return false;
    }
    if ((TimeLineEnd != "") && ((EndHour < 0) || (EndMinute < 0) || (EndHour > 23) || (EndMinute > 59)))
    {
        Print("Time End value invalid. It has to be in the following format: 0000-2359");
        return false;
    }
    if ((LineThickness < 1) || (LineThickness > 5))
    {
        Print("Line Thickness must be between 1 and 5.");
        return false;
    }
    return true;
}

void CleanChart()
{
    ObjectsDeleteAll(ChartID(), IndicatorName);
}

void DrawLines()
{
    int MaxBars = BarsToScan;
    if ((Bars < MaxBars) || (MaxBars == 0)) MaxBars = Bars;
    datetime MaxTime = Time[MaxBars - 1];
    datetime CurrTime = StringToTime(StringConcatenate(TimeYear(Time[0]), ".", TimeMonth(Time[0]), ".", TimeDay(Time[0]), " ", StartHour, ":", StartMinute));
    if (ShowFutureSession) CurrTime += PeriodSeconds(PERIOD_D1) * 30; // Some distance in the future.
    while (CurrTime > MaxTime)
    {
        if ((ShowFutureSession) || (CurrTime <= Time[0])) // Skip future session if not to be displayed.
        {
            bool allow_draw = true;
            if (CurrTime <= Time[0])
            {
                datetime bar_time = Time[iBarShift(Symbol(), PERIOD_CURRENT, CurrTime)];
                if (TimeDayOfWeek(bar_time) != TimeDayOfWeek(CurrTime)) allow_draw = false; // To avoid drawing the day of the week on the next one when the needed one is missing.
            }
            if (allow_draw)
            {
                if ((TimeDayOfWeek(CurrTime) == 0) && (ShowSunday)) DrawLine(CurrTime);
                else if ((TimeDayOfWeek(CurrTime) == 1) && (ShowMonday)) DrawLine(CurrTime);
                else if ((TimeDayOfWeek(CurrTime) == 2) && (ShowTuesday)) DrawLine(CurrTime);
                else if ((TimeDayOfWeek(CurrTime) == 3) && (ShowWednesday)) DrawLine(CurrTime);
                else if ((TimeDayOfWeek(CurrTime) == 4) && (ShowThursday)) DrawLine(CurrTime);
                else if ((TimeDayOfWeek(CurrTime) == 5) && (ShowFriday)) DrawLine(CurrTime);
                else if ((TimeDayOfWeek(CurrTime) == 6) && (ShowSaturday)) DrawLine(CurrTime);
            }
        }
        CurrTime -= PERIOD_D1 * 60;
    }
}

void DrawLine(datetime LineTime)
{
    string LineName = IndicatorName + "-VLINE-" + IntegerToString(LineTime);
    ObjectCreate(0, LineName, OBJ_VLINE, 0, LineTime, 0);
    ObjectSetInteger(0, LineName, OBJPROP_COLOR, LineColor);
    ObjectSetInteger(0, LineName, OBJPROP_BACK, true);
    ObjectSetInteger(0, LineName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, LineName, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, LineName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, LineName, OBJPROP_WIDTH, LineThickness);
    if (((SessionLabel != "") || (ShowRange)) && (LineTime <= Time[0])) // Won't work for future sessions.
    {
        datetime StartTimeTmp = LineTime;
        datetime EndTimeTmp = StringToTime(StringConcatenate(TimeYear(LineTime), ".", TimeMonth(LineTime), ".", TimeDay(LineTime), " ", 23, ":", 59));
        int StartBar = iBarShift(Symbol(), PERIOD_CURRENT, StartTimeTmp);
        int EndBar = iBarShift(Symbol(), PERIOD_CURRENT, EndTimeTmp);
        if (StartBar == EndBar) return; // Empty session.
        if ((EndBar != 0) || (iTime(Symbol(), PERIOD_CURRENT, 0) >= EndTimeTmp)) EndBar++; // End bar itself shouldn't be included unless it's the latest bar that makes a part of the session.
        int BarsCount = StartBar - EndBar + 1;
        double HighPoint = High[iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, BarsCount, EndBar)];
        string LabelName = IndicatorName + "-LABEL-" + IntegerToString(LineTime);
        ObjectCreate(0, LabelName, OBJ_TEXT, 0, LineTime, HighPoint);
        ObjectSetInteger(0, LabelName, OBJPROP_COLOR, LineColor);
        ObjectSetInteger(0, LabelName, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, LabelName, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, LabelName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, LabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
        ObjectSetString(0, LabelName, OBJPROP_FONT, "Consolas");
        ObjectSetInteger(0, LabelName, OBJPROP_FONTSIZE, 10);        
        string Text = SessionLabel;
        if (ShowRange)
        {
            double LowPoint = Low[iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BarsCount, EndBar)];
            Text += " " + IntegerToString(int((HighPoint - LowPoint) / _Point));
        }
        ObjectSetString(0, LabelName, OBJPROP_TEXT, Text);
        if (EndTimeTmp > LatestSessionEnd) LatestSessionEnd = EndTimeTmp;
        if (LineTime > LatestSessionStart) LatestSessionStart = LineTime;
    }
}

void UpdateCurrentLine()
{
    if (LatestSessionEnd == 0) return; // Nothing to update.
    if (iTime(Symbol(), PERIOD_CURRENT, 0) >= LatestSessionEnd) return; // The current bar is outside the session.

    if ((SessionLabel != "") || (ShowRange)) // Update the label if required.
    {
        int StartBar = iBarShift(Symbol(), PERIOD_CURRENT, LatestSessionStart);
        int EndBar = 0; // Always the latest bar.
        int BarsCount = StartBar - EndBar + 1;
        double HighPoint = iHigh(Symbol(), PERIOD_CURRENT, iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, BarsCount, EndBar));
        string LabelName = IndicatorName + "-LABEL-" + IntegerToString(LatestSessionStart);
        ObjectSetDouble(0, LabelName, OBJPROP_PRICE, 0, HighPoint);
        string Text = SessionLabel;
        if (ShowRange)
        {
            double LowPoint = Low[iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BarsCount, EndBar)];
            Text += " " + IntegerToString(int((HighPoint - LowPoint) / _Point));
        }
        ObjectSetString(0, LabelName, OBJPROP_TEXT, Text);
    }
}

void DrawAreas()
{
    int MaxBars = BarsToScan;
    if ((Bars < MaxBars) || (MaxBars == 0)) MaxBars = Bars;
    datetime MaxTime = Time[MaxBars - 1];
    datetime StartTimeTmp = StringToTime(StringConcatenate(TimeYear(Time[0]), ".", TimeMonth(Time[0]), ".", TimeDay(Time[0]), " ", StartHour, ":", StartMinute));
    datetime EndTimeTmp = StringToTime(StringConcatenate(TimeYear(Time[0]), ".", TimeMonth(Time[0]), ".", TimeDay(Time[0]), " ", EndHour, ":", EndMinute));
    if (StartTimeTmp > EndTimeTmp)
    {
        EndTimeTmp += PERIOD_D1 * 60;
    }
    while (StartTimeTmp > MaxTime)
    {
        if ((TimeDayOfWeek(StartTimeTmp) == 0) && (ShowSunday)) DrawArea(StartTimeTmp, EndTimeTmp);
        else if ((TimeDayOfWeek(StartTimeTmp) == 1) && (ShowMonday)) DrawArea(StartTimeTmp, EndTimeTmp);
        else if ((TimeDayOfWeek(StartTimeTmp) == 2) && (ShowTuesday)) DrawArea(StartTimeTmp, EndTimeTmp);
        else if ((TimeDayOfWeek(StartTimeTmp) == 3) && (ShowWednesday)) DrawArea(StartTimeTmp, EndTimeTmp);
        else if ((TimeDayOfWeek(StartTimeTmp) == 4) && (ShowThursday)) DrawArea(StartTimeTmp, EndTimeTmp);
        else if ((TimeDayOfWeek(StartTimeTmp) == 5) && (ShowFriday)) DrawArea(StartTimeTmp, EndTimeTmp);
        else if ((TimeDayOfWeek(StartTimeTmp) == 6) && (ShowSaturday)) DrawArea(StartTimeTmp, EndTimeTmp);
        StartTimeTmp -= PERIOD_D1 * 60;
        EndTimeTmp -= PERIOD_D1 * 60;
    }
}

void DrawArea(datetime Start, datetime End)
{
    string AreaName = IndicatorName + "-AREA-" + IntegerToString(Start);
    int StartBar = iBarShift(Symbol(), PERIOD_CURRENT, Start);
    int EndBar = iBarShift(Symbol(), PERIOD_CURRENT, End);
    if (StartBar == EndBar) return; // Empty session.
    if ((EndBar != 0) || (iTime(Symbol(), PERIOD_CURRENT, 0) >= End)) EndBar++; // End bar itself shouldn't be included unless it's the latest bar that makes a part of the session.
    int BarsCount = StartBar - EndBar + 1;
    double HighPoint = High[iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, BarsCount, EndBar)];
    double LowPoint = Low[iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BarsCount, EndBar)];

    ObjectCreate(0, AreaName, OBJ_RECTANGLE, 0, Start, HighPoint, End, LowPoint);
    ObjectSetInteger(0, AreaName, OBJPROP_COLOR, LineColor);
    ObjectSetInteger(0, AreaName, OBJPROP_BACK, !DrawRectangles);
    ObjectSetInteger(0, AreaName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, AreaName, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, AreaName, OBJPROP_FILL, !DrawRectangles);
    ObjectSetInteger(0, AreaName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, AreaName, OBJPROP_SELECTABLE, false);

    if ((SessionLabel != "") || (ShowRange))
    {
        string LabelName = IndicatorName + "-LABEL-" + IntegerToString(Start);
        ObjectCreate(0, LabelName, OBJ_TEXT, 0, Start, HighPoint);
        ObjectSetInteger(0, LabelName, OBJPROP_COLOR, LineColor);
        ObjectSetInteger(0, LabelName, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, LabelName, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, LabelName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, LabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
        ObjectSetString(0, LabelName, OBJPROP_FONT, "Consolas");
        ObjectSetInteger(0, LabelName, OBJPROP_FONTSIZE, 10);        
        string Text = SessionLabel;
        if (ShowRange)
        {
            Text += " " + IntegerToString(int((HighPoint - LowPoint) / _Point));
        }
        ObjectSetString(0, LabelName, OBJPROP_TEXT, Text);
    }
    if (Start > LatestSessionStart) LatestSessionStart = Start;
}

void UpdateCurrentArea()
{
    if (LatestSessionStart == 0) return; // Nothing to update.
    string AreaName = IndicatorName + "-AREA-" + IntegerToString(LatestSessionStart);
    datetime End = (datetime)ObjectGetInteger(0, AreaName, OBJPROP_TIME, 1);
    if (iTime(Symbol(), PERIOD_CURRENT, 0) >= End) return; // The current bar is outside the session.

    double prevHighPoint = ObjectGetDouble(0, AreaName, OBJPROP_PRICE, 0);
    double prevLowPoint = ObjectGetDouble(0, AreaName, OBJPROP_PRICE, 1);
    int StartBar = iBarShift(Symbol(), PERIOD_CURRENT, LatestSessionStart);
    int EndBar = 0; // Always the latest bar.
    int BarsCount = StartBar - EndBar + 1;
    double HighPoint = iHigh(Symbol(), PERIOD_CURRENT, iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, BarsCount, EndBar));
    double LowPoint = iLow(Symbol(), PERIOD_CURRENT, iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BarsCount, EndBar));
    if ((HighPoint > prevHighPoint) || (LowPoint < prevLowPoint)) // Update is needed.
    {
        ObjectSetDouble(0, AreaName, OBJPROP_PRICE, 0, HighPoint);
        ObjectSetDouble(0, AreaName, OBJPROP_PRICE, 1, LowPoint);
        if ((SessionLabel != "") || (ShowRange)) // Update the label if required.
        {
            string LabelName = IndicatorName + "-LABEL-" + IntegerToString(LatestSessionStart);
            ObjectSetDouble(0, LabelName, OBJPROP_PRICE, 0, HighPoint);
            string Text = SessionLabel;
            if (ShowRange)
            {
                Text += " " + IntegerToString(int((HighPoint - LowPoint) / _Point));
            }
            ObjectSetString(0, LabelName, OBJPROP_TEXT, Text);
        }
    }
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if ((!DrawCandles) || (IsStopped())) return;
    UpdateCandleWidth();
}

void UpdateCandleWidth()
{
    int chart_scale = int(ChartGetInteger(0, CHART_SCALE));
    if (chart_scale == ChartScale) return;
    
    ChartScale = chart_scale;
    
    int width;
    switch(ChartScale)
    {
        case 0: width = 1; break;
        case 1: width = 1; break;
        case 2: width = 2; break;
        case 3: width = 3; break;
        case 4: width = 6; break;
        case 5: width = 14; break;
        default: width = 1; break;
    }
    SetIndexStyle(2, DRAW_HISTOGRAM, STYLE_SOLID, width, CandleColorBearish);
    SetIndexStyle(3, DRAW_HISTOGRAM, STYLE_SOLID, width, CandleColorBullish);
    ChartRedraw();
}

void DrawCandlesticks()
{
    if (TimeLineEnd == "")
    {
        EndHour = 23;
        EndMinute = 59;
    }
    int MaxBars = BarsToScan;
    if ((Bars < MaxBars) || (MaxBars == 0)) MaxBars = Bars;
    datetime MaxTime = Time[MaxBars - 1];
    datetime StartTimeTmp = StringToTime(StringConcatenate(TimeYear(Time[0]), ".", TimeMonth(Time[0]), ".", TimeDay(Time[0]), " ", StartHour, ":", StartMinute));
    datetime EndTimeTmp = StringToTime(StringConcatenate(TimeYear(Time[0]), ".", TimeMonth(Time[0]), ".", TimeDay(Time[0]), " ", EndHour, ":", EndMinute));
    if (StartTimeTmp > EndTimeTmp)
    {
        EndTimeTmp += PERIOD_D1 * 60;
    }
    while (StartTimeTmp > MaxTime)
    {
        if ((ShowFutureSession) || (StartTimeTmp <= Time[0])) // Skip future session if not to be displayed.
        {
            if ((TimeDayOfWeek(StartTimeTmp) == 0) && (ShowSunday)) DrawCandlesticksSession(StartTimeTmp, EndTimeTmp);
            if ((TimeDayOfWeek(StartTimeTmp) == 1) && (ShowMonday)) DrawCandlesticksSession(StartTimeTmp, EndTimeTmp);
            if ((TimeDayOfWeek(StartTimeTmp) == 2) && (ShowTuesday)) DrawCandlesticksSession(StartTimeTmp, EndTimeTmp);
            if ((TimeDayOfWeek(StartTimeTmp) == 3) && (ShowWednesday)) DrawCandlesticksSession(StartTimeTmp, EndTimeTmp);
            if ((TimeDayOfWeek(StartTimeTmp) == 4) && (ShowThursday)) DrawCandlesticksSession(StartTimeTmp, EndTimeTmp);
            if ((TimeDayOfWeek(StartTimeTmp) == 5) && (ShowFriday)) DrawCandlesticksSession(StartTimeTmp, EndTimeTmp);
            if ((TimeDayOfWeek(StartTimeTmp) == 6) && (ShowSaturday)) DrawCandlesticksSession(StartTimeTmp, EndTimeTmp);
        }
        StartTimeTmp -= PeriodSeconds(PERIOD_D1);
        EndTimeTmp -= PeriodSeconds(PERIOD_D1);
    }
}

void DrawCandlesticksSession(datetime Start, datetime End)
{
    string AreaName = IndicatorName + "-AREA-" + IntegerToString(Start);
    int StartBar = iBarShift(Symbol(), PERIOD_CURRENT, Start);
    int EndBar = iBarShift(Symbol(), PERIOD_CURRENT, End);
    if (StartBar == EndBar) return; // Empty session.
    if ((EndBar != 0) || (iTime(Symbol(), PERIOD_CURRENT, 0) >= End)) EndBar++; // End bar itself shouldn't be included unless it's the latest bar that makes a part of the session.
    int BarsCount = StartBar - EndBar + 1;

    for (int i = StartBar; i >= EndBar; i--)
    {
        if (Open[i] >= Close[i])
        {
            CandleLow[i] = Low[i];
            CandleHigh[i] = High[i];
        }
        else
        {
            CandleLow[i] = High[i];
            CandleHigh[i] = Low[i];
        }
        CandleOpen[i] = Open[i];
        CandleClose[i] = Close[i];
    }

    if ((SessionLabel != "") || (ShowRange))
    {
        double HighPoint = High[iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, BarsCount, EndBar)];
        string LabelName = IndicatorName + "-LABEL-" + IntegerToString(Start);
        ObjectCreate(0, LabelName, OBJ_TEXT, 0, Start, HighPoint);
        ObjectSetInteger(0, LabelName, OBJPROP_COLOR, LineColor);
        ObjectSetInteger(0, LabelName, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, LabelName, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, LabelName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, LabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
        ObjectSetString(0, LabelName, OBJPROP_FONT, "Consolas");
        ObjectSetInteger(0, LabelName, OBJPROP_FONTSIZE, 10);        
        string Text = SessionLabel;
        if (ShowRange)
        {
            double LowPoint = Low[iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BarsCount, EndBar)];
            Text += " " + IntegerToString(int((HighPoint - LowPoint) / _Point));
        }
        ObjectSetString(0, LabelName, OBJPROP_TEXT, Text);
    }
    if (Start > LatestSessionStart) LatestSessionStart = Start;
    if (End > LatestSessionEnd) LatestSessionEnd = End;
}

void UpdateCurrentCandlestick()
{
    if (LatestSessionEnd == 0) return; // Nothing to update.
    if (iTime(Symbol(), PERIOD_CURRENT, 0) >= LatestSessionEnd) return; // The current bar is outside the session.
    
    if (Open[0] >= Close[0])
    {
        CandleLow[0] = Low[0];
        CandleHigh[0] = High[0];
    }
    else
    {
        CandleLow[0] = High[0];
        CandleHigh[0] = Low[0];
    }
    CandleOpen[0] = Open[0];
    CandleClose[0] = Close[0];
    
    if ((SessionLabel != "") || (ShowRange)) // Update the label if required.
    {
        int StartBar = iBarShift(Symbol(), PERIOD_CURRENT, LatestSessionStart);
        int EndBar = 0; // Always the latest bar.
        int BarsCount = StartBar - EndBar + 1;
        double HighPoint = iHigh(Symbol(), PERIOD_CURRENT, iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, BarsCount, EndBar));
        string LabelName = IndicatorName + "-LABEL-" + IntegerToString(LatestSessionStart);
        ObjectSetDouble(0, LabelName, OBJPROP_PRICE, 0, HighPoint);
        string Text = SessionLabel;
        if (ShowRange)
        {
            double LowPoint = Low[iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BarsCount, EndBar)];
            Text += " " + IntegerToString(int((HighPoint - LowPoint) / _Point));
        }
        ObjectSetString(0, LabelName, OBJPROP_TEXT, Text);
    }
}
//+------------------------------------------------------------------+