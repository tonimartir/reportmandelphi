unit umainform;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, rpfrmmonacoeditorlcl;

type
  TMainForm = class(TForm)
    PanelToolbar: TPanel;
    BtnLoadSample: TButton;
    BtnGetSQL: TButton;
    BtnToggleTheme: TButton;
    BtnToggleFallback: TButton;
    BtnClear: TButton;
    BtnClearLog: TButton;
    PanelCenter: TPanel;
    SplitterLog: TSplitter;
    PanelLog: TPanel;
    LabelLogTitle: TLabel;
    MemoLog: TMemo;
    StatusBar: TStatusBar;

    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure BtnLoadSampleClick(Sender: TObject);
    procedure BtnGetSQLClick(Sender: TObject);
    procedure BtnToggleThemeClick(Sender: TObject);
    procedure BtnToggleFallbackClick(Sender: TObject);
    procedure BtnClearClick(Sender: TObject);
    procedure BtnClearLogClick(Sender: TObject);
  private
    FMonacoEditor: TFRpMonacoEditorLCL;
    FIsDarkTheme: Boolean;
    FSelfTestMode: Boolean;
    FSelfTestTimer: TTimer;
    procedure SelfTestTimeout(Sender: TObject);
    procedure EditorContentChanged(Sender: TObject);
    procedure EditorWebMessage(Sender: TObject; const AMessage: string);
    procedure EditorStatusLog(Sender: TObject; const AStatus: string);
    procedure LogMessage(const AText: string);
    procedure UpdateStatusBar;
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

const
  SampleSQL = 
    '-- =======================================================' + LineEnding +
    '-- Report Manager Monaco SQL Editor Test' + LineEnding +
    '-- Running inside Free Pascal / LCL with Microsoft WebView2' + LineEnding +
    '-- =======================================================' + LineEnding +
    'SELECT ' + LineEnding +
    '    c.CustomerID,' + LineEnding +
    '    c.CompanyName,' + LineEnding +
    '    c.ContactName,' + LineEnding +
    '    o.OrderID,' + LineEnding +
    '    o.OrderDate,' + LineEnding +
    '    SUM(od.Quantity * od.UnitPrice * (1.0 - od.Discount)) AS TotalAmount,' + LineEnding +
    '    COUNT(od.ProductID) AS TotalItems' + LineEnding +
    'FROM Customers c' + LineEnding +
    'INNER JOIN Orders o ON o.CustomerID = c.CustomerID' + LineEnding +
    'INNER JOIN OrderDetails od ON od.OrderID = o.OrderID' + LineEnding +
    'WHERE o.OrderDate >= ''2026-01-01''' + LineEnding +
    '  AND c.Country IN (''Spain'', ''France'', ''Germany'', ''USA'')' + LineEnding +
    'GROUP BY ' + LineEnding +
    '    c.CustomerID, ' + LineEnding +
    '    c.CompanyName, ' + LineEnding +
    '    c.ContactName, ' + LineEnding +
    '    o.OrderID, ' + LineEnding +
    '    o.OrderDate' + LineEnding +
    'HAVING SUM(od.Quantity * od.UnitPrice) > 1000.00' + LineEnding +
    'ORDER BY TotalAmount DESC;';

function IsSelfTestRequested: Boolean;
var
  I: Integer;
  P: string;
begin
  Result := False;
  for I := 1 to ParamCount do
  begin
    P := LowerCase(ParamStr(I));
    if (P = '--selftest') or (P = '-selftest') or (P = '/selftest') or (P = '-s') then
      Exit(True);
  end;
end;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  LogMessage('TMainForm.FormCreate: inicio');
  FIsDarkTheme := False;
  FSelfTestMode := IsSelfTestRequested;
  LogMessage('TMainForm.FormCreate: FSelfTestMode = ' + BoolToStr(FSelfTestMode, True));

  FMonacoEditor := TFRpMonacoEditorLCL.Create(Self);
  LogMessage('TMainForm.FormCreate: FMonacoEditor creado');
  FMonacoEditor.Parent := PanelCenter;
  LogMessage('TMainForm.FormCreate: FMonacoEditor asignado a PanelCenter');
  FMonacoEditor.Align := alClient;
  FMonacoEditor.OnContentChanged := EditorContentChanged;
  FMonacoEditor.OnWebMessage := EditorWebMessage;
  FMonacoEditor.OnStatusLog := EditorStatusLog;

  LogMessage('Formulario de test iniciado. Modo self-test: ' + BoolToStr(FSelfTestMode, True));
  // Set initial sample SQL
  FMonacoEditor.SQL := SampleSQL;
  UpdateStatusBar;

  if FSelfTestMode then
  begin
    LogMessage('[SelfTest] Modo self-test activo. Iniciando timeout de 15s...');
    FSelfTestTimer := TTimer.Create(Self);
    FSelfTestTimer.Interval := 15000;
    FSelfTestTimer.OnTimer := SelfTestTimeout;
    FSelfTestTimer.Enabled := True;
  end;
  LogMessage('TMainForm.FormCreate: fin');
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  LogMessage('FormShow: asegurando creación de WebView2...');
  FMonacoEditor.TryCreateWebView;
end;

procedure TMainForm.SelfTestTimeout(Sender: TObject);
begin
  FSelfTestTimer.Enabled := False;
  LogMessage('[SelfTest ERROR] Timeout alcanzado antes de completar la prueba.');
  Application.Terminate;
end;

procedure TMainForm.LogMessage(const AText: string);
var
  LFormatted: string;
  F: TextFile;
  LFileName: string;
begin
  LFormatted := FormatDateTime('hh:nn:ss.zzz', Now) + ' - ' + AText;
  if MemoLog <> nil then
  begin
    MemoLog.Lines.Add(LFormatted);
    MemoLog.SelStart := Length(MemoLog.Lines.Text);
  end;

  try
    LFileName := ExtractFilePath(ParamStr(0)) + 'selftest_result.log';
    AssignFile(F, LFileName);
    if FileExists(LFileName) then
      Append(F)
    else
      Rewrite(F);
    WriteLn(F, LFormatted);
    CloseFile(F);
  except
  end;
end;

procedure TMainForm.UpdateStatusBar;
var
  LState: string;
begin
  if StatusBar = nil then
    Exit;

  if FMonacoEditor.UseFallback then
    LState := 'Estado: Fallback TMemo (Activo)'
  else if FMonacoEditor.EditorReady then
    LState := 'Estado: Monaco Editor (Listo)'
  else
    LState := 'Estado: Monaco Inicializando...';

  StatusBar.Panels[0].Text := LState;
  StatusBar.Panels[1].Text := 'SQL: ' + IntToStr(Length(FMonacoEditor.SQL)) + ' caracteres';
  if FMonacoEditor.AssetRootPath <> '' then
    StatusBar.Panels[2].Text := 'Assets: ' + FMonacoEditor.AssetRootPath
  else
    StatusBar.Panels[2].Text := 'Assets: pendiente de resolver';
end;

procedure TMainForm.EditorContentChanged(Sender: TObject);
begin
  UpdateStatusBar;
end;

procedure TMainForm.EditorWebMessage(Sender: TObject; const AMessage: string);
var
  LPrefix: string;
begin
  LPrefix := Copy(AMessage, 1, 3);
  if LPrefix = '00:' then
    LogMessage('[IPC Recv] 00: - Monaco Editor listo y montado en WebView2')
  else if LPrefix = '01:' then
    LogMessage('[IPC Recv] 01: - Texto modificado en Monaco (' + IntToStr(Length(AMessage) - 3) + ' caracteres)')
  else if LPrefix = '02:' then
    LogMessage('[IPC Recv] 02: - Solicitud de autocompletado AI recibida')
  else
    LogMessage('[IPC Recv] Mensaje: ' + Copy(AMessage, 1, 80));
  UpdateStatusBar;

  if FSelfTestMode then
  begin
    if LPrefix = '00:' then
    begin
      LogMessage('[SelfTest] Señal 00: recibida. Enviando consulta SQL de prueba...');
      FMonacoEditor.SQL := 'SELECT 99999 AS TestCol;';
    end
    else if LPrefix = '01:' then
    begin
      LogMessage('[SelfTest] Señal 01: recibida. Comprobando contenido...');
      if Pos('99999', AMessage) > 0 then
      begin
        LogMessage('[SelfTest] PRUEBA EXITOSA: Comunicacion bidireccional Pascal <-> Monaco confirmada.');
        MemoLog.Lines.SaveToFile(ExtractFilePath(ParamStr(0)) + 'selftest_result.log');
        if FSelfTestTimer <> nil then
          FSelfTestTimer.Enabled := False;
        Application.Terminate;
      end;
    end;
  end;
end;

procedure TMainForm.EditorStatusLog(Sender: TObject; const AStatus: string);
begin
  LogMessage('[Status] ' + AStatus);
  UpdateStatusBar;
end;

procedure TMainForm.BtnLoadSampleClick(Sender: TObject);
begin
  LogMessage('Cargando SQL de ejemplo en Monaco...');
  FMonacoEditor.SQL := SampleSQL;
  UpdateStatusBar;
end;

procedure TMainForm.BtnGetSQLClick(Sender: TObject);
var
  LSQL: string;
begin
  LSQL := FMonacoEditor.SQL;
  LogMessage('Obtenido SQL desde Pascal (' + IntToStr(Length(LSQL)) + ' chars):');
  LogMessage('------------------------------------------------------------');
  LogMessage(Copy(LSQL, 1, 300) + '...');
  LogMessage('------------------------------------------------------------');
  ShowMessage('SQL actual obtenido exitosamente (' + IntToStr(Length(LSQL)) + ' caracteres).' + LineEnding +
              'Primeras lineas:' + LineEnding + Copy(LSQL, 1, 200) + '...');
end;

procedure TMainForm.BtnToggleThemeClick(Sender: TObject);
begin
  FIsDarkTheme := not FIsDarkTheme;
  if FIsDarkTheme then
  begin
    LogMessage('Cambiando tema a oscuro (vs-dark)...');
    FMonacoEditor.SetTheme('vs-dark');
  end
  else
  begin
    LogMessage('Cambiando tema a claro (vs)...');
    FMonacoEditor.SetTheme('vs');
  end;
end;

procedure TMainForm.BtnToggleFallbackClick(Sender: TObject);
begin
  if not FMonacoEditor.UseFallback then
  begin
    LogMessage('Activando manualmente modo fallback (TMemo)...');
    FMonacoEditor.ActivateFallback('Activado por el usuario en test');
  end
  else
  begin
    LogMessage('El modo fallback esta activo para esta sesion.');
  end;
  UpdateStatusBar;
end;

procedure TMainForm.BtnClearClick(Sender: TObject);
begin
  LogMessage('Limpiando editor SQL...');
  FMonacoEditor.SQL := '';
  UpdateStatusBar;
end;

procedure TMainForm.BtnClearLogClick(Sender: TObject);
begin
  MemoLog.Clear;
  LogMessage('Log limpiado.');
end;

end.
