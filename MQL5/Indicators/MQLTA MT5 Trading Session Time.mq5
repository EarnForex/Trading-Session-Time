#property link          "https://www.earnforex.com/metatrader-indicators/trading-session-time/"
#property version       "1.04"

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
#property indicator_plots 1
#property indicator_type1 DRAW_CANDLES
#property indicator_color1 clrDodgerBlue, clrDodgerBlue, clrBlack

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
input bool DrawRectangles = false;                  // Draw Rectangles Instead of Areas?

int StartHour = 0;
int StartMinute = 0;
int EndHour = 0;
int EndMinute = 0;
int BarsInChart = 0;
datetime LatestSessionStart = 0;
datetime LatestSessionEnd = 0;

double ColorCandlesBuffer1[]; 
double ColorCandlesBuffer2[]; 
double ColorCandlesBuffer3[]; 
double ColorCandlesBuffer4[]; 

int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, IndicatorName); // Set the indicator name.
    OnInitInitialization(); // Internal function to initialize other variables.
    if (!OnInitPreChecksPass()) // Check to see there are requirements that need to be met in order to run.
    {
        return INIT_FAILED;
    }

    // Cannot NOT declare all the buffers even when DrawCandles == false because of an MT5 bug.
    SetIndexBuffer(0, ColorCandlesBuffer1, INDICATOR_DATA);
    SetIndexBuffer(1, ColorCandlesBuffer2, INDICATOR_DATA);
    SetIndexBuffer(2, ColorCandlesBuffer3, INDICATOR_DATA);
    SetIndexBuffer(3, ColorCandlesBuffer4, INDICATOR_DATA);
    ArraySetAsSeries(ColorCandlesBuffer1, true);
    ArraySetAsSeries(ColorCandlesBuffer2, true);
    ArraySetAsSeries(ColorCandlesBuffer3, true);
    ArraySetAsSeries(ColorCandlesBuffer4, true);
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    if (!DrawCandles) PlotIndexSetInteger(0, PLOT_SHOW_DATA, false);

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
    if ((Bars(Symbol(), PERIOD_CURRENT) != BarsInChart) || (prev_calculated == 0)) // New bar or bars.
    {
        ArrayInitialize(ColorCandlesBuffer1, EMPTY_VALUE);
        ArrayInitialize(ColorCandlesBuffer2, EMPTY_VALUE);
        ArrayInitialize(ColorCandlesBuffer3, EMPTY_VALUE);
        ArrayInitialize(ColorCandlesBuffer4, EMPTY_VALUE);
        CleanChart();
        if (DrawCandles) DrawCandlesticks();
        else if (TimeLineEnd == "") DrawLines();
        else DrawAreas();
        BarsInChart = Bars(Symbol(), PERIOD_CURRENT);
    }
    else // No new bars.
    {
        // Updates related to the current candle.
        if (DrawCandles) UpdateCurrentCandlestick();
        else if (TimeLineEnd == "") UpdateCurrentLine();
        else UpdateCurrentArea();
    }
    ChartRedraw();
    return rates_total;
}

void OnDeinit(const int reason)
{
    CleanChart();
    ChartRedraw();
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
    if ((Bars(Symbol(), PERIOD_CURRENT) < MaxBars) || (MaxBars == 0)) MaxBars = Bars(Symbol(), PERIOD_CURRENT);
    datetime MaxTime = iTime(Symbol(), PERIOD_CURRENT, MaxBars - 1);
    MqlDateTime CurrentTime;
    TimeToStruct(iTime(Symbol(), PERIOD_CURRENT, 0), CurrentTime);
    string CurrentTimeStr = (string)CurrentTime.year + "." + (string)CurrentTime.mon + "." + (string)CurrentTime.day + " " + (string)StartHour + ":" + (string)StartMinute;
    datetime CurrTime = StringToTime(CurrentTimeStr);
    if (ShowFutureSession) CurrTime += PeriodSeconds(PERIOD_D1) * 30; // Some distance in the future.
    while ((CurrTime > MaxTime) && (iClose(Symbol(), PERIOD_CURRENT, iBarShiftCustom(Symbol(), PERIOD_CURRENT, CurrTime)) > 0))
    {
        if ((ShowFutureSession) || (CurrTime <= iTime(Symbol(), PERIOD_CURRENT, 0))) // Skip future session if not to be displayed.
        {
            TimeToStruct(CurrTime, CurrentTime);
            bool allow_draw = true;
            if (CurrTime <= iTime(Symbol(), PERIOD_CURRENT, 0))
            {
                datetime bar_time = iTime(Symbol(), PERIOD_CURRENT, iBarShiftCustom(Symbol(), PERIOD_CURRENT, CurrTime));
                MqlDateTime bt_struct;
                TimeToStruct(bar_time, bt_struct); 
                if (bt_struct.day_of_week != CurrentTime.day_of_week) allow_draw = false; // To avoid drawing the day of the week on the next one when the needed one is missing.
            }
            if (allow_draw)
            {
                if ((CurrentTime.day_of_week == 0) && (ShowSunday)) DrawLine(CurrTime);
                else if ((CurrentTime.day_of_week == 1) && (ShowMonday)) DrawLine(CurrTime);
                else if ((CurrentTime.day_of_week == 2) && (ShowTuesday)) DrawLine(CurrTime);
                else if ((CurrentTime.day_of_week == 3) && (ShowWednesday)) DrawLine(CurrTime);
                else if ((CurrentTime.day_of_week == 4) && (ShowThursday)) DrawLine(CurrTime);
                else if ((CurrentTime.day_of_week == 5) && (ShowFriday)) DrawLine(CurrTime);
                else if ((CurrentTime.day_of_week == 6) && (ShowSaturday)) DrawLine(CurrTime);
            }
        }
        CurrTime -= PeriodSeconds(PERIOD_D1);
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
    if (((SessionLabel != "") || (ShowRange)) && (LineTime <= iTime(Symbol(), PERIOD_CURRENT, 0))) // Won't work for future sessions.
    {
        datetime StartTimeTmp = LineTime;
        MqlDateTime EndTimeStruct;
        TimeToStruct(LineTime, EndTimeStruct);
        string EndTimeStructStr = (string)EndTimeStruct.year + "." + (string)EndTimeStruct.mon + "." + (string)EndTimeStruct.day + " " + "23:59";
        datetime EndTimeTmp = StringToTime(EndTimeStructStr);
        int StartBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, StartTimeTmp);
        int EndBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, EndTimeTmp);
        if (StartBar == EndBar) return; // Empty session.
        if ((EndBar != 0) || (iTime(Symbol(), PERIOD_CURRENT, 0) >= EndTimeTmp)) EndBar++; // End bar itself shouldn't be included unless it's the latest bar that makes a part of the session.
        int BarsCount = StartBar - EndBar + 1;
        double HighPoint = iHigh(Symbol(), PERIOD_CURRENT, iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, BarsCount, EndBar));
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
            double LowPoint = iLow(Symbol(), PERIOD_CURRENT, iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BarsCount, EndBar));
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
        int StartBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, LatestSessionStart);
        int EndBar = 0; // Always the latest bar.
        int BarsCount = StartBar - EndBar + 1;
        double HighPoint = iHigh(Symbol(), PERIOD_CURRENT, iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, BarsCount, EndBar));
        string LabelName = IndicatorName + "-LABEL-" + IntegerToString(LatestSessionStart);
        ObjectSetDouble(0, LabelName, OBJPROP_PRICE, 0, HighPoint);
        string Text = SessionLabel;
        if (ShowRange)
        {
            double LowPoint = iLow(Symbol(), PERIOD_CURRENT, iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BarsCount, EndBar));
            Text += " " + IntegerToString(int((HighPoint - LowPoint) / _Point));
        }
        ObjectSetString(0, LabelName, OBJPROP_TEXT, Text);
    }
}

void DrawAreas()
{
    int MaxBars = BarsToScan;
    if ((Bars(Symbol(), PERIOD_CURRENT) < MaxBars) || (MaxBars == 0)) MaxBars = Bars(Symbol(), PERIOD_CURRENT);
    datetime MaxTime = iTime(Symbol(), PERIOD_CURRENT, MaxBars - 1);
    MqlDateTime StartTimeStruct;
    MqlDateTime EndTimeStruct;
    TimeToStruct(iTime(Symbol(), PERIOD_CURRENT, 0), StartTimeStruct);
    TimeToStruct(iTime(Symbol(), PERIOD_CURRENT, 0), EndTimeStruct);
    string StartTimeStructStr = (string)StartTimeStruct.year + "." + (string)StartTimeStruct.mon + "." + (string)StartTimeStruct.day + " " + (string)StartHour + ":" + (string)StartMinute;
    string EndTimeStructStr = (string)EndTimeStruct.year + "." + (string)EndTimeStruct.mon + "." + (string)EndTimeStruct.day + " " + (string)EndHour + ":" + (string)EndMinute;

    datetime StartTime = StringToTime(StartTimeStructStr);
    datetime EndTime = StringToTime(EndTimeStructStr);
    datetime StartTimeTmp = StringToTime(StartTimeStructStr);
    datetime EndTimeTmp = StringToTime(EndTimeStructStr);
    if (StartTimeTmp > EndTimeTmp)
    {
        EndTimeTmp += PeriodSeconds(PERIOD_D1);
    }
    while ((StartTimeTmp > MaxTime) && (iClose(Symbol(), PERIOD_CURRENT, iBarShiftCustom(Symbol(), PERIOD_CURRENT, StartTimeTmp)) > 0))
    {
        TimeToStruct(StartTimeTmp, StartTimeStruct);
        if ((StartTimeStruct.day_of_week == 0) && (ShowSunday)) DrawArea(StartTimeTmp, EndTimeTmp);
        else if ((StartTimeStruct.day_of_week == 1) && (ShowMonday)) DrawArea(StartTimeTmp, EndTimeTmp);
        else if ((StartTimeStruct.day_of_week == 2) && (ShowTuesday)) DrawArea(StartTimeTmp, EndTimeTmp);
        else if ((StartTimeStruct.day_of_week == 3) && (ShowWednesday)) DrawArea(StartTimeTmp, EndTimeTmp);
        else if ((StartTimeStruct.day_of_week == 4) && (ShowThursday)) DrawArea(StartTimeTmp, EndTimeTmp);
        else if ((StartTimeStruct.day_of_week == 5) && (ShowFriday)) DrawArea(StartTimeTmp, EndTimeTmp);
        else if ((StartTimeStruct.day_of_week == 6) && (ShowSaturday)) DrawArea(StartTimeTmp, EndTimeTmp);
        StartTimeTmp -= PeriodSeconds(PERIOD_D1);
        EndTimeTmp -= PeriodSeconds(PERIOD_D1);
    }
}

void DrawArea(datetime Start, datetime End)
{
    string AreaName = IndicatorName + "-AREA-" + IntegerToString(Start);
    int StartBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, Start);
    int EndBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, End);
    if (StartBar == EndBar) return; // Empty session.
    if (((EndBar != 0) || (iTime(Symbol(), PERIOD_CURRENT, 0) >= End)) && ((EndMinute != 59) || (EndHour != 23))) EndBar++; // End bar itself shouldn't be included unless it's the latest bar that makes a part of the current session or it's a 23:59 end of day.
    int BarsCount = StartBar - EndBar + 1;
    double HighPoint = iHigh(Symbol(), PERIOD_CURRENT, iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, BarsCount, EndBar));
    double LowPoint = iLow(Symbol(), PERIOD_CURRENT, iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BarsCount, EndBar));
    ObjectCreate(0, AreaName, OBJ_RECTANGLE, 0, Start, HighPoint, End, LowPoint);
    ObjectSetInteger(0, AreaName, OBJPROP_COLOR, LineColor);
    ObjectSetInteger(0, AreaName, OBJPROP_BACK, true);
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
    int StartBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, LatestSessionStart);
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

void DrawCandlesticks()
{
    if (TimeLineEnd == "")
    {
        EndHour = 23;
        EndMinute = 59;
    }
    int MaxBars = BarsToScan;
    if ((Bars(Symbol(), PERIOD_CURRENT) < MaxBars) || (MaxBars == 0)) MaxBars = Bars(Symbol(), PERIOD_CURRENT);
    datetime MaxTime = iTime(Symbol(), PERIOD_CURRENT, MaxBars - 1);
    MqlDateTime StartTimeStruct;
    MqlDateTime EndTimeStruct;
    TimeToStruct(iTime(Symbol(), PERIOD_CURRENT, 0), StartTimeStruct);
    TimeToStruct(iTime(Symbol(), PERIOD_CURRENT, 0), EndTimeStruct);
    string StartTimeStructStr = (string)StartTimeStruct.year + "." + (string)StartTimeStruct.mon + "." + (string)StartTimeStruct.day + " " + (string)StartHour + ":" + (string)StartMinute;
    string EndTimeStructStr = (string)EndTimeStruct.year + "." + (string)EndTimeStruct.mon + "." + (string)EndTimeStruct.day + " " + (string)EndHour + ":" + (string)EndMinute;

    datetime StartTime = StringToTime(StartTimeStructStr);
    datetime EndTime = StringToTime(EndTimeStructStr);
    datetime StartTimeTmp = StringToTime(StartTimeStructStr);
    datetime EndTimeTmp = StringToTime(EndTimeStructStr);

    if (StartTimeTmp > EndTimeTmp)
    {
        EndTimeTmp += PeriodSeconds(PERIOD_D1);
    }
    while ((StartTimeTmp > MaxTime) && (iClose(Symbol(), PERIOD_CURRENT, iBarShiftCustom(Symbol(), PERIOD_CURRENT, StartTimeTmp)) > 0))
    {
        TimeToStruct(StartTimeTmp, StartTimeStruct);
        if ((StartTimeStruct.day_of_week == 0) && (ShowSunday)) DrawCandlesticksSession(StartTimeTmp, EndTimeTmp);
        else if ((StartTimeStruct.day_of_week == 1) && (ShowMonday)) DrawCandlesticksSession(StartTimeTmp, EndTimeTmp);
        else if ((StartTimeStruct.day_of_week == 2) && (ShowTuesday)) DrawCandlesticksSession(StartTimeTmp, EndTimeTmp);
        else if ((StartTimeStruct.day_of_week == 3) && (ShowWednesday)) DrawCandlesticksSession(StartTimeTmp, EndTimeTmp);
        else if ((StartTimeStruct.day_of_week == 4) && (ShowThursday)) DrawCandlesticksSession(StartTimeTmp, EndTimeTmp);
        else if ((StartTimeStruct.day_of_week == 5) && (ShowFriday)) DrawCandlesticksSession(StartTimeTmp, EndTimeTmp);
        else if ((StartTimeStruct.day_of_week == 6) && (ShowSaturday)) DrawCandlesticksSession(StartTimeTmp, EndTimeTmp);
        StartTimeTmp -= PeriodSeconds(PERIOD_D1);
        EndTimeTmp -= PeriodSeconds(PERIOD_D1);
    }
}

void DrawCandlesticksSession(datetime Start, datetime End)
{
    int StartBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, Start);
    int EndBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, End);
    if (StartBar == EndBar) return; // Empty session.
    if (((EndBar != 0) || (iTime(Symbol(), PERIOD_CURRENT, 0) >= End)) && ((EndMinute != 59) || (EndHour != 23))) EndBar++; // End bar itself shouldn't be included unless it's the latest bar that makes a part of the current session or it's a 23:59 end of day.
    int BarsCount = StartBar - EndBar + 1;

    for (int i = StartBar; i >= EndBar; i--)
    {
        ColorCandlesBuffer1[i] = iOpen(Symbol(), PERIOD_CURRENT, i);
        ColorCandlesBuffer2[i] = iHigh(Symbol(), PERIOD_CURRENT, i);
        ColorCandlesBuffer3[i] = iLow(Symbol(), PERIOD_CURRENT, i);
        ColorCandlesBuffer4[i] = iClose(Symbol(), PERIOD_CURRENT, i);
    }
    
    if ((SessionLabel != "") || (ShowRange))
    {
        double HighPoint = iHigh(Symbol(), PERIOD_CURRENT, iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, BarsCount, EndBar));
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
            double LowPoint = iLow(Symbol(), PERIOD_CURRENT, iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BarsCount, EndBar));
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
    
    ColorCandlesBuffer1[0] = iOpen(Symbol(), PERIOD_CURRENT, 0);
    ColorCandlesBuffer2[0] = iHigh(Symbol(), PERIOD_CURRENT, 0);
    ColorCandlesBuffer3[0] = iLow(Symbol(), PERIOD_CURRENT, 0);
    ColorCandlesBuffer4[0] = iClose(Symbol(), PERIOD_CURRENT, 0);
    
    if ((SessionLabel != "") || (ShowRange)) // Update the label if required.
    {
        int StartBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, LatestSessionStart);
        int EndBar = 0; // Always the latest bar.
        int BarsCount = StartBar - EndBar + 1;
        double HighPoint = iHigh(Symbol(), PERIOD_CURRENT, iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, BarsCount, EndBar));
        string LabelName = IndicatorName + "-LABEL-" + IntegerToString(LatestSessionStart);
        ObjectSetDouble(0, LabelName, OBJPROP_PRICE, 0, HighPoint);
        string Text = SessionLabel;
        if (ShowRange)
        {
            double LowPoint = iLow(Symbol(), PERIOD_CURRENT, iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BarsCount, EndBar));
            Text += " " + IntegerToString(int((HighPoint - LowPoint) / _Point));
        }
        ObjectSetString(0, LabelName, OBJPROP_TEXT, Text);
    }
}

int iBarShiftCustom(string symbol, ENUM_TIMEFRAMES tf, datetime time) // Always exact = false.
{
    int i = 0;
    int bars = iBars(symbol, tf);
    while (iTime(symbol, tf, i) > time)
    {
        i++;
        if (i >= bars) return -1;
    }
    return i;
}
//+------------------------------------------------------------------+