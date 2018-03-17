program changeHMS;

{$APPTYPE CONSOLE}

uses
  WebBroker,
  CGIApp,
  MainF in 'MainF.pas' {MainWebModule: TWebModule};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'changeHMS';
  Application.CreateForm(TMainWebModule, MainWebModule);
  Application.Run;
end.
