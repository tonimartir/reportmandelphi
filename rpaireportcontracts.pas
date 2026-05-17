unit rpaireportcontracts;

interface

{$I rpconf.inc}

uses
  SysUtils, Classes, System.JSON;

type
  TRpAIErrorType = (raetInappropriateContent, raetInaccurateContent);

  TRpAIReport = class(TPersistent)
  private
    FAIContent: string;
    FErrorType: TRpAIErrorType;
    FUserComments: string;
  public
    procedure Assign(Source: TPersistent); override;
    function ToJsonObject: TJSONObject;
    property AIContent: string read FAIContent write FAIContent;
    property ErrorType: TRpAIErrorType read FErrorType write FErrorType;
    property UserComments: string read FUserComments write FUserComments;
  end;

function RpAIErrorTypeToString(AValue: TRpAIErrorType): string;

implementation

function RpAIErrorTypeToString(AValue: TRpAIErrorType): string;
begin
  case AValue of
    raetInaccurateContent:
      Result := 'InaccurateContent';
  else
    Result := 'InappropriateContent';
  end;
end;

procedure TRpAIReport.Assign(Source: TPersistent);
begin
  if Source is TRpAIReport then
  begin
    FAIContent := TRpAIReport(Source).AIContent;
    FErrorType := TRpAIReport(Source).ErrorType;
    FUserComments := TRpAIReport(Source).UserComments;
  end
  else
    inherited Assign(Source);
end;

function TRpAIReport.ToJsonObject: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('errorType', RpAIErrorTypeToString(FErrorType));
  Result.AddPair('userComments', FUserComments);
  Result.AddPair('aiContent', FAIContent);
end;

end.
