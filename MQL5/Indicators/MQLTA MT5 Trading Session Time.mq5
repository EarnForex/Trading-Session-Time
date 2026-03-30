#property link          "https://www.earnforex.com/metatrader-indicators/trading-session-time/"
#property version       "1.05"

#property copyright     "EarnForex.com - 2019-2026"
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

input string Comment_1 = "========================"; // MQLTA Trading Session Time
input string IndicatorName = "MQLTA-TST";            // Indicator Short Name
input string Comment_2 = "========================"; // Indicator Parameters
input bool DrawCandles = false;                      // Candlesticks Display
input string TimeLineStart = "0000";                 // Start Time To Draw (Format 24H HHMM)
input string TimeLineEnd = "";                       // End Time To Draw (Optional - Format HHMM)
input bool ShowMonday = true;                        // Show If Monday
input bool ShowTuesday = true;                       // Show If Tuesday
input bool ShowWednesday = true;                     // Show If Wednesday
input bool ShowThursday = true;                      // Show If Thursday
input bool ShowFriday = true;                        // Show If Friday
input bool ShowSaturday = false;                     // Show If Saturday
input bool ShowSunday = false;                       // Show If Sunday
input int BarsToScan = 1000;                         // Maximum Bars To Search (0=No Limit)
input bool ShowFutureSession = true;                 // Show Future Sessions
input string SessionLabel = "";                      // Session Label
input bool ShowRange = false;                        // Show Range in Points
input string Comment_3 = "========================"; // Objects Options
input color LineColor = clrLightGray;                // Objects Color
input int LineThickness = 5;                         // Objects Thickness (For Line, Set 1 to 5)
input color AreaBorderColor = clrDarkGray;           // Area Border Color
input color AreaFillColor = clrSlateGray;            // Area Fill Color
input string Comment_4 = "========================"; // Notification Options
input bool NotifyOnSessionStart = false;             // Notify on Session Start
input bool NotifyOnSessionEnd = false;               // Notify on Session End
input bool SendAlert = true;                         // Send Alert Notification
input bool SendApp = false;                          // Send Notification to Mobile
input bool SendEmail = false;                        // Send Notification via Email
input bool SendSound = false;                        // Sound Alert
input string SoundFile = "alert.wav";                // Sound File

int StartHour = 0;
int StartMinute = 0;
int EndHour = 0;
int EndMinute = 0;
int BarsInChart = 0;
datetime LatestSessionStart = 0;
datetime LatestSessionEnd = 0;
datetime NewestCompletedSessionStart = 0; // Most recent session fully in the past — used as the boundary for incremental redraws.
int ObjectPrefixLength;
datetime LastNotificationTime;   // Prevents duplicate alerts for the same bar.
datetime SessionStartToday = 0;  // Today's session start, computed on each new bar.
datetime SessionEndToday = 0;    // Today's session end, computed on each new bar.

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

    ObjectPrefixLength = StringLen(IndicatorName + "-");

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
    if (prev_calculated == 0) // First call, timeframe change, or history reload — full redraw required.
    {
        ArrayInitialize(ColorCandlesBuffer1, EMPTY_VALUE);
        ArrayInitialize(ColorCandlesBuffer2, EMPTY_VALUE);
        ArrayInitialize(ColorCandlesBuffer3, EMPTY_VALUE);
        ArrayInitialize(ColorCandlesBuffer4, EMPTY_VALUE);
        CleanChart();
        LatestSessionStart = 0;
        LatestSessionEnd = 0;
        NewestCompletedSessionStart = 0;
        if (DrawCandles) DrawCandlesticks();
        else if (TimeLineEnd == "") DrawLines();
        else DrawAreas();
        BarsInChart = rates_total;
    }
    else if (rates_total != BarsInChart) // New bar(s) — incremental update.
    {
        IncrementalUpdate();
        BarsInChart = rates_total;
        CheckNotifications();
    }
    else // No new bars — tick update for the current candle only.
    {
        if (DrawCandles) UpdateCurrentCandlestick();
        else if (TimeLineEnd == "") UpdateCurrentLine();
        else UpdateCurrentArea();
    }
    return rates_total;
}

void OnDeinit(const int reason)
{
    CleanChart();
    ChartRedraw();
}

void OnInitInitialization()
{
    string ts = TimeLineStart;
    string te = TimeLineEnd;
    StringTrimLeft(ts);
    StringTrimRight(ts);
    StringTrimLeft(te);
    StringTrimRight(te);
    StringReplace(ts, "h", "");
    StringReplace(ts, ":", "");
    StringReplace(ts, ".", "");
    StringReplace(te, "h", "");
    StringReplace(te, ":", "");
    StringReplace(te, ".", "");
    if (StringLen(ts) < 4) ts = "0" + ts; // 830 -> 0830.
    if (StringLen(te) < 4) te = "0" + te;
    StartHour = (int)StringSubstr(ts, 0, 2);
    EndHour = (int)StringSubstr(te, 0, 2);
    StartMinute = (int)StringSubstr(ts, 2, 2);
    EndMinute = (int)StringSubstr(te, 2, 2);
    LastNotificationTime = 0;
}

bool OnInitPreChecksPass()
{
    if ((StartHour < 0) || (StartMinute < 0) || (StartHour > 23) || (StartMinute > 59))
    {
        Print("Time Start value invalid. It has to be between 0000 and 2359.");
        return false;
    }
    if ((TimeLineEnd != "") && ((EndHour < 0) || (EndMinute < 0) || (EndHour > 23) || (EndMinute > 59)))
    {
        Print("Time End value invalid. It has to be between 0000 and 2359.");
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
    ObjectsDeleteAll(ChartID(), IndicatorName + "-");
}

// Delete only indicator objects whose primary time anchor is at or after fromTime.
// This removes current (incomplete) session objects and future session projections
// while leaving all completed past session objects untouched.
void CleanSessionsFrom(datetime fromTime)
{
    int totalObjects = ObjectsTotal(ChartID(), 0, -1);
    for (int i = totalObjects - 1; i >= 0; i--)
    {
        string name = ObjectName(ChartID(), i);
        if (StringSubstr(name, 0, ObjectPrefixLength) != IndicatorName + "-") continue; // Not ours.
        datetime objTime = (datetime)ObjectGetInteger(ChartID(), name, OBJPROP_TIME, 0);
        if (objTime >= fromTime)
        {
            ObjectDelete(ChartID(), name);
        }
    }
}

// Called on every new bar instead of a full wipe-and-redraw.
// Only redraws the current (possibly still active) session and future projections.
void IncrementalUpdate()
{
    // Determine the boundary: everything from LatestSessionStart onward gets redrawn.
    datetime redrawFrom = LatestSessionStart;
    if (redrawFrom <= 0) redrawFrom = iTime(Symbol(), PERIOD_CURRENT, 0); // Fallback: just today.

    // Remove objects for the current session and any future projections.
    CleanSessionsFrom(redrawFrom);

    // For candle buffers, clear only the bars from bar 0 up to the redraw boundary.
    if (DrawCandles)
    {
        int clearUpTo = iBarShiftCustom(Symbol(), PERIOD_CURRENT, redrawFrom);
        if (clearUpTo < 0) clearUpTo = Bars(Symbol(), PERIOD_CURRENT) - 1;
        for (int i = 0; i <= clearUpTo; i++)
        {
            ColorCandlesBuffer1[i] = EMPTY_VALUE;
            ColorCandlesBuffer2[i] = EMPTY_VALUE;
            ColorCandlesBuffer3[i] = EMPTY_VALUE;
            ColorCandlesBuffer4[i] = EMPTY_VALUE;
        }
    }

    // Reset the tracking variables to just before the redraw zone.
    LatestSessionStart = NewestCompletedSessionStart;
    LatestSessionEnd = 0;

    // Redraw only from the boundary forward (typically 1-2 sessions + future lines).
    if (DrawCandles) DrawCandlesticks(redrawFrom);
    else if (TimeLineEnd == "") DrawLines(redrawFrom);
    else DrawAreas(redrawFrom);
}

void DrawLines(datetime stopTime = 0)
{
    int MaxBars = BarsToScan;
    if ((Bars(Symbol(), PERIOD_CURRENT) < MaxBars) || (MaxBars == 0)) MaxBars = Bars(Symbol(), PERIOD_CURRENT);
    datetime MaxTime = iTime(Symbol(), PERIOD_CURRENT, MaxBars - 1);
    if ((stopTime > 0) && (stopTime > MaxTime)) MaxTime = stopTime - 1; // -1 so the session starting exactly at stopTime still satisfies the > check.
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
                if (IsDayAllowed(CurrentTime.day_of_week)) DrawLine(CurrTime);
            }
        }
        CurrTime -= PeriodSeconds(PERIOD_D1);
    }
    ChartRedraw();
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

    // Determine the session's effective end time (end of the line's day).
    MqlDateTime EndTimeStruct;
    TimeToStruct(LineTime, EndTimeStruct);
    string EndTimeStructStr = (string)EndTimeStruct.year + "." + (string)EndTimeStruct.mon + "." + (string)EndTimeStruct.day + " " + "23:59";
    datetime EndTimeTmp = StringToTime(EndTimeStructStr);

    if (((SessionLabel != "") || (ShowRange)) && (LineTime <= iTime(Symbol(), PERIOD_CURRENT, 0))) // Won't work for future sessions.
    {
        datetime StartTimeTmp = LineTime;
        int StartBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, StartTimeTmp);
        int EndBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, EndTimeTmp);
        // Skip if end already passed (historical gap). Allow single-bar active sessions where end is still in the future.
        if ((StartBar == EndBar) && (EndTimeTmp <= iTime(Symbol(), PERIOD_CURRENT, 0))) return;
        if ((EndBar != 0) || (iTime(Symbol(), PERIOD_CURRENT, 0) >= EndTimeTmp)) EndBar++; // End bar itself shouldn't be included unless it's the latest bar that makes a part of the session.
        int BarsCount = StartBar - EndBar + 1;
        double HighPoint = iHigh(Symbol(), PERIOD_CURRENT, iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, BarsCount, EndBar));
        string Text = SessionLabel;
        if (ShowRange)
        {
            double LowPoint = iLow(Symbol(), PERIOD_CURRENT, iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BarsCount, EndBar));
            Text += " " + IntegerToString(int((HighPoint - LowPoint) / _Point));
        }
        SetLabel(LineTime, HighPoint, Text);
    }

    // Track session boundaries for tick updates and incremental redraws.
    // Must be outside the label block so incremental works even when labels are off.
    if (LineTime <= iTime(Symbol(), PERIOD_CURRENT, 0))
    {
        if (EndTimeTmp > LatestSessionEnd) LatestSessionEnd = EndTimeTmp;
        if (LineTime > LatestSessionStart) LatestSessionStart = LineTime;
    }

    // Track the most recent completed session for incremental redraw.
    if ((LineTime > NewestCompletedSessionStart) && (iTime(Symbol(), PERIOD_CURRENT, 0) >= EndTimeTmp))
    {
        NewestCompletedSessionStart = LineTime;
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
    ChartRedraw();
}

void DrawAreas(datetime stopTime = 0)
{
    int MaxBars = BarsToScan;
    if ((Bars(Symbol(), PERIOD_CURRENT) < MaxBars) || (MaxBars == 0)) MaxBars = Bars(Symbol(), PERIOD_CURRENT);
    datetime MaxTime = iTime(Symbol(), PERIOD_CURRENT, MaxBars - 1);
    if ((stopTime > 0) && (stopTime > MaxTime)) MaxTime = stopTime - 1; // -1 so the session starting exactly at stopTime still satisfies the > check.
    MqlDateTime StartTimeStruct;
    MqlDateTime EndTimeStruct;
    TimeToStruct(iTime(Symbol(), PERIOD_CURRENT, 0), StartTimeStruct);
    TimeToStruct(iTime(Symbol(), PERIOD_CURRENT, 0), EndTimeStruct);
    string StartTimeStructStr = (string)StartTimeStruct.year + "." + (string)StartTimeStruct.mon + "." + (string)StartTimeStruct.day + " " + (string)StartHour + ":" + (string)StartMinute;
    string EndTimeStructStr = (string)EndTimeStruct.year + "." + (string)EndTimeStruct.mon + "." + (string)EndTimeStruct.day + " " + (string)EndHour + ":" + (string)EndMinute;

    datetime StartTimeTmp = StringToTime(StartTimeStructStr);
    datetime EndTimeTmp = StringToTime(EndTimeStructStr);
    if (StartTimeTmp > EndTimeTmp)
    {
        EndTimeTmp += PeriodSeconds(PERIOD_D1);
    }
    while ((StartTimeTmp > MaxTime) && (iClose(Symbol(), PERIOD_CURRENT, iBarShiftCustom(Symbol(), PERIOD_CURRENT, StartTimeTmp)) > 0))
    {
        TimeToStruct(StartTimeTmp, StartTimeStruct);
        if (IsDayAllowed(StartTimeStruct.day_of_week)) DrawArea(StartTimeTmp, EndTimeTmp);
        StartTimeTmp -= PeriodSeconds(PERIOD_D1);
        EndTimeTmp -= PeriodSeconds(PERIOD_D1);
    }
    ChartRedraw();
}

void DrawArea(datetime Start, datetime End)
{
    int StartBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, Start);
    int EndBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, End);
    // Skip if completely in the future (not started) or a historical gap (end already passed). Allow single-bar active sessions.
    if ((StartBar == EndBar) && ((Start > iTime(Symbol(), PERIOD_CURRENT, 0)) || (End <= iTime(Symbol(), PERIOD_CURRENT, 0)))) return;
    if (((EndBar != 0) || (iTime(Symbol(), PERIOD_CURRENT, 0) >= End)) && ((EndMinute != 59) || (EndHour != 23))) EndBar++; // End bar itself shouldn't be included unless it's the latest bar that makes a part of the current session or it's a 23:59 end of day.
    int BarsCount = StartBar - EndBar + 1;
    double HighPoint = iHigh(Symbol(), PERIOD_CURRENT, iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, BarsCount, EndBar));
    double LowPoint = iLow(Symbol(), PERIOD_CURRENT, iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BarsCount, EndBar));

    // Filled background rectangle.
    string FillName = IndicatorName + "-FILL-" + IntegerToString(Start);
    ObjectCreate(0, FillName, OBJ_RECTANGLE, 0, Start, HighPoint, End, LowPoint);
    ObjectSetInteger(0, FillName, OBJPROP_COLOR, AreaFillColor);
    ObjectSetInteger(0, FillName, OBJPROP_BACK, true);
    ObjectSetInteger(0, FillName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, FillName, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, FillName, OBJPROP_FILL, true);
    ObjectSetInteger(0, FillName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, FillName, OBJPROP_SELECTABLE, false);

    // Border rectangle (outline only, drawn in front).
    string BorderName = IndicatorName + "-BORDER-" + IntegerToString(Start);
    ObjectCreate(0, BorderName, OBJ_RECTANGLE, 0, Start, HighPoint, End, LowPoint);
    ObjectSetInteger(0, BorderName, OBJPROP_COLOR, AreaBorderColor);
    ObjectSetInteger(0, BorderName, OBJPROP_BACK, false);
    ObjectSetInteger(0, BorderName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, BorderName, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, BorderName, OBJPROP_FILL, false);
    ObjectSetInteger(0, BorderName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, BorderName, OBJPROP_SELECTABLE, false);
    
    if ((SessionLabel != "") || (ShowRange))
    {
        string Text = SessionLabel;
        if (ShowRange)
        {
            Text += " " + IntegerToString(int((HighPoint - LowPoint) / _Point));
        }
        SetLabel(Start, HighPoint, Text);
    }
    if (Start > LatestSessionStart) LatestSessionStart = Start;

    // Track the most recent completed session for incremental redraw.
    if ((Start > NewestCompletedSessionStart) && (iTime(Symbol(), PERIOD_CURRENT, 0) >= End))
    {
        NewestCompletedSessionStart = Start;
    }
}

void UpdateCurrentArea()
{
    if (LatestSessionStart == 0) return; // Nothing to update.
    string FillName = IndicatorName + "-FILL-" + IntegerToString(LatestSessionStart);
    string BorderName = IndicatorName + "-BORDER-" + IntegerToString(LatestSessionStart);
    datetime End = (datetime)ObjectGetInteger(0, FillName, OBJPROP_TIME, 1);
    if (iTime(Symbol(), PERIOD_CURRENT, 0) >= End) return; // The current bar is outside the session.

    double prevHighPoint = ObjectGetDouble(0, FillName, OBJPROP_PRICE, 0);
    double prevLowPoint = ObjectGetDouble(0, FillName, OBJPROP_PRICE, 1);
    int StartBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, LatestSessionStart);
    int EndBar = 0; // Always the latest bar.
    int BarsCount = StartBar - EndBar + 1;
    double HighPoint = iHigh(Symbol(), PERIOD_CURRENT, iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, BarsCount, EndBar));
    double LowPoint = iLow(Symbol(), PERIOD_CURRENT, iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BarsCount, EndBar));
    if ((HighPoint > prevHighPoint) || (LowPoint < prevLowPoint)) // Update is needed.
    {
        ObjectSetDouble(0, FillName, OBJPROP_PRICE, 0, HighPoint);
        ObjectSetDouble(0, FillName, OBJPROP_PRICE, 1, LowPoint);
        ObjectSetDouble(0, BorderName, OBJPROP_PRICE, 0, HighPoint);
        ObjectSetDouble(0, BorderName, OBJPROP_PRICE, 1, LowPoint);
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
    ChartRedraw();
}

void DrawCandlesticks(datetime stopTime = 0)
{
    if (TimeLineEnd == "")
    {
        EndHour = 23;
        EndMinute = 59;
    }
    int MaxBars = BarsToScan;
    if ((Bars(Symbol(), PERIOD_CURRENT) < MaxBars) || (MaxBars == 0)) MaxBars = Bars(Symbol(), PERIOD_CURRENT);
    datetime MaxTime = iTime(Symbol(), PERIOD_CURRENT, MaxBars - 1);
    if ((stopTime > 0) && (stopTime > MaxTime)) MaxTime = stopTime - 1; // -1 so the session starting exactly at stopTime still satisfies the > check.
    MqlDateTime StartTimeStruct;
    MqlDateTime EndTimeStruct;
    TimeToStruct(iTime(Symbol(), PERIOD_CURRENT, 0), StartTimeStruct);
    TimeToStruct(iTime(Symbol(), PERIOD_CURRENT, 0), EndTimeStruct);
    string StartTimeStructStr = (string)StartTimeStruct.year + "." + (string)StartTimeStruct.mon + "." + (string)StartTimeStruct.day + " " + (string)StartHour + ":" + (string)StartMinute;
    string EndTimeStructStr = (string)EndTimeStruct.year + "." + (string)EndTimeStruct.mon + "." + (string)EndTimeStruct.day + " " + (string)EndHour + ":" + (string)EndMinute;

    datetime StartTimeTmp = StringToTime(StartTimeStructStr);
    datetime EndTimeTmp = StringToTime(EndTimeStructStr);

    if (StartTimeTmp > EndTimeTmp)
    {
        EndTimeTmp += PeriodSeconds(PERIOD_D1);
    }
    while ((StartTimeTmp > MaxTime) && (iClose(Symbol(), PERIOD_CURRENT, iBarShiftCustom(Symbol(), PERIOD_CURRENT, StartTimeTmp)) > 0))
    {
        TimeToStruct(StartTimeTmp, StartTimeStruct);
        if (IsDayAllowed(StartTimeStruct.day_of_week)) DrawCandlesticksSession(StartTimeTmp, EndTimeTmp);
        StartTimeTmp -= PeriodSeconds(PERIOD_D1);
        EndTimeTmp -= PeriodSeconds(PERIOD_D1);
    }
    ChartRedraw();
}

void DrawCandlesticksSession(datetime Start, datetime End)
{
    int StartBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, Start);
    int EndBar = iBarShiftCustom(Symbol(), PERIOD_CURRENT, End);
    // Skip if completely in the future (not started) or a historical gap (end already passed). Allow single-bar active sessions.
    if ((StartBar == EndBar) && ((Start > iTime(Symbol(), PERIOD_CURRENT, 0)) || (End <= iTime(Symbol(), PERIOD_CURRENT, 0)))) return;
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
        string Text = SessionLabel;
        if (ShowRange)
        {
            double LowPoint = iLow(Symbol(), PERIOD_CURRENT, iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, BarsCount, EndBar));
            Text += " " + IntegerToString(int((HighPoint - LowPoint) / _Point));
        }
        SetLabel(Start, HighPoint, Text);
    }
    if (Start > LatestSessionStart) LatestSessionStart = Start;
    if (End > LatestSessionEnd) LatestSessionEnd = End;

    // Track the most recent completed session for incremental redraw.
    if ((Start > NewestCompletedSessionStart) && (iTime(Symbol(), PERIOD_CURRENT, 0) >= End))
    {
        NewestCompletedSessionStart = Start;
    }
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
    ChartRedraw();
}

// Check if the current bar crosses a session start or end boundary and fire notifications.
// Called only on new bar events, never during initial history redraw.
void CheckNotifications()
{
    if ((!SendAlert) && (!SendApp) && (!SendEmail) && (!SendSound)) return;
    if ((!NotifyOnSessionStart) && (!NotifyOnSessionEnd)) return;

    datetime barTime = iTime(Symbol(), PERIOD_CURRENT, 0);
    datetime prevBarTime = iTime(Symbol(), PERIOD_CURRENT, 1);

    // Don't re-alert for the same bar.
    if (barTime <= LastNotificationTime) return;

    // Check the day-of-week filter.
    MqlDateTime barStruct;
    TimeToStruct(barTime, barStruct);
    if (!IsDayAllowed(barStruct.day_of_week)) return;

    // Compute today's session start time.
    string todayStartStr = (string)barStruct.year + "." + (string)barStruct.mon + "." + (string)barStruct.day + " " + (string)StartHour + ":" + (string)StartMinute;
    SessionStartToday = StringToTime(todayStartStr);

    // Session start: bar[0] is at or past the start, but bar[1] was before it.
    if ((NotifyOnSessionStart) && (barTime >= SessionStartToday) && (prevBarTime < SessionStartToday))
    {
        string label = (SessionLabel != "") ? SessionLabel : IndicatorName;
        Notify(label + " session started");
        LastNotificationTime = barTime;
    }

    // Session end is only relevant when an end time is configured.
    if ((NotifyOnSessionEnd) && (TimeLineEnd != ""))
    {
        string todayEndStr = (string)barStruct.year + "." + (string)barStruct.mon + "." + (string)barStruct.day + " " + (string)EndHour + ":" + (string)EndMinute;
        SessionEndToday = StringToTime(todayEndStr);
        // Handle overnight sessions where end < start.
        if (SessionEndToday <= SessionStartToday) SessionEndToday += PeriodSeconds(PERIOD_D1);

        if ((barTime >= SessionEndToday) && (prevBarTime < SessionEndToday))
        {
            string label = (SessionLabel != "") ? SessionLabel : IndicatorName;
            Notify(label + " session ended");
            LastNotificationTime = barTime;
        }
    }
}

void Notify(string message)
{
    string EmailSubject = IndicatorName + " " + Symbol() + " Notification";
    string EmailBody = AccountInfoString(ACCOUNT_COMPANY) + " - " + AccountInfoString(ACCOUNT_NAME) + " - " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\r\n" + IndicatorName + " Notification for " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + "\r\n";
    string AppText = AccountInfoString(ACCOUNT_COMPANY) + " - " + AccountInfoString(ACCOUNT_NAME) + " - " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + " - " + IndicatorName + " - " + Symbol() + " @ " + EnumToString((ENUM_TIMEFRAMES)Period()) + " - ";

    EmailBody += message;
    AppText += message;

    if (SendAlert) Alert(message);
    if (SendEmail)
    {
        if (!SendMail(EmailSubject, EmailBody)) Print("Error sending email " + IntegerToString(GetLastError()));
    }
    if (SendApp)
    {
        if (!SendNotification(AppText)) Print("Error sending notification " + IntegerToString(GetLastError()));
    }
    if (SendSound)
    {
        PlaySound(SoundFile);
    }
}

bool IsDayAllowed(int day_of_week)
{
    switch(day_of_week)
    {
        case 0: return ShowSunday;
        case 1: return ShowMonday;
        case 2: return ShowTuesday;
        case 3: return ShowWednesday;
        case 4: return ShowThursday;
        case 5: return ShowFriday;
        case 6: return ShowSaturday;
    }
    return false;
}

void SetLabel(datetime time, double price, string text)
{
    string LabelName = IndicatorName + "-LABEL-" + IntegerToString(time);
    ObjectCreate(0, LabelName, OBJ_TEXT, 0, time, price);
    ObjectSetInteger(0, LabelName, OBJPROP_COLOR, LineColor);
    ObjectSetInteger(0, LabelName, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, LabelName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, LabelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, LabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
    ObjectSetString(0, LabelName, OBJPROP_FONT, "Consolas");
    ObjectSetInteger(0, LabelName, OBJPROP_FONTSIZE, 10);        
    ObjectSetString(0, LabelName, OBJPROP_TEXT, text);
}

int iBarShiftCustom(string symbol, ENUM_TIMEFRAMES tf, datetime time) // Always exact = false.
{
    int i = iBarShift(symbol, tf, time); // Try traditional first.
    if (i >= 0) return i; // Success.
    else i = 0; // Failed, start from zero.
    int bars = iBars(symbol, tf);
    while (iTime(symbol, tf, i) > time)
    {
        i++;
        if (i >= bars) return -1;
    }
    return i;
}
//+------------------------------------------------------------------+