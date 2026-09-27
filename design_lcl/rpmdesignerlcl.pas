{*******************************************************}
{                                                       }
{       Report Manager                                  }
{                                                       }
{       rpmdesignerlcl                                  }
{       TRpDesignerLCL: A component to call report      }
{       designer in LCL                                 }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdesignerlcl;

{$mode delphi}

interface

uses
  Classes, SysUtils, rpmdconsts, rpreport;

type
  TRpSaveEvent = procedure(var Stream: TStream; report: TRpReport;
    var handled: Boolean) of object;

  TRpDesignerLCL = class(TComponent)
  private
    FFilename: string;
    FReadOnly: Boolean;
    FReport: TRpReport;
    FModal: Boolean;
    FOnSave: TRpSaveEvent;
    procedure CheckLoaded;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadFromStream(stream: TStream);
    procedure LoadFromFile(AFilename: string);
    procedure SaveToStream(stream: TStream);
    procedure SaveToFile(AFilename: string);
    function Execute: Boolean;
    property Report: TRpReport read FReport write FReport;
  published
    property Filename: string read FFilename write FFilename;
    property ReadOnly: Boolean read FReadOnly write FReadOnly default False;
    property OnSave: TRpSaveEvent read FOnSave write FOnSave;
    property Modal: Boolean read FModal write FModal default True;
  end;

  TRpDesigner = TRpDesignerLCL;

implementation

uses
  rpmdfmainlcl;

constructor TRpDesignerLCL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FModal := True;
end;

destructor TRpDesignerLCL.Destroy;
begin
  FreeAndNil(FReport);
  inherited Destroy;
end;

procedure TRpDesignerLCL.LoadFromStream(stream: TStream);
begin
  FreeAndNil(FReport);
  FReport := TRpReport.Create(Self);
  try
    FReport.LoadFromStream(stream);
  except
    FreeAndNil(FReport);
    raise;
  end;
end;

procedure TRpDesignerLCL.LoadFromFile(AFilename: string);
begin
  FreeAndNil(FReport);
  FReport := TRpReport.Create(Self);
  try
    FReport.LoadFromFile(AFilename);
    FFilename := AFilename;
  except
    FreeAndNil(FReport);
    raise;
  end;
end;

procedure TRpDesignerLCL.CheckLoaded;
begin
  if Assigned(FReport) then
    Exit;
  if Length(FFilename) < 1 then
    raise Exception.Create(SRpNoFilename);
  LoadFromFile(FFilename);
end;

procedure TRpDesignerLCL.SaveToStream(stream: TStream);
begin
  CheckLoaded;
  FReport.SaveToStream(stream);
end;

procedure TRpDesignerLCL.SaveToFile(AFilename: string);
begin
  CheckLoaded;
  FReport.SaveToFile(AFilename);
  FFilename := AFilename;
end;

function TRpDesignerLCL.Execute: Boolean;
var
  handled: Boolean;
  stream: TStream;
  dia: TFRpMainFLCL;
  accepted, modified: Boolean;
  snapshot: TMemoryStream;
  restored: TRpReport;
begin
  // Returns True only when the modified report was accepted by the user and
  // saved (OnSave handler, stream or file)
  Result := False;
  accepted := False;
  modified := False;
  CheckLoaded;
  snapshot := TMemoryStream.Create;
  try
    // State to restore when the user discards the changes
    FReport.SaveToStream(snapshot);
    dia := TFRpMainFLCL.Create(nil);
    try
      // As rpmdesignervcl: New/Open/Save/Save as are not available, the
      // component saves the report
      dia.HostedMode := True;
      dia.Report := FReport;
      if Length(FFilename) > 0 then
        dia.FileName := FFilename;
      dia.RefreshInterface;
      dia.ShowModal;
      accepted := dia.SaveAccepted;
      modified := FReport.Modified;
    finally
      dia.Free;
    end;
    if (not accepted) and modified then
    begin
      // Changes discarded: the report goes back to its initial state
      snapshot.Seek(0, soFromBeginning);
      restored := TRpReport.Create(Self);
      try
        restored.LoadFromStream(snapshot);
      except
        restored.Free;
        raise;
      end;
      FReport.Free;
      FReport := restored;
    end;
  finally
    snapshot.Free;
  end;
  if FReadOnly or (not accepted) then
    Exit;
  handled := False;
  stream := nil;
  if Assigned(FOnSave) then
    FOnSave(stream, FReport, handled);
  if not handled then
  begin
    if Assigned(stream) then
      FReport.SaveToStream(stream)
    else
    if Length(FFilename) > 0 then
      FReport.SaveToFile(FFilename)
    else
      raise Exception.Create(SRpNoStreamToSaveReport);
  end;
  Result := True;
end;

end.
