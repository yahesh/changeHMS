unit MainF;

interface

uses
  Windows,
  SysUtils,
  Messages,
  HTTPApp,
  Classes;


type
  TValueAction = (vaUnknown, vaForward, vaPassword);

  TValueRecord = record
    Action         : TValueAction;
    Domain         : String;
    Username       : String;
    Password       : String;
    ForwardAddress : String;
    NewPassword    : String;
  end;

  TMainWebModule = class(TWebModule)
    procedure MainWebModuledefaultAction(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
  private
    { Private-Deklarationen }
    function GetApplicationOutput(AApplication : String; AParameters : TStringList) : String;
    function GetCGIPath(APathTranslated : String; APathInfo : String; AScriptName : String) : String;
    function GetResultString(AAction : TValueAction; AResult : String) : String;
    function GetWindowsPath : String;
    function ParseRequest(ARequest : TWebRequest) : TValueRecord;
  public
    { Public-Deklarationen }
  end;

var
  MainWebModule : TMainWebModule;

implementation

{$R *.xfm}

const
  CCGIFolder       = '/cgi-bin';
  CCscriptExe      = 'system32\cscript.exe';
  CForwardAction   = 'forward';
  CForwardParam    = 'forward';
  CForwardVBS      = 'changeForward.vbs';
  CNewParam        = 'new';
  CNoLogoParam     = '/nologo';
  CPasswordAction  = 'password';
  CPasswordParam   = 'password';
  CPasswordVBS     = 'changePassword.vbs';
  CPathDivider     = '\';
  CQuote           = '"';
  CQuoteEscaped    = '\"';
  CURLDivider      = '/';

// source: http://delphi.about.com/cs/adptips2001/a/bltip0201_2.htm
function TMainWebModule.GetApplicationOutput(AApplication: String; AParameters: TStringList): String;
  function GetParameterLine(AApplication : String; AParameters : TStringList) : String;
  var
    LIndex : Integer;
  begin
    Result := CQuote + StringReplace(AApplication, CQuote, CQuoteEscaped, [rfReplaceAll, rfIgnoreCase]) + CQuote;

    if (AParameters <> nil) then
    begin
      for LIndex := 0 to Pred(AParameters.Count) do
        Result := Result + #32 + CQuote + StringReplace(AParameters[LIndex], CQuote, CQuoteEscaped, [rfReplaceAll, rfIgnoreCase]) + CQuote;
    end;
  end;

  procedure ProcessMessages;
  var
    LMessage : TMsg;
  begin
    while PeekMessage(LMessage, 0, 0, 0, PM_REMOVE) do
    begin
      if (LMessage.Message <> WM_QUIT) then
      begin
        TranslateMessage(LMessage);
        DispatchMessage(LMessage);
      end
      else
        Break;
    end;
  end;
const
  CReadBuffer = 1024;
var
  LAppRunning  : DWord;
  LBuffer      : PChar;
  LBytesRead   : DWord;
  LProcessInfo : TProcessInformation;
  LReadPipe    : THandle;
  LSecurity    : TSecurityAttributes;
  LStart       : TStartUpInfo;
  LWritePipe   : THandle;
begin
  Result := '';

  LSecurity.nLength             := SizeOf(TSecurityAttributes);
  LSecurity.bInheritHandle      := true;
  LSecurity.lpSecurityDescriptor := nil;

  if CreatePipe(LReadPipe, LWritePipe, @LSecurity, 0) then
  begin
    try
      LBuffer := AllocMem(Succ(CReadBuffer));
      try
        FillChar(LStart, SizeOf(LStart), #0) ;
        LStart.cb          := SizeOf(LStart) ;
        LStart.dwFlags     := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
        LStart.hStdInput   := LReadPipe;
        LStart.hStdOutput  := LWritePipe;
        LStart.wShowWindow := SW_HIDE;

        if CreateProcess(nil, PChar(GetParameterLine(AApplication, AParameters)),
                         @LSecurity, @LSecurity, true, NORMAL_PRIORITY_CLASS, nil,
                         nil, LStart, LProcessInfo) then
        begin
          try
            repeat
              LAppRunning := WaitForSingleObject(LProcessInfo.hProcess, 100);
              
              ProcessMessages;
            until (LAppRunning <> WAIT_TIMEOUT);

            repeat
              LBytesRead := 0;
              ReadFile(LReadPipe, LBuffer[0], CReadBuffer, LBytesRead, nil) ;
              LBuffer[LBytesRead] := #0;
              OemToChar(LBuffer, LBuffer);

              Result := Result + String(LBuffer);
            until (LBytesRead < CReadBuffer);
          finally
            CloseHandle(LProcessInfo.hProcess);
            CloseHandle(LProcessInfo.hThread);
          end;
        end;
      finally
        FreeMem(LBuffer);
      end;
    finally
      CloseHandle(LReadPipe);
      CloseHandle(LWritePipe);
    end;
  end;
end;

function TMainWebModule.GetCGIPath(APathTranslated, APathInfo, AScriptName: String): String;
var
  LPosition : Integer;
begin
  Result := '';

  repeat
    LPosition := Pos(CURLDivider, APathInfo);
    if (LPosition > 0) then
      APathInfo[LPosition] := CPathDivider;
  until (LPosition <= 0);

  repeat
    LPosition := Pos(CURLDivider, AScriptName);
    if (LPosition > 0) then
      AScriptName[LPosition] := CPathDivider;
  until (LPosition <= 0);

  if (Pred(Pos(APathInfo, AScriptName) + Length(APathInfo)) = Length(AScriptName)) then
  begin
    Delete(AScriptName, Succ(Length(AScriptName) - Length(APathInfo)), Length(APathInfo));

    if (Pred(Pos(APathInfo, APathTranslated) + Length(APathInfo)) = Length(APathTranslated)) then
    begin
      Delete(APathTranslated, Succ(Length(APathTranslated) - Length(APathInfo)), Length(APathInfo));

      Result := APathTranslated + AScriptName + CPathDivider;
    end;
  end;
end;

function TMainWebModule.GetResultString(AAction: TValueAction; AResult: String) : String;
const
  CEverythingFine   = 'everything went fine';
  CForward          = '(forward)';
  CInternalError    = 'an internal error occured';
  CMissingArguments = 'missing arguments';
  CNoSuchDomain     = 'there is no such domain';
  CPassword         = '(password)';
  CUnknownError     = 'an unknown error occured';
  CWrongCredentials = 'wrong credentials have been provided';
var
  LError  : LongInt;
  LResult : Byte;
begin
  Result := '';

  AResult := Trim(AResult);
  Val(AResult, LResult, LError);
  if (LError = 0) then
  begin
    case AAction of
      vaForward :
      begin
        case LResult of
          0 : Result := AResult + #32 + CEverythingFine + #32 + CForward;
          1 : Result := AResult + #32 + CWrongCredentials + #32 + CForward;
          2 : Result := AResult + #32 + CWrongCredentials + #32 + CForward;
          3 : Result := AResult + #32 + CNoSuchDomain + #32 + CForward;
          4 : Result := AResult + #32 + CWrongCredentials + #32 + CForward;
          5 : Result := AResult + #32 + CInternalError + #32 + CForward;
          6 : Result := AResult + #32 + CMissingArguments + #32 + CForward;
        else
          Result := AResult + #32 + CUnknownError + #32 + CForward;
        end;
      end;

      vaPassword :
      begin
        case LResult of
          0 : Result := AResult + #32 + CEverythingFine + #32 + CPassword;
          1 : Result := AResult + #32 + CWrongCredentials + #32 + CPassword;
          2 : Result := AResult + #32 + CWrongCredentials + #32 + CPassword;
          3 : Result := AResult + #32 + CNoSuchDomain + #32 + CPassword;
          4 : Result := AResult + #32 + CWrongCredentials + #32 + CPassword;
          5 : Result := AResult + #32 + CInternalError + #32 + CPassword;
          6 : Result := AResult + #32 + CMissingArguments + #32 + CPassword;
        else
          Result := AResult + #32 + CUnknownError + #32 + CPassword;
        end;
      end;
    else
      Result := AResult + #32 + CUnknownError;
    end;
  end
  else
    Result := AResult + #32 + CUnknownError;
end;

function TMainWebModule.GetWindowsPath: String;
var
  LSize : Integer;
begin
  Result := '';

  LSize := GetWindowsDirectory(nil, 0);
  if (LSize > 0) then
  begin
    SetLength(Result, Succ(LSize));
    GetWindowsDirectory(@Result[1], Length(Result));

    Result := Trim(Result);
    if (Length(Result) > 0) then
    begin
      if (Result[Length(Result)] <> CPathDivider) then
        Result := Result + CPathDivider;
    end;
  end;
end;

procedure TMainWebModule.MainWebModuledefaultAction(Sender: TObject; Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  LCGIDirectory : String;
  LParameters   : TStringList;
  LTextResult   : String;
  LValueRecord  : TValueRecord;
begin
  LCGIDirectory := GetCGIPath(Request.PathTranslated, Request.PathInfo, Request.ScriptName);
  if DirectoryExists(LCGIDirectory) then
  begin
    LValueRecord := ParseRequest(Request);

    case LValueRecord.Action of
      vaForward :
      begin
        if FileExists(LCGIDirectory + CForwardVBS) then
        begin
          LParameters := TStringList.Create;
          try
            LParameters.Add(CNoLogoParam);
            LParameters.Add(LCGIDirectory + CForwardVBS);
            if (Length(Trim(LValueRecord.Domain)) > 0) then
              LParameters.Add(LValueRecord.Domain);
            if (Length(Trim(LValueRecord.Username)) > 0) then
              LParameters.Add(LValueRecord.Username);
            if (Length(Trim(LValueRecord.Password)) > 0) then
              LParameters.Add(LValueRecord.Password);
            if (Length(Trim(LValueRecord.ForwardAddress)) > 0) then
              LParameters.Add(LValueRecord.ForwardAddress);

            LTextResult := Trim(GetApplicationOutput(GetWindowsPath + CCscriptExe, LParameters));
            Response.Content := GetResultString(LValueRecord.Action, LTextResult);
          finally
            LParameters.Free;
          end;
        end;
      end;

      vaPassword :
      begin
        if FileExists(LCGIDirectory + CPasswordVBS) then
        begin
          LParameters := TStringList.Create;
          try
            LParameters.Add(CNoLogoParam);
            LParameters.Add(LCGIDirectory + CPasswordVBS);
            if (Length(Trim(LValueRecord.Domain)) > 0) then
              LParameters.Add(LValueRecord.Domain);
            if (Length(Trim(LValueRecord.Username)) > 0) then
              LParameters.Add(LValueRecord.Username);
            if (Length(Trim(LValueRecord.Password)) > 0) then
              LParameters.Add(LValueRecord.Password);
            if (Length(Trim(LValueRecord.NewPassword)) > 0) then
              LParameters.Add(LValueRecord.NewPassword);

            LTextResult := Trim(GetApplicationOutput(GetWindowsPath + CCscriptExe, LParameters));
            Response.Content := GetResultString(LValueRecord.Action, LTextResult);
          finally
            LParameters.Free;
          end;
        end;
      end;
    else
      Response.Content := '';
    end;
  end;

  Handled := true;
end;

function TMainWebModule.ParseRequest(ARequest: TWebRequest) : TValueRecord;
var
  LAction     : String;
  LIndex      : Integer;
  LScriptName : String;
  LUsername   : String;
begin
  Result.Action         := vaUnknown;
  Result.Domain         := '';
  Result.Username       := '';
  Result.Password       := '';
  Result.ForwardAddress := '';
  Result.NewPassword    := '';

  if (ARequest <> nil) then
  begin
    LScriptName := AnsiLowerCase(Trim(ARequest.ScriptName));
    if (Length(LScriptName) > 0) then
    begin
      // kill trailing slash
      if (LScriptName[Length(LScriptName)] = CURLDivider) then
        Delete(LScriptName, Length(LScriptName), 1);

      // read trailing value - is username
      // kill trailing value
      for LIndex := Length(LScriptName) downto 1 do
      begin
        if (LScriptName[LIndex] = CURLDivider) then
        begin
          LUserName := Copy(LScriptName, Succ(LIndex), Length(LScriptName) - LIndex);
          Delete(LScriptName, LIndex, Length(LScriptName) - Pred(LIndex));

          Break;
        end;
      end;

      // read trailing value - is action
      // kill trailing value
      for LIndex := Length(LScriptName) downto 1 do
      begin
        if (LScriptName[LIndex] = CURLDivider) then
        begin
          LAction := Copy(LScriptName, Succ(LIndex), Length(LScriptName) - LIndex);
          Delete(LScriptName, LIndex, Length(LScriptName) - Pred(LIndex));

          Break;
        end;
      end;

      // check action string
      if AnsiSameText(LAction, CForwardAction) then
        Result.Action := vaForward;
      if AnsiSameText(LAction, CPasswordAction) then
        Result.Action := vaPassword;

      case Result.Action of
        vaForward :
        begin
          // read "forward" parameter
          LIndex := Request.QueryFields.IndexOfName(CForwardParam);
          if (LIndex >= 0) then
            Result.ForwardAddress := Request.QueryFields.ValueFromIndex[LIndex];

          // read "password" parameter
          LIndex := Request.QueryFields.IndexOfName(CPasswordParam);
          if (LIndex >= 0) then
            Result.Password := Request.QueryFields.ValueFromIndex[LIndex];

          Result.Domain   := Request.Host;
          Result.Username := LUserName;
        end;

        vaPassword :
        begin
          // read "new" parameter
          LIndex := Request.QueryFields.IndexOfName(CNewParam);
          if (LIndex >= 0) then
            Result.NewPassword := Request.QueryFields.ValueFromIndex[LIndex];

          // read "password" parameter
          LIndex := Request.QueryFields.IndexOfName(CPasswordParam);
          if (LIndex >= 0) then
            Result.Password := Request.QueryFields.ValueFromIndex[LIndex];

          Result.Domain   := Request.Host;
          Result.Username := LUserName;
        end;
      end;
    end;
  end;
end;

end.
