unit ALFmxInertialMovement;

{$IF CompilerVersion > 34} // sydney
  {$MESSAGE WARN 'Check if FMX.InertialMovement.pas was not updated and adjust the IFDEF'}
{$ENDIF}

interface

{$SCOPEDENUMS ON}

uses
  System.Types,
  System.UITypes,
  System.Classes,
  System.Generics.Collections,
  System.Messaging,
  System.TypInfo,
  {$IFDEF DEBUG}
  system.diagnostics,
  {$ENDIF}
  {$IFDEF IOS}
  Macapi.ObjectiveC,
  iOSapi.Foundation,
  iOSapi.QuartzCore,
  {$ENDIF}
  {$IFDEF ANDROID}
  Androidapi.JNIBridge,
  ALAndroidApi,
  {$ENDIF}
  FMX.Types,
  ALCommon;

type

  TALScrollingAcquiredMessage = class(TMessage)
  private
    FAcquired: boolean;
  public
    constructor Create(const AAcquired: boolean);
    property Acquired: boolean read FAcquired;
  end;

const
  ALDefaultStorageTime = 0.15;
  ALDefaultIntervalOfAni = 10; // << on ios this is not use because we synch via cadisplaylink. however on android
                               // << this will be not exact time between each timerproc,
                               // << because the onpaint is bound to the fps (60), so every onpaint
                               // << must wait the vsync signal (every 16.6 ms), so the intervalOfAni
                               // << will be generally not less than 16.6 ms
                               // << but also it's can produce strange bug: https://quality.embarcadero.com/browse/RSP-18982
  ALDecelerationRateNormal = 1.95;
  ALDecelerationRateFast = 9.5;
  ALDefaultElasticity = 100;
  ALDefaultMinVelocity = 10;
  ALDefaultMaxVelocity = 5000;
  ALDefaultDeadZone = 8;
  ALDefaultVelocityFactor = 1;

type

  TALAniCalculations = class(TPersistent)
  public type
    TTargetType = (Achieved, Max, Min, Other);
    TTarget = record
      TargetType: TTargetType;
      Point: TALPointD;
    end;
  private type
    TPointTime = record
      Point: TALPointD;
      Time: TDateTime;
    end;
  {$IFDEF IOS}

  private type
    IDisplayLinkListener = interface(NSObject)
    ['{810AD3F0-265C-4A73-9B96-74103268884A}']
      procedure displayLinkUpdated; cdecl;
    end;

    TDisplayLinkListener = class(TOCLocal)
    private
      [Weak] fAniCalculations: TALAniCalculations;
    protected
      function GetObjectiveCClass: PTypeInfo; override;
    public
      constructor Create(const aAniCalculations: TALAniCalculations);
      procedure displayLinkUpdated; cdecl;
    end;

  private
    fDisplayLink: CADisplayLink;
    fDisplayLinkListener: TDisplayLinkListener;

  {$ELSEIF defined(ANDROID)}

  private type
    TChoreographerFrameCallback = class(TJavaLocal, JChoreographer_FrameCallback)
    private
      [Weak] fAniCalculations: TALAniCalculations;
    public
      constructor Create(const aAniCalculations: TALAniCalculations);
      procedure doFrame(frameTimeNanos: Int64); cdecl;
    end;

  private
    FChoreographer: JChoreographer;
    FChoreographerFrameCallback: TChoreographerFrameCallback;

  {$ELSE}

  private
    FTimerHandle: TFmxHandle;

  {$ENDIF}
  private
    FTimerActive: Boolean;
    FVelocityFactor: Double;
    FEnabled: Boolean;
    FInTimerProc: Boolean;
    FTouchTracking: TTouchTracking;
    FInterval: Word;
    FCurrentVelocity: TALPointD;
    FUpVelocity: TALPointD;
    FUpPosition: TALPointD;
    FUpDownTime: TDateTime;
    FlastTickCalc: Double;
    FLastTimeCalc: TDateTime;
    [Weak] FOwner: TPersistent;
    FPlatformTimer: IFMXTimerService;
    FPointTime: TList<TPointTime>;
    FTargets: array of TTarget;
    FMinTarget: TTarget;
    FMaxTarget: TTarget;
    FTarget: TTarget;
    FLastTarget: TTarget;
    FCancelTargetX: Boolean;
    FCancelTargetY: Boolean;
    FOnStart: TNotifyEvent;
    FOnTimer: TNotifyEvent;
    FOnChanged: TNotifyEvent;
    FOnStop: TNotifyEvent;
    FDown: Boolean;
    FAnimation: Boolean;
    FViewportPosition: TALPointD;
    FLowChanged: Boolean;
    FLastTimeChanged: TDateTime;
    FDownPoint: TALPointD;
    FDownPosition: TALPointD;
    FUpdateTimerCount: Integer;
    FElasticity: Double;
    FDecelerationRate: Double;
    FStorageTime: Double;
    FInDoStart: Boolean;
    FInDoStop: Boolean;
    FMoved: Boolean;
    FStarted: Boolean;
    FBoundsAnimationAtMinTarget: Boolean;
    FBoundsAnimationAtMaxTarget: Boolean;
    FAutoShowing: Boolean;
    FOpacity: Single;
    FShown: Boolean;
    FMouseTarget: TTarget;
    FAveraging: Boolean;
    FMinVelocity: Integer;
    FMaxVelocity: Integer;
    FDeadZone: Integer;
    FUpdateCount: Integer;
    FElasticityFactor: TPoint;
    FOnCalcVelocity: TNotifyEvent;
    {$IFDEF DEBUG}
    //fTimerProcStopWatch: TstopWatch;
    {$ENDIF}
    procedure StartTimer;
    procedure StopTimer;
    procedure Clear(T: TDateTime = 0);
    procedure UpdateTimer;
    procedure SetInterval(const Value: Word);
    procedure SetEnabled(const Value: Boolean);
    procedure SetTouchTracking(const Value: TTouchTracking);
    procedure InternalCalc(DeltaTime: Double);
    procedure SetAnimation(const Value: Boolean);
    procedure SetDown(const Value: Boolean);
    function FindTarget(var Target: TTarget): Boolean;
    function GetTargetCount: Integer;
    function DecelerationRateStored: Boolean;
    function ElasticityStored: Boolean;
    function StorageTimeStored: Boolean;
    function VelocityFactorStored: boolean;
    procedure CalcVelocity(const Time: TDateTime = 0);
    procedure InternalStart;
    procedure InternalTerminated;
    function GetBoundsAnimation: Boolean;
    procedure SetBoundsAnimation(const Value: Boolean);
    procedure SetBoundsAnimationAtMinTarget(const Value: Boolean);
    procedure SetBoundsAnimationAtMaxTarget(const Value: Boolean);
    procedure UpdateViewportPositionByBounds;
    procedure SetAutoShowing(const Value: Boolean);
    procedure SetShown(const Value: Boolean);
    function GetViewportPositionF: TPointF;
    procedure SetViewportPositionF(const Value: TPointF);
    procedure SetMouseTarget(Value: TTarget);
    function GetInternalTouchTracking: TTouchTracking;
    function GetPositions(const Index: Integer): TALPointD;
    function GetPositionCount: Integer;
    function GetPositionTimes(const Index: Integer): TDateTime;
    function PosToView(const APosition: TALPointD): TALPointD;
    procedure SetViewportPosition(const Value: TALPointD);
    function GetOpacity: Single;
    function GetLowVelocity: Boolean;
    function AddPointTime(const X, Y: Double; const Time: TDateTime = 0): TPointTime;
    procedure InternalChanged;
    procedure UpdateTarget;
    function DoStopScrolling(CurrentTime: TDateTime = 0): Boolean;
  protected
    function IsSmall(const P: TALPointD; const Epsilon: Double): Boolean; overload;
    function IsSmall(const P: TALPointD): Boolean; overload;
    function GetOwner: TPersistent; override;
    procedure DoStart; virtual;
    procedure DoChanged; virtual;
    procedure DoStop; virtual;
    procedure DoCalc(const DeltaTime: Double; var NewPoint, NewVelocity: TALPointD; var Done: Boolean); virtual;
    property Enabled: Boolean read FEnabled write SetEnabled;
    property Shown: Boolean read FShown write SetShown;
    property MouseTarget: TTarget read FMouseTarget write SetMouseTarget;
    property InternalTouchTracking: TTouchTracking read GetInternalTouchTracking;
    property Positions[const index: Integer]: TALPointD read GetPositions;
    property PositionTimes[const index: Integer]: TDateTime read GetPositionTimes;
    property PositionCount: Integer read GetPositionCount;
    property UpVelocity: TALPointD read FUpVelocity;
    property UpPosition: TALPointD read FUpPosition;
    property UpDownTime: TDateTime read FUpDownTime;
    property Target: TTarget read FTarget;
    property MinVelocity: Integer read FMinVelocity write FMinVelocity default ALDefaultMinVelocity;
    property MaxVelocity: Integer read FMaxVelocity write FMaxVelocity default ALDefaultMaxVelocity;
    property CancelTargetX: Boolean read FCancelTargetX;
    property CancelTargetY: Boolean read FCancelTargetY;
  public
    constructor Create(AOwner: TPersistent); virtual;
    destructor Destroy; override;
    procedure AfterConstruction; override;
    procedure Assign(Source: TPersistent); override;
    {$IF not defined(IOS)}
    procedure TimerProc;
    {$ENDIF}
    procedure MouseDown(X, Y: Double); virtual;
    procedure MouseMove(X, Y: Double); virtual;
    procedure MouseLeave; virtual;
    procedure MouseUp(X, Y: Double); virtual;
    procedure MouseWheel(X, Y: Double); virtual;
    property Animation: Boolean read FAnimation write SetAnimation default False;
    property AutoShowing: Boolean read FAutoShowing write SetAutoShowing default False;
    property Averaging: Boolean read FAveraging write FAveraging default False;
    property BoundsAnimation: Boolean read GetBoundsAnimation write SetBoundsAnimation default True;
    property BoundsAnimationAtMinTarget: Boolean read FBoundsAnimationAtMinTarget write SetBoundsAnimationAtMinTarget default True;
    property BoundsAnimationAtMaxTarget: Boolean read FBoundsAnimationAtMaxTarget write SetBoundsAnimationAtMaxTarget default True;
    property TouchTracking: TTouchTracking read FTouchTracking write SetTouchTracking default [ttVertical, ttHorizontal];
    property TargetCount: Integer read GetTargetCount;
    procedure SetTargets(const ATargets: array of TTarget);
    procedure GetTargets(var ATargets: array of TTarget);
    property MinTarget: TTarget read FMinTarget;
    property MaxTarget: TTarget read FMaxTarget;
    procedure UpdatePosImmediately(const Force: Boolean = False);
    property CurrentVelocity: TALPointD read FCurrentVelocity write FCurrentVelocity;
    property ViewportPosition: TALPointD read FViewportPosition write SetViewportPosition;
    property ViewportPositionF: TPointF read GetViewportPositionF write SetViewportPositionF;
    property DownPosition: TALPointD read fDownPosition write fDownPosition;
    property LastTimeCalc: TDateTime read FLastTimeCalc;
    property Down: Boolean read FDown write SetDown;
    property Opacity: Single read GetOpacity;
    property InTimerProc: Boolean read FInTimerProc;
    Procedure WakeUpTimer;
    Procedure Calculate; // when Ontimer is set (an event that just need to call repaint/invalidate), then in the onpaint of the control we must manually call Calculate
                         // this because of this problem: https://stackoverflow.com/questions/46146006/why-calling-setneedsdisplay-from-a-nstimer-make-cadisplaylink-stop-to-work-corre
                         // i do also like this because between the time to receive the ontimer event, then we calculate new position and then we call repaint AND the time we
                         // will actually repaint the form they could be a delay. so in this way callling calculate from the onpaint and we are sure we have the most accurate
                         // position to draw. NOTE: If onTimer is not set, no need to call calculate because it's will be call automatically on each timerproc
    property Moved: Boolean read FMoved;
    property LowVelocity: Boolean read GetLowVelocity;
    procedure BeginUpdate;
    procedure EndUpdate;
    property UpdateCount: Integer read FUpdateCount;
    property OnStart: TNotifyEvent read FOnStart write FOnStart;
    property OnTimer: TNotifyEvent read FOnTimer write FOnTimer; // in this event, you just need to call repaint (on the related control).
                                                                 // then later in the onpaint of the related control you will need to call Calculate
                                                                 // this because of this problem: https://stackoverflow.com/questions/46146006/why-calling-setneedsdisplay-from-a-nstimer-make-cadisplaylink-stop-to-work-corre
                                                                 // i do also like this because between the time to receive the ontimer event, then we calculate new position and then we call repaint AND the time we
                                                                 // will actually repaint the form they could be a delay. so in this way callling calculate from the onpaint and we are sure we have the most accurate
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
    property OnStop: TNotifyEvent read FOnStop write FOnStop;
    property DeadZone: Integer read FDeadZone write FDeadZone default ALDefaultDeadZone;
    property TimerActive: boolean read FTimerActive;
  published
    property Interval: Word read FInterval write SetInterval default ALDefaultIntervalOfAni;
    property DecelerationRate: Double read FDecelerationRate write FDecelerationRate stored DecelerationRateStored nodefault;
    property Elasticity: Double read FElasticity write FElasticity stored ElasticityStored nodefault;
    property StorageTime: Double read FStorageTime write FStorageTime stored StorageTimeStored nodefault;
    property VelocityFactor: Double read FVelocityFactor write FVelocityFactor stored VelocityFactorStored nodefault; // << this is a factor to apply to the calculated velocity of the scroll (to boost a the velocity)
    property OnCalcVelocity: TNotifyEvent read FOnCalcVelocity write FOnCalcVelocity; // << we this you can dynamically calc the velocity
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.RTLConsts,
  System.Math.Vectors,
  {$IFDEF DEBUG}
  AlString,
  {$ENDIF}
  {$IFDEF ANDROID}
  Androidapi.AppGlue,
  Androidapi.Looper,
  Fmx.platform.Android,
  {$ENDIF}
  {$IFDEF IOS}
  Macapi.CoreFoundation,
  Macapi.ObjCRuntime,
  {$ENDIF}
  FMX.Consts,
  FMX.Platform;

const
  ALEpsilonPoint = TEpsilon.Position;
  ALDefaultOpacityTime = 0.3;
  ALMaxOpacity = 1.5;
  ALEpsilonTime = 0; // 0.01; => https://quality.embarcadero.com/browse/RSP-18982
  ALStopTime = 0.007;

var
  ALEpsilonRange: Integer;

{************************************************************************************}
function ALAniSign(const CurrentValue, TargetValue, EpsilonPoint: Double): TValueSign;
begin
  Result := -CompareValue(CurrentValue, TargetValue, EpsilonPoint);
end;

{$IFDEF IOS}

{*****************************************************************************************************}
constructor TALAniCalculations.TDisplayLinkListener.Create(const aAniCalculations: TALAniCalculations);
begin
  inherited Create;
  fAniCalculations := aAniCalculations;
end;

{*******************************************************************}
procedure TALAniCalculations.TDisplayLinkListener.displayLinkUpdated;
begin
  if not fAniCalculations.Down then
  begin
    if assigned(fAniCalculations.fOnTimer) then
      fAniCalculations.fOnTimer(fAniCalculations)
    else
      fAniCalculations.Calculate;
  end;
end;

{*****************************************************************************}
function TALAniCalculations.TDisplayLinkListener.GetObjectiveCClass: PTypeInfo;
begin
  Result := TypeInfo(IDisplayLinkListener);
end;

{$ENDIF}

{$IF defined(ANDROID)}

{************************************************************************************************************}
constructor TALAniCalculations.TChoreographerFrameCallback.Create(const aAniCalculations: TALAniCalculations);
 begin
  inherited Create;
  fAniCalculations := aAniCalculations;
end;

{**************************************************************************************}
procedure TALAniCalculations.TChoreographerFrameCallback.doFrame(frameTimeNanos: Int64);
begin
  {$IFDEF DEBUG}
  //ALLog('TALAniCalculations.TChoreographerFrameCallback.doFrame', 'ThreadID: ' + alIntToStrU(TThread.Current.ThreadID) + '/' + alIntToStrU(MainThreadID), TalLogType.verbose);
  {$ENDIF}

  if assigned(fAniCalculations.fOnTimer) then
    fAniCalculations.fOnTimer(fAniCalculations)
  else
    fAniCalculations.Calculate;

  if fAniCalculations.FTimerActive then
    fAniCalculations.fChoreographer.postFrameCallback(self);
end;

{$ENDIF}

{*********************************************************}
constructor TALAniCalculations.Create(AOwner: TPersistent);
begin
  inherited Create;
  FOwner := AOwner;
  {$IFDEF IOS}
  fDisplayLinkListener := TDisplayLinkListener.Create(self);
  fDisplayLink := TCADisplayLink.Wrap(TCADisplayLink.OCClass.displayLinkWithTarget(fDisplayLinkListener.GetObjectID, sel_getUid('displayLinkUpdated')));
  fDisplayLink.retain;
  fDisplayLink.addToRunLoop(TNSRunLoop.Wrap(TNSRunLoop.OCClass.currentRunLoop), NSRunLoopCommonModes); // I don't really know with is the best, NSDefaultRunLoopMode or NSRunLoopCommonModes
  fDisplayLink.setPaused(true);
  {$ELSEIF defined(ANDROID)}
  fChoreographer := TJChoreographer.JavaClass.getInstance;
  fChoreographerFrameCallback := TChoreographerFrameCallback.create(self);
  {$ELSE}
  FTimerHandle := TFmxHandle(-1);
  {$ENDIF}
  FTimerActive := False;
  BeginUpdate;
  FPointTime := TList<TPointTime>.Create;
  if not TPlatformServices.Current.SupportsPlatformService(IFMXTimerService, FPlatformTimer) then
    raise EUnsupportedPlatformService.Create('IFMXTimerService');
  Assign(nil);
end;

{************************************}
destructor TALAniCalculations.Destroy;
begin
  StopTimer;
  {$IFDEF IOS}
  fDisplayLink.invalidate; // Removes the display link from all run loop modes.
                           // Removing the display link from all run loop modes causes it to be released by the run loop. The display link also releases the target.
                           // invalidate is thread safe meaning that it can be called from a thread separate to the one in which the display link is running.
  fDisplayLink.release;
  AlFreeAndNil(fDisplayLinkListener);
  {$ELSEIF defined(ANDROID)}
  alFreeAndNil(fChoreographerFrameCallback);
  {$ENDIF}
  ALFreeAndNil(FPointTime);
  inherited;
end;

{*********************************************}
procedure TALAniCalculations.AfterConstruction;
begin
  inherited;
  if not AutoShowing then
    FOpacity := ALMaxOpacity;
  EndUpdate;
end;

{*******************************************************}
procedure TALAniCalculations.Assign(Source: TPersistent);
var
  LSource: TALAniCalculations;
  LTargets: array of TTarget;
begin
  if Source is TALAniCalculations then
  begin
    LSource := TALAniCalculations(Source);
    MinVelocity := LSource.MinVelocity;
    MaxVelocity := LSource.MaxVelocity;
    DeadZone := LSource.DeadZone;
    Animation := LSource.Animation;
    AutoShowing := LSource.AutoShowing;
    Averaging := LSource.Averaging;
    BoundsAnimationAtMinTarget := LSource.BoundsAnimationAtMinTarget;
    BoundsAnimationAtMaxTarget := LSource.BoundsAnimationAtMaxTarget;
    Interval := LSource.Interval;
    TouchTracking := LSource.TouchTracking;
    SetLength(LTargets, LSource.TargetCount);
    LSource.GetTargets(LTargets);
    SetTargets(LTargets);
    DecelerationRate := LSource.DecelerationRate;
    Elasticity := LSource.Elasticity;
    StorageTime := LSource.StorageTime;
    VelocityFactor := LSource.VelocityFactor;
  end
  else if Source = nil then
  begin
    MinVelocity := ALDefaultMinVelocity;
    MaxVelocity := ALDefaultMaxVelocity;
    DeadZone := ALDefaultDeadZone;
    Animation := False;
    AutoShowing := False;
    Averaging := False;
    BoundsAnimationAtMinTarget := True;
    BoundsAnimationAtMaxTarget := True;
    Interval := ALDefaultIntervalOfAni;
    TouchTracking := [ttVertical, ttHorizontal];
    SetTargets([]);
    DecelerationRate := ALDecelerationRateNormal;
    Elasticity := ALDefaultElasticity;
    StorageTime := ALDefaultStorageTime;
    VelocityFactor := ALDefaultVelocityFactor;
  end
  else
    inherited;
end;

{*******************************************************************}
function TALAniCalculations.GetInternalTouchTracking: TTouchTracking;
begin
  Result := FTouchTracking;
  if FMouseTarget.TargetType = TTargetType.Other then
  begin
    if not SameValue(FMouseTarget.Point.X, FViewportPosition.X, ALEpsilonPoint)
    then
      Result := Result + [ttHorizontal];
    if not SameValue(FMouseTarget.Point.Y, FViewportPosition.Y, ALEpsilonPoint)
    then
      Result := Result + [ttVertical];
  end;
end;

{*********************************************}
function TALAniCalculations.GetOpacity: Single;
begin
  Result := Min(1, Max(0, FOpacity));
end;

{************************************************}
function TALAniCalculations.GetOwner: TPersistent;
begin
  Result := FOwner;
end;

{**************************************************************}
procedure TALAniCalculations.SetAnimation(const Value: Boolean);
begin
  if FAnimation <> Value then
  begin
    FAnimation := Value;
    FLastTimeCalc := 0;
    FCurrentVelocity := TALPointD.Create(0, 0);
    UpdateTimer;
    if (not Animation) then
      UpdatePosImmediately(True);
  end;
end;

{******************************************************}
function TALAniCalculations.GetBoundsAnimation: Boolean;
begin
  result := FBoundsAnimationAtMinTarget and
            FBoundsAnimationAtMaxTarget;
end;

{********************************************************************}
procedure TALAniCalculations.SetBoundsAnimation(const Value: Boolean);
begin
  if (FBoundsAnimationAtMinTarget <> Value) or
     (FBoundsAnimationAtMaxTarget <> Value) then
  begin
    FBoundsAnimationAtMinTarget := Value;
    FBoundsAnimationAtMaxTarget := Value;
    SetViewportPosition(ViewportPosition);
  end;
end;

{*******************************************************************************}
procedure TALAniCalculations.SetBoundsAnimationAtMinTarget(const Value: Boolean);
begin
  if FBoundsAnimationAtMinTarget <> Value then
  begin
    FBoundsAnimationAtMinTarget := Value;
    SetViewportPosition(ViewportPosition);
  end;
end;

{*******************************************************************************}
procedure TALAniCalculations.SetBoundsAnimationAtMaxTarget(const Value: Boolean);
begin
  if FBoundsAnimationAtMaxTarget <> Value then
  begin
    FBoundsAnimationAtMaxTarget := Value;
    SetViewportPosition(ViewportPosition);
  end;
end;

{*********************************************************}
procedure TALAniCalculations.SetDown(const Value: Boolean);
var
  LTarget: TTarget;
  T: TDateTime;
begin
  if FDown <> Value then
  begin
    T := FPlatformTimer.getTick/SecsPerDay;
    if Value then
    begin
      FDown := Value;
      FPointTime.Clear;
      if not Averaging then
        FCurrentVelocity := TALPointD.Create(0, 0);
      FLastTimeCalc := 0;
      FUpDownTime := T;
      LTarget.TargetType := TTargetType.Achieved;
      LTarget.Point := TALPointD.Create(0, 0);
      SetMouseTarget(LTarget);
    end
    else
    begin
      try
        DoStopScrolling(T);
        FUpDownTime := T;
      finally
        FDown := Value;
      end;
    end;
    UpdateTimer;
    if (not FDown) and (not Animation) and (InternalTouchTracking <> []) then
      UpdatePosImmediately;
  end;
end;

{*****************************************}
procedure TALAniCalculations.InternalStart;
begin
  if (not FInDoStart) and (not FStarted) then
  begin
    FInDoStart := True;
    try
      DoStart;
      FStarted := True;
    finally
      FInDoStart := False;
    end;
  end;
end;

{**********************************************}
procedure TALAniCalculations.InternalTerminated;
var
  LTarget: TTarget;
begin
  if (not FInDoStop) and (FStarted) then
  begin
    FInDoStop := True;
    try
      LTarget.TargetType := TTargetType.Achieved;
      LTarget.Point := TALPointD.Create(0, 0);
      SetMouseTarget(LTarget);
      DoStop;
      FStarted := False;
    finally
      FInDoStop := False;
    end;
  end;
end;

{**************************************************************************************}
function TALAniCalculations.IsSmall(const P: TALPointD; const Epsilon: Double): Boolean;
var
  LTouchTracking: TTouchTracking;
begin
  LTouchTracking := InternalTouchTracking;
  if LTouchTracking = [ttVertical, ttHorizontal] then
    Result := P.Abs < Epsilon
  else if LTouchTracking = [ttVertical] then
    Result := System.Abs(P.Y) < Epsilon
  else if LTouchTracking = [ttHorizontal] then
    Result := System.Abs(P.X) < Epsilon
  else
    Result := True
end;

{***************************************************************}
function TALAniCalculations.IsSmall(const P: TALPointD): Boolean;
begin
  Result := IsSmall(P, ALEpsilonPoint);
end;

{************************************************************}
procedure TALAniCalculations.SetEnabled(const Value: Boolean);
begin
  if FEnabled <> Value then
  begin
    if Value and (FInterval > 0) then
    begin
      if UpdateCount = 0 then
      begin
        InternalStart;
        StartTimer;
        FEnabled := Value;
      end;
    end
    else
    begin
      StopTimer;
      FEnabled := Value;
      InternalTerminated;
    end;
  end;
end;

{**********************************************************}
procedure TALAniCalculations.SetInterval(const Value: Word);
begin
  if FInterval <> Value then
  begin
    StopTimer;
    FInterval := Value;
    if FEnabled and (FInterval > 0) and (UpdateCount <= 0) then
      StartTimer;
  end;
end;

{********************************************************}
function TALAniCalculations.GetViewportPositionF: TPointF;
begin
  Result.X := FViewportPosition.X;
  Result.Y := FViewportPosition.Y;
end;

{***********************************************************************}
procedure TALAniCalculations.SetViewportPosition(const Value: TALPointD);
var
  LChanged: Boolean;
  LOldViewportPosition: TALPointD;
  LTarget: TTarget;
begin
  LOldViewportPosition := FViewportPosition;
  FViewportPosition := Value;
  UpdateViewportPositionByBounds;
  LChanged := FViewportPosition <> LOldViewportPosition;
  if LChanged and (not FInTimerProc) then
  begin
    LTarget.TargetType := TTargetType.Achieved;
    LTarget.Point := TALPointD.Create(0, 0);
    SetMouseTarget(LTarget);
    if Down then
      InternalChanged
    else
    begin
      UpdateTimer;
      InternalChanged;
    end;
  end;
end;

{**********************************************************************}
procedure TALAniCalculations.SetViewportPositionF(const Value: TPointF);
var
  NewValue: TALPointD;
begin
  NewValue := TALPointD.Create(Value);
  ViewportPosition := NewValue;
end;

{*************************************************************************}
procedure TALAniCalculations.SetTouchTracking(const Value: TTouchTracking);
begin
  if FTouchTracking <> Value then
  begin
    FTouchTracking := Value;
    UpdateTimer;
  end;
end;

{**********************************************************}
procedure TALAniCalculations.SetShown(const Value: Boolean);
var
  NewVisible, ChangeOpacity: Boolean;
begin
  NewVisible := (not AutoShowing) or (Value);
  ChangeOpacity := ((FOpacity < ALMaxOpacity) and (NewVisible)) or
                   ((FOpacity > 0) and (not NewVisible));
  FShown := Value;
  if ChangeOpacity then
  begin
    FUpdateTimerCount := -1;
    UpdateTimer;
  end;
end;

{**************************************}
procedure TALAniCalculations.StartTimer;
begin

  if FTimerActive then exit;
  {$IFDEF DEBUG}
  //ALLog('TALAniCalculations.StartTimer', 'TALAniCalculations.StartTimer', TalLogType.verbose);
  {$ENDIF}
  FlastTickCalc := FPlatformTimer.getTick;
  FTimerActive := True;

  {$IFDEF IOS}
  fDisplayLink.setPaused(False);
  {$ELSEIF defined(ANDROID)}
  fChoreographer.postFrameCallback(fChoreographerFrameCallback);
  {$ELSE}
  if FTimerHandle = TFmxHandle(-1) then
  begin
    FTimerHandle := FPlatformTimer.CreateTimer(FInterval, TimerProc);
  end;
  {$ENDIF}

end;

{*************************************}
procedure TALAniCalculations.StopTimer;
begin

  if not FTimerActive then exit;
  {$IFDEF DEBUG}
  //ALLog('TALAniCalculations.StopTimer', 'TALAniCalculations.StopTimer', TalLogType.verbose);
  {$ENDIF}
  FTimerActive := False;

  {$IFDEF IOS}
  fDisplayLink.setPaused(True);
  {$ELSEIF defined(ANDROID)}
  fChoreographer.removeFrameCallback(fChoreographerFrameCallback);
  {$ELSE}
  if FTimerHandle <> TFmxHandle(-1) then
  begin
    FPlatformTimer.DestroyTimer(FTimerHandle);
    FTimerHandle := TFmxHandle(-1);
  end;
  {$ENDIF}

end;

{********************************************************************************************************************}
procedure TALAniCalculations.DoCalc(const DeltaTime: Double; var NewPoint, NewVelocity: TALPointD; var Done: Boolean);
var
  EnableTargetX: Boolean;
  EnableTargetY: Boolean;
  procedure UpdatePhysicalParameters(const Target: Double; var Pos, Velocity: Double; const ADecelerationRate: Double;
    const EnableTarget: Boolean; const CancelTarget: Boolean; var ElasticityFactor: Integer);
  var
    dV, DX, aT, aTDecelerationRate, Tmp, R: Double;
    LSign, LSignV: TValueSign;
  begin
    LSign := ALAniSign(Pos, Target, ALEpsilonPoint);
    LSignV := ALAniSign(Velocity, 0, ALEpsilonPoint);
    R := Abs(Target - Pos);
    Tmp := Velocity;

    aTDecelerationRate := LSignV * ADecelerationRate;
    if EnableTarget then
    begin
      if Velocity = 0 then
        Inc(ElasticityFactor)
      else
        ElasticityFactor := 1;
      aT := (LSign * Ceil(Elasticity * ElasticityFactor * R));
      aT := aT + (aTDecelerationRate / DecelerationRate * 8);
    end
    else
    begin
      aT := aTDecelerationRate;
      ElasticityFactor := 0;
    end;

    dV := aT * DeltaTime;
    if (Velocity > 0) and (dV < 0) and (-dV > Velocity) then
      dV := -Velocity
    else if (Velocity < 0) and (dV > 0) and (dV > -Velocity) then
      dV := -Velocity;
    Velocity := Velocity + dV;
    aT := dV / DeltaTime;
    DX := Tmp * DeltaTime + (aT * Sqr(DeltaTime)) / 2;

    if EnableTarget and (not CancelTarget) then
    begin
      Tmp := Max(1, StorageTime / DeltaTime);
      if LSign = 1 then
      begin
        if (Pos + DX > Target) and (StorageTime > 0) then
          DX := (Target - Pos) / Max(1, Tmp / 3);
        Pos := Pos + DX;
      end
      else if LSign = -1 then
      begin
        if (Pos + DX < Target) and (StorageTime > 0) then
          DX := (Target - Pos) / Max(1, Tmp / 3);
        Pos := Pos + DX;
      end
      else
        Velocity := 0;
      if SameValue(Pos, Target, ALEpsilonPoint) then
      begin
        Pos := Target;
        Velocity := 0;
      end;
    end
    else
      Pos := Pos + DX;
  end;
  procedure UpdateParams;
  var
    LDecelerationRate: Double;
    AbsV: Double;
  begin
    AbsV := NewVelocity.Abs;
    if (AbsV < MinVelocity) or (DecelerationRate <= 0) then
      LDecelerationRate := 0
    else
      LDecelerationRate := DecelerationRate;

    UpdatePhysicalParameters(Target.Point.X, NewPoint.X, NewVelocity.X, Abs(LDecelerationRate * NewVelocity.X),
      EnableTargetX, CancelTargetX, FElasticityFactor.X);
    UpdatePhysicalParameters(Target.Point.Y, NewPoint.Y, NewVelocity.Y, Abs(LDecelerationRate * NewVelocity.Y),
      EnableTargetY, CancelTargetY, FElasticityFactor.Y);
  end;

begin
  if not Done then
  begin
    EnableTargetX := ([ttHorizontal] * InternalTouchTracking <> []) and
      (Target.TargetType <> TTargetType.Achieved) and
      (ALAniSign(NewPoint.X, Target.Point.X, ALEpsilonPoint) <> 0);

    EnableTargetY := ([ttVertical] * InternalTouchTracking <> []) and
      (Target.TargetType <> TTargetType.Achieved) and
      (ALAniSign(NewPoint.Y, Target.Point.Y, ALEpsilonPoint) <> 0);

    UpdateParams;
  end;
end;

{***********************************}
procedure TALAniCalculations.DoStart;
begin
  if Assigned(FOnStart) then
    FOnStart(self);
end;

{*************************************}
procedure TALAniCalculations.DoChanged;
begin
  if Assigned(FOnChanged) then
    FOnChanged(self);
end;

{****************************************************}
function TALAniCalculations.ElasticityStored: Boolean;
begin
  Result := not SameValue(FElasticity, ALDefaultElasticity);
end;

{***************************************}
procedure TALAniCalculations.BeginUpdate;
begin
  Inc(FUpdateCount);
end;

{*************************************}
procedure TALAniCalculations.EndUpdate;
begin
  if FUpdateCount > 0 then
    Dec(FUpdateCount);
end;

{**********************************************************}
function TALAniCalculations.DecelerationRateStored: Boolean;
begin
  Result := not SameValue(FDecelerationRate, ALDecelerationRateNormal);
end;

{*****************************************************}
function TALAniCalculations.StorageTimeStored: Boolean;
begin
  Result := not SameValue(FStorageTime, ALDefaultStorageTime);
end;

{********************************************************}
function TALAniCalculations.VelocityFactorStored: Boolean;
begin
  Result := not SameValue(fVelocityFactor, ALDefaultVelocityFactor);
end;

{**********************************}
procedure TALAniCalculations.DoStop;
begin
  if Assigned(FOnStop) then
    FOnStop(self);
end;

{*******************************************************************************}
function TALAniCalculations.DoStopScrolling(CurrentTime: TDateTime = 0): Boolean;
var
  T: Double;
begin
  if CurrentTime = 0 then
    CurrentTime := FPlatformTimer.getTick/SecsPerDay;
  T := (CurrentTime - FUpDownTime) * SecsPerDay;
  Result := Down and (not Moved) and (T >= ALStopTime);
  if Result then
  begin
    FCurrentVelocity := TALPointD.Create(0, 0);
    FPointTime.Clear;
  end;
end;

{********************}
{$IF not defined(IOS)}
procedure TALAniCalculations.TimerProc;
begin
  if assigned(fOnTimer) then fOnTimer(self) // << this must simply call repaint and in the paint event we must call Calculate
  else calculate;
end;
{$ENDIF}

{***************************************}
Procedure TALAniCalculations.WakeUpTimer;
begin
  if not FTimerActive then exit;
  if FPlatformTimer.GetTick - FlastTickCalc > 0.04 then begin // normally Calculate must be called every 0.016 seconds.
                                                              // but in heavy situation, especially on ios, the CADisplay link
                                                              // could never fire. I saw it on iphone 5 playing webRTC + filter
                                                              // the GPU was so busy that the CADisplay link never fire.
                                                              // so if it's was not called for more than 0.04 seconds (0.016*2 + 0.016/2)
                                                              // then call it again
    {$IFDEF DEBUG}
    ALLog('TALAniCalculations.WakeUpTimer', 'ThreadID: ' + alIntToStrU(TThread.Current.ThreadID) + '/' + alIntToStrU(MainThreadID), TalLogType.warn);
    {$ENDIF}
    if assigned(fOnTimer) then fOnTimer(self)
    else Calculate;
  end;
end;

{*************************************}
procedure TALAniCalculations.Calculate;
var
  D, T: TDateTime;
  IsInit: Boolean;
  DOpacity: Single;
begin

  if (FTimerActive) and (not FInTimerProc) then
  begin

    {$IFDEF DEBUG}
    //fTimerProcStopWatch.stop;
    //ALLog('TALAniCalculations.TimerProc', 'interval: '  + ALFormatFloatU('0', fTimerProcStopWatch.Elapsed.totalMilliseconds, alDefaultFormatSettingsU), TalLogType.verbose);
    //fTimerProcStopWatch := TstopWatch.StartNew;
    {$ENDIF}

    FInTimerProc := True;
    FlastTickCalc := FPlatformTimer.getTick;
    T := FlastTickCalc/SecsPerDay;
    IsInit := FLastTimeCalc > 0;
    D := T - FLastTimeCalc;
    FLastTimeCalc := T;
    try
      if (D > 0) then
      try
        D := D * SecsPerDay;
        if AutoShowing then
        begin
          DOpacity := Min(D, 2 * Interval / 1000);
          DOpacity := DOpacity / ALDefaultOpacityTime;
          if (FOpacity < ALMaxOpacity) and (Shown) then
            FOpacity := ALMaxOpacity
          else if (FOpacity > 0) and (not Shown) then
            FOpacity := Max(FOpacity - DOpacity, 0);
        end
        else
          FOpacity := ALMaxOpacity;
        if IsInit and ((D > ALEpsilonTime) or (not Down) or FLowChanged) then
        begin
          DoStopScrolling(FLastTimeCalc);
          if Animation and (not (Down and Moved)) then
            InternalCalc(D);
          InternalChanged;
          FLowChanged := False;
          UpdateTimer;
        end;
      except
        on E: Exception do
        begin
          Enabled := False;
          raise;
        end;
      end;
    finally
      FInTimerProc := False;
    end;

  end;
end;

{**************************************************}
function TALAniCalculations.GetTargetCount: Integer;
begin
  Result := Length(FTargets);
end;

{**********************************************************************}
procedure TALAniCalculations.GetTargets(var ATargets: array of TTarget);
var
  N, I: Integer;
begin
  N := Min(TargetCount, Length(ATargets));
  for I := 0 to N - 1 do
    ATargets[I] := FTargets[I];
  UpdateTimer;
end;

{************************************************************************}
procedure TALAniCalculations.SetTargets(const ATargets: array of TTarget);
  function FindMaxTarget(var Target: TTarget): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    for I := 0 to TargetCount - 1 do
      if FTargets[I].TargetType = TTargetType.Max then
      begin
        if not Result then
        begin
          Target := FTargets[I];
          Result := True;
        end
        else
        begin
          if (Target.Point.X > FTargets[I].Point.X) then
            Target.Point.X := FTargets[I].Point.X;
          if (Target.Point.Y > FTargets[I].Point.Y) then
            Target.Point.Y := FTargets[I].Point.Y;
        end;
      end;
  end;
  function FindMinTarget(var Target: TTarget): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    for I := 0 to TargetCount - 1 do
      if FTargets[I].TargetType = TTargetType.Min then
      begin
        if not Result then
        begin
          Target := FTargets[I];
          Result := True;
        end
        else
        begin
          if (Target.Point.X < FTargets[I].Point.X) then
            Target.Point.X := FTargets[I].Point.X;
          if (Target.Point.Y < FTargets[I].Point.Y) then
            Target.Point.Y := FTargets[I].Point.Y;
        end;
      end;
  end;

var
  I: Integer;
begin
  SetLength(FTargets, Length(ATargets));
  for I := 0 to Length(ATargets) - 1 do
    FTargets[I] := ATargets[I];

  if not FindMinTarget(FMinTarget) then
  begin
    FMinTarget.TargetType := TTargetType.Achieved;
    FMinTarget.Point := TALPointD.Create(0, 0);
  end;
  if not FindMaxTarget(FMaxTarget) then
  begin
    FMaxTarget.TargetType := TTargetType.Achieved;
    FMaxTarget.Point := TALPointD.Create(0, 0);
  end;

  if IsSmall(FCurrentVelocity, MinVelocity) then
    FLastTimeCalc := 0;
  UpdateTimer;
  if (not FDown) and (not Animation) and (InternalTouchTracking <> []) then
    UpdatePosImmediately;
end;

{*******************************************************************}
function TALAniCalculations.FindTarget(var Target: TTarget): Boolean;
var
  MinR: Double;

  function FindMinMaxTarget(var Target: TTarget): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    Target.TargetType := TTargetType.Achieved;
    Target.Point := ViewportPosition;

    for I := 0 to TargetCount - 1 do
      if (FTargets[I].TargetType = TTargetType.Max) then
      begin
        if Target.Point.X > FTargets[I].Point.X then
        begin
          Target.Point.X := FTargets[I].Point.X;
          Result := True;
        end;
        if Target.Point.Y > FTargets[I].Point.Y then
        begin
          Target.Point.Y := FTargets[I].Point.Y;
          Result := True;
        end;
      end;
    for I := 0 to TargetCount - 1 do
      if (FTargets[I].TargetType = TTargetType.Min) then
      begin
        if Target.Point.X < FTargets[I].Point.X then
        begin
          Target.Point.X := FTargets[I].Point.X;
          Result := True;
        end;
        if Target.Point.Y < FTargets[I].Point.Y then
        begin
          Target.Point.Y := FTargets[I].Point.Y;
          Result := True;
        end;
      end;
    if Result then
      Target.TargetType := TTargetType.Min;
  end;

  procedure UpdateResult(P: TALPointD);
  var
    R: Double;
  begin
    R := ViewportPosition.Distance(P);
    if R < MinR then
    begin
      MinR := R;
      Result := True;
      Target.Point := P;
      Target.TargetType := TTargetType.Other;
    end;
  end;

var
  I: Integer;
  MinFound, MaxFound: Boolean;
  X, Y: Double;
begin
  Result := False;
  MinR := MaxInt;
  MinFound := FMinTarget.TargetType = TTargetType.Min;
  MaxFound := FMaxTarget.TargetType = TTargetType.Max;
  for I := 0 to TargetCount - 1 do
    if (FTargets[I].TargetType = TTargetType.Other) then
    begin
      if FTargets[I].Point = ViewportPosition then
      begin
        Target.Point := FTargets[I].Point;
        Target.TargetType := TTargetType.Achieved;
        Result := False;
        Exit;
      end
      else
      begin
        X := FTargets[I].Point.X;
        Y := FTargets[I].Point.Y;
        if ((not MinFound) or (MinFound and (X >= FMinTarget.Point.X))) and
          ((not MaxFound) or (MaxFound and (X <= FMaxTarget.Point.X))) and
          ((not MinFound) or (MinFound and (Y >= FMinTarget.Point.Y))) and
          ((not MaxFound) or (MaxFound and (Y <= FMaxTarget.Point.Y))) then
          UpdateResult(FTargets[I].Point);
      end;
    end;
  if Result then
  begin
    if Target.Point = ViewportPosition then
    begin
      Target.TargetType := TTargetType.Achieved;
      Result := False;
    end;
  end
  else
  begin
    if MinFound or MaxFound then
      Result := FindMinMaxTarget(Target)
    else
    begin
      Target.TargetType := TTargetType.Achieved;
      Target.Point := ViewportPosition;
    end;
  end;
end;

{****************************************}
procedure TALAniCalculations.UpdateTarget;
var
  SignPos: TValueSign;
begin
  FindTarget(FTarget);
  if (FTarget.TargetType = TTargetType.Achieved) or
    (not SameValue(FLastTarget.Point.X, FTarget.Point.X, ALEpsilonPoint)) then
    FCancelTargetX := False;
  if (FTarget.TargetType = TTargetType.Achieved) or
    (not SameValue(FLastTarget.Point.Y, FTarget.Point.Y, ALEpsilonPoint)) then
    FCancelTargetY := False;
  FLastTarget := FTarget;
  if Animation and Down and Moved and (not InTimerProc) and (PositionCount > 1) and
    (FMinTarget.TargetType <> TTargetType.Achieved) and (FMaxTarget.TargetType <> TTargetType.Achieved) and
    (FTarget.TargetType <> TTargetType.Achieved) then
  begin
    if not SameValue(FMinTarget.Point.X, FMaxTarget.Point.X, ALEpsilonPoint) then
    begin
      SignPos := System.Math.Sign(Positions[PositionCount - 1].X - Positions[PositionCount - 2].X);
      FCancelTargetX := (SignPos <> 0) and (SignPos = System.Math.Sign(ViewportPosition.X - FTarget.Point.X));
    end;
    if not SameValue(FMinTarget.Point.Y, FMaxTarget.Point.Y, ALEpsilonPoint) then
    begin
      SignPos := System.Math.Sign(Positions[PositionCount - 1].Y - Positions[PositionCount - 2].Y);
      FCancelTargetY := (SignPos <> 0) and (SignPos = System.Math.Sign(ViewportPosition.Y - FTarget.Point.Y));
    end;
  end;
end;

{**********************************************************}
procedure TALAniCalculations.UpdateViewportPositionByBounds;

  function NotBoundsAni(const Vert: Boolean; const aBoundsAnimation: Boolean): Boolean;
  begin
    if Vert then
      Result := not(aBoundsAnimation and (ttVertical in TouchTracking))
    else
      Result := not(aBoundsAnimation and (ttHorizontal in TouchTracking));
  end;

begin
  if FMinTarget.TargetType = TTargetType.Min then
  begin
    if (FViewportPosition.X < FMinTarget.Point.X) and NotBoundsAni(False, BoundsAnimationatMinTarget) then
    begin
      FViewportPosition.X := FMinTarget.Point.X;
      FCurrentVelocity.X := 0;
    end;
    if (FViewportPosition.Y < FMinTarget.Point.Y) and NotBoundsAni(True, BoundsAnimationatMinTarget) then
    begin
      FViewportPosition.Y := FMinTarget.Point.Y;
      FCurrentVelocity.Y := 0;
    end;
  end;
  if FMaxTarget.TargetType = TTargetType.Max then
  begin
    if (FViewportPosition.X > FMaxTarget.Point.X) and NotBoundsAni(False, BoundsAnimationatMaxTarget) then
    begin
      FViewportPosition.X := FMaxTarget.Point.X;
      FCurrentVelocity.X := 0;
    end;
    if (FViewportPosition.Y > FMaxTarget.Point.Y) and NotBoundsAni(True, BoundsAnimationatMaxTarget) then
    begin
      FViewportPosition.Y := FMaxTarget.Point.Y;
      FCurrentVelocity.Y := 0;
    end;
  end;
end;

{***************************************}
procedure TALAniCalculations.UpdateTimer;
var
  EnableTimer, NewVisible, ChangeOpacity, LSmall: Boolean;
  LTarget: TTarget;
begin
  EnableTimer := FUpdateTimerCount < 0;
  if not EnableTimer then
  begin
    EnableTimer := Animation and Down;
    if not EnableTimer then
    begin
      LSmall := LowVelocity;
      EnableTimer := (not LSmall) and Animation;
      if not EnableTimer then
        EnableTimer := FindTarget(LTarget);

      if EnableTimer then
        FUpdateTimerCount := 0;

      NewVisible := (not AutoShowing) or Shown;
      ChangeOpacity := ((FOpacity < ALMaxOpacity) and NewVisible) or
                       ((FOpacity > 0) and (not NewVisible));

      if (not EnableTimer) and
         (not ChangeOpacity) then
      begin
        Inc(FUpdateTimerCount);
        if FUpdateTimerCount < 3 then
          EnableTimer := True;
      end
      else
        EnableTimer := True;
    end;
  end
  else
    Inc(FUpdateTimerCount);
  Enabled := EnableTimer;
end;

{******************************************************************************}
procedure TALAniCalculations.UpdatePosImmediately(const Force: Boolean = False);
var
  NewViewportPosition, OldViewportPosition: TALPointD;
begin
  NewViewportPosition := ViewportPosition;
  OldViewportPosition := NewViewportPosition;
  try
    if FindTarget(FTarget) then
    begin
      if ttHorizontal in InternalTouchTracking then
        NewViewportPosition.X := Target.Point.X;
      if ttVertical in InternalTouchTracking then
        NewViewportPosition.Y := Target.Point.Y;
    end;
  finally
    FViewportPosition := OldViewportPosition;
  end;
  if Force or not IsSmall(TALPointD.Create(NewViewportPosition.X - OldViewportPosition.X,
    NewViewportPosition.Y - OldViewportPosition.Y)) then
  begin
    FCurrentVelocity := TALPointD.Create(0, 0);
    FViewportPosition := NewViewportPosition;
    UpdateViewportPositionByBounds;
    FUpdateTimerCount := -1;
    UpdateTimer;
  end;
end;

{***********************************************************}
procedure TALAniCalculations.InternalCalc(DeltaTime: Double);
var
  NewPoint, NewVelocity: TALPointD;
  Done: Boolean;
  LMinVelocity: Double;
begin
  NewPoint := ViewportPosition;
  NewVelocity := FCurrentVelocity;
  FindTarget(FTarget);
  Done := False;
  UpdateTarget;
  DoCalc(DeltaTime, NewPoint, NewVelocity, Done);
  if FTarget.TargetType <> TTargetType.Achieved then
    LMinVelocity := Min(MinVelocity, (MinVelocity * DeltaTime / ALEpsilonPoint))
  else
    LMinVelocity := MinVelocity;
  if IsSmall(NewVelocity, LMinVelocity) then
  begin
    FCurrentVelocity := TALPointD.Create(0, 0);
    if (FTarget.TargetType <> TTargetType.Achieved) and
       (Abs(NewPoint.X - FTarget.Point.X) < ALEpsilonPoint) then
      NewPoint.X := FTarget.Point.X;

    if (FTarget.TargetType <> TTargetType.Achieved) and
       (Abs(NewPoint.Y - FTarget.Point.Y) < ALEpsilonPoint) then
      NewPoint.Y := FTarget.Point.Y;
    FLowChanged := True;
    ViewportPosition := NewPoint;
  end
  else
  begin
    FCurrentVelocity := NewVelocity;
    ViewportPosition := NewPoint;
  end;
end;

{*******************************************}
procedure TALAniCalculations.InternalChanged;
var
  T: TDateTime;
begin
  T := FPlatformTimer.getTick/SecsPerDay;
  if (FLastTimeChanged = 0) or (Abs(T - FLastTimeChanged) * SecsPerDay >= ALEpsilonTime) then
  begin
    try
      DoChanged;
    finally
      FLastTimeChanged := T;
    end;
  end
  else if not InTimerProc then
  begin
    FUpdateTimerCount := -1;
    UpdateTimer;
  end;
end;

{****************************************************************}
procedure TALAniCalculations.SetAutoShowing(const Value: Boolean);
begin
  if FAutoShowing <> Value then
  begin
    FAutoShowing := Value;
    if UpdateCount > 0 then
    begin
      if AutoShowing then
        FOpacity := 0
      else
        FOpacity := ALMaxOpacity;
      InternalChanged;
    end;
    UpdateTimer;
  end;
end;

{**************************************************}
function TALAniCalculations.GetLowVelocity: Boolean;
begin
  Result := IsSmall(FCurrentVelocity, MinVelocity);
end;

{***************************************************************}
procedure TALAniCalculations.CalcVelocity(const Time: TDateTime);
var
  D, VAbs: Double;
  I: Integer;
begin
  if Time > 0 then
    FLastTimeCalc := Time
  else
    FLastTimeCalc := FPlatformTimer.getTick/SecsPerDay;
  Clear(FLastTimeCalc);
  if Averaging then
    I := 0
  else if PositionCount > 2 then
    I := PositionCount - 3
  else
    I := PositionCount - 2;
  if (I >= 0) and ((PositionCount - 1) > I) and (InternalTouchTracking <> [])
  then
  begin
    FCurrentVelocity := TALPointD.Create(0, 0);
    D := PositionTimes[PositionCount - 1] - PositionTimes[I];
    D := D * (SecsPerDay);
    if D > 0 then
    begin
      D := Max(D, ALEpsilonTime);
      if ttHorizontal in InternalTouchTracking then
      begin
        FCurrentVelocity.X := Positions[PositionCount - 1].X - Positions[I].X;
        FCurrentVelocity.X := -FCurrentVelocity.X / D;
      end;
      if ttVertical in InternalTouchTracking then
      begin
        FCurrentVelocity.Y := Positions[PositionCount - 1].Y - Positions[I].Y;
        FCurrentVelocity.Y := -FCurrentVelocity.Y / D;
      end;
      VAbs := FCurrentVelocity.Abs;
      D := Max(1, MaxVelocity);
      if (VAbs < MinVelocity) and (not Down) then
        FCurrentVelocity := TALPointD.Create(0, 0)
      else if VAbs > D then
      begin
        VAbs := D / VAbs;
        FCurrentVelocity.X := FCurrentVelocity.X * VAbs;
        FCurrentVelocity.Y := FCurrentVelocity.Y * VAbs;
      end;
    end;
    fCurrentVelocity.X := fCurrentVelocity.X * fVelocityFactor;
    fCurrentVelocity.Y := fCurrentVelocity.y * fVelocityFactor;
    if assigned(fOnCalcVelocity) then fOnCalcVelocity(self);
  end;
  UpdateTimer;
end;

{***********************************************}
procedure TALAniCalculations.Clear(T: TDateTime);
begin
  if FPointTime.Count > 0 then
  begin
    if T <= 0 then
      T := FPointTime[FPointTime.Count - 1].Time;
    while (FPointTime.Count > 0) and
      ((T - FPointTime[0].Time) * (SecsPerDay) > FStorageTime) do
      FPointTime.Delete(0);
  end;
end;

{****************************************************}
function TALAniCalculations.GetPositionCount: Integer;
begin
  if FPointTime <> nil then
    Result := FPointTime.Count
  else
    Result := 0;
end;

{***************************************************************************}
function TALAniCalculations.PosToView(const APosition: TALPointD): TALPointD;
var
  X, Y, D: Double;
  P: TALPointD;
  function NewDelta(X: Double): Double;
  const
    q = (5 / 6) * (5 / 6) * (5 / 6) * (5 / 6) * (5 / 6) * (5 / 6);
  begin
    if X > D + q then
      Result := D - q + (Power(X - D, 5 / 6))
    else
      Result := X;
  end;

begin
  P := TALPointD.Create(FDownPosition.X + FDownPoint.X, FDownPosition.Y + FDownPoint.Y);
  D := Min(24, Max(1, FDeadZone));
  X := P.X - APosition.X;
  Y := P.Y - APosition.Y;
  if (FMinTarget.TargetType = TTargetType.Min) and (X < FMinTarget.Point.X) then
    X := FMinTarget.Point.X - NewDelta(FMinTarget.Point.X - X);
  if (FMaxTarget.TargetType = TTargetType.Max) and (X > FMaxTarget.Point.X) then
    X := FMaxTarget.Point.X + NewDelta(X - FMaxTarget.Point.X);
  if (FMinTarget.TargetType = TTargetType.Min) and (Y < FMinTarget.Point.Y) then
    Y := FMinTarget.Point.Y - NewDelta(FMinTarget.Point.Y - Y);
  if (FMaxTarget.TargetType = TTargetType.Max) and (Y > FMaxTarget.Point.Y) then
    Y := FMaxTarget.Point.Y + NewDelta(Y - FMaxTarget.Point.Y);
  Result := TALPointD.Create(P.X - X, P.Y - Y);
end;

{************************************************************************}
function TALAniCalculations.GetPositions(const Index: Integer): TALPointD;
begin
  if (index < 0) or (index >= PositionCount) then
    raise EListError.CreateFMT(sArgumentOutOfRange_Index,
      [index, PositionCount]);
  Result := FPointTime[index].Point;
end;

{****************************************************************************}
function TALAniCalculations.GetPositionTimes(const Index: Integer): TDateTime;
begin
  if (index < 0) or (index >= PositionCount) then
    raise EListError.CreateFMT(sArgumentOutOfRange_Index,
      [index, PositionCount]);
  Result := FPointTime[index].Time;
end;

{**********************************************************************************************}
function TALAniCalculations.AddPointTime(const X, Y: Double; const Time: TDateTime): TPointTime;
begin
  if Time > 0 then
    Result.Time := Time
  else
    Result.Time := FPlatformTimer.getTick/SecsPerDay;
  Result.Point.X := X;
  Result.Point.Y := Y;
  Result.Point := PosToView(Result.Point);
  if FPointTime.Count > 0 then
  begin
    if (not(ttHorizontal in TouchTracking)) then
      Result.Point.X := FPointTime[FPointTime.Count - 1].Point.X;
    if (not(ttVertical in TouchTracking)) then
      Result.Point.Y := FPointTime[FPointTime.Count - 1].Point.Y;
  end;
  if (FPointTime.Count = 0) or
    (Result.Point <> FPointTime[FPointTime.Count - 1].Point) then
    FPointTime.Add(Result)
  else
  begin
    Result.Point := FPointTime[FPointTime.Count - 1].Point;
    FPointTime[FPointTime.Count - 1] := Result;
  end;
end;

{***************************************************}
procedure TALAniCalculations.MouseDown(X, Y: Double);
begin
  if Down then
    Exit;
  Down := True;
  FindTarget(FLastTarget);
  FCancelTargetX := False;
  FCancelTargetY := False;
  FMoved := False;
  FDownPoint := TALPointD.Create(X, Y);
  FDownPosition := ViewportPosition;
  AddPointTime(X, Y, FUpDownTime);
  UpdateTimer;
end;

{***************************************************}
procedure TALAniCalculations.MouseMove(X, Y: Double);
var
  NewVal: TPointTime;
  NewViewportPosition: TALPointD;
  D, DZ: Double;
  P: TALPointD;
begin
  {$IFDEF DEBUG}
  //ALLog('TALAniCalculations.MouseMove', 'x: '  + ALFormatFloatU('0', x, alDefaultFormatSettingsU) +
  //                                      ' - y: '  + ALFormatFloatU('0', y, alDefaultFormatSettingsU), TalLogType.verbose);
  {$ENDIF}
  if Down and ([ttVertical, ttHorizontal] * TouchTracking <> []) then
  begin
    if not FMoved then
    begin
      P := TALPointD.Create(X, Y);
      if TouchTracking = [ttVertical, ttHorizontal] then
        D := P.Distance(FDownPoint)
      else if (TouchTracking = [ttVertical]) then
        D := Abs(P.Y - FDownPoint.Y)
      else if (TouchTracking = [ttHorizontal]) then
        D := Abs(P.X - FDownPoint.X)
      else
        D := 0;
      if Averaging and Animation then
      begin
        DZ := Max(FDeadZone, 1);
        if D > DZ then
        begin
          FMoved := True;
          FDownPoint := TALPointD.Create(X, Y);
          FDownPosition := ViewportPosition;
        end;
      end
      else
        FMoved := D > 0;
      if FMoved then
      begin
        FMoved := True;
        InternalStart;
      end;
    end;
    if FMoved then
    begin
      NewVal := AddPointTime(X, Y);
      if (ttHorizontal in TouchTracking) then
        NewViewportPosition.X := FDownPosition.X - (NewVal.Point.X - FDownPoint.X)
      else
        NewViewportPosition.X := ViewportPosition.X;
      if (ttVertical in TouchTracking) then
        NewViewportPosition.Y := FDownPosition.Y - (NewVal.Point.Y - FDownPoint.Y)
      else
        NewViewportPosition.Y := ViewportPosition.Y;
      Clear;
      ViewportPosition := NewViewportPosition;
      UpdateTarget;
    end;
  end;
end;

{*************************************************}
procedure TALAniCalculations.MouseUp(X, Y: Double);
begin
  if Down then
  begin
    MouseMove(X, Y);
    CalcVelocity;
    FUpVelocity := CurrentVelocity;
    FUpPosition := ViewportPosition;
    UpdateTimer;
    if (not Animation) then
      UpdateViewportPositionByBounds;
    Down := False;
  end;
end;

{**************************************}
procedure TALAniCalculations.MouseLeave;
var
  PointTime: TPointTime;
begin
  if Down then
  begin
    if PositionCount > 0 then
    begin
      PointTime := FPointTime[PositionCount - 1];
      PointTime.Time := FPlatformTimer.getTick/SecsPerDay;
      FPointTime[PositionCount - 1] := PointTime;
    end;
    CalcVelocity;
    FUpVelocity := CurrentVelocity;
    FUpPosition := ViewportPosition;
    UpdateTimer;
    if (not Enabled) and (not Animation) then
      UpdateViewportPositionByBounds;
    Down := False;
  end;
end;

{****************************************************}
procedure TALAniCalculations.MouseWheel(X, Y: Double);
var
  DX, DY: Double;
  NewTarget: TTarget;
begin
  DX := RoundTo(X, ALEpsilonRange);
  DY := RoundTo(Y, ALEpsilonRange);
  if (DX <> 0) or (DY <> 0) then
  begin
    NewTarget.TargetType := TTargetType.Other;
    if FMouseTarget.TargetType <> TTargetType.Other then
      NewTarget.Point := ViewportPosition
    else
      NewTarget.Point := FMouseTarget.Point;
    NewTarget.Point.Offset(DX, DY);
    FUpdateTimerCount := -1;
    SetMouseTarget(NewTarget);
  end;
end;

{**********************************************************}
procedure TALAniCalculations.SetMouseTarget(Value: TTarget);
var
  NewTargets: array of TTarget;
  I: Integer;
  LTarget: TTarget;
begin
  if Value.TargetType in [TTargetType.Min, TTargetType.Max] then
    Exit;
  LTarget := Value;
  SetLength(NewTargets, 0);
  for I := low(FTargets) to high(FTargets) do
    if FTargets[I].TargetType in [TTargetType.Min, TTargetType.Max] then
    begin
      SetLength(NewTargets, Length(NewTargets) + 1);
      NewTargets[Length(NewTargets) - 1] := FTargets[I];
      if (FTargets[I].TargetType = TTargetType.Min) then
      begin
        LTarget.Point.X := Max(LTarget.Point.X, FTargets[I].Point.X);
        LTarget.Point.Y := Max(LTarget.Point.Y, FTargets[I].Point.Y);
      end;
      if (FTargets[I].TargetType = TTargetType.Max) then
      begin
        LTarget.Point.X := Min(LTarget.Point.X, FTargets[I].Point.X);
        LTarget.Point.Y := Min(LTarget.Point.Y, FTargets[I].Point.Y);
      end;
    end;
  if LTarget.TargetType = TTargetType.Achieved then
  begin
    for I := low(FTargets) to high(FTargets) do
      if (not(FTargets[I].TargetType in [TTargetType.Min, TTargetType.Max])) and
        (FTargets[I].Point <> FMouseTarget.Point) then
      begin
        SetLength(NewTargets, Length(NewTargets) + 1);
        NewTargets[Length(NewTargets) - 1] := FTargets[I];
      end;
    FMouseTarget := LTarget;
  end
  else
  begin
    FMouseTarget := LTarget;
    if (FMouseTarget.TargetType <> TTargetType.Achieved) then
    begin
      SetLength(NewTargets, Length(NewTargets) + 1);
      NewTargets[Length(NewTargets) - 1] := FMouseTarget;
    end;
  end;
  SetTargets(NewTargets);
end;

{***********************************************************************}
constructor TALScrollingAcquiredMessage.Create(const AAcquired: boolean);
begin
  fAcquired := AAcquired;
end;

initialization
  ALEpsilonRange := Trunc(Log10(ALEpsilonPoint));

end.
