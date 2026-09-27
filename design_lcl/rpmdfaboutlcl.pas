{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpmdfaboutlcl                                   }
{       About box for Report Manager Designer LCL       }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpmdfaboutlcl;

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, Buttons, LCLIntf,
  rpmdconsts;

type
  { TFRpAboutBoxLCL }

  TFRpAboutBoxLCL = class(TForm)
  private
    FPanelTop: TPanel;
    FPanelBottom: TPanel;
    FMemoLicense: TMemo;
    FLTitle: TLabel;
    FLVersion: TLabel;
    FLAuthor: TLabel;
    FLProject: TLabel;
    FLProjectLink: TLabel;
    FBOK: TButton;

    procedure ProjectLinkClick(Sender: TObject);
    procedure BOKClick(Sender: TObject);
    procedure BuildControls;
  public
    constructor Create(AOwner: TComponent); override;
  end;

procedure ShowAbout;

implementation

procedure ShowAbout;
var
  dia: TFRpAboutBoxLCL;
begin
  dia := TFRpAboutBoxLCL.Create(Application);
  try
    dia.ShowModal;
  finally
    dia.Free;
  end;
end;

{ TFRpAboutBoxLCL }

constructor TFRpAboutBoxLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);

  Caption := TranslateStr(88, 'About Report Manager');
  Width := 460;
  Height := 340;
  Position := poScreenCenter;
  BorderStyle := bsDialog;

  BuildControls;
end;

procedure TFRpAboutBoxLCL.BuildControls;
var
  verStr: string;
begin
  // Top Panel
  FPanelTop := TPanel.Create(Self);
  FPanelTop.Parent := Self;
  FPanelTop.Align := alTop;
  FPanelTop.Height := 130;
  FPanelTop.BevelOuter := bvNone;
  FPanelTop.Color := clWindow;

  FLTitle := TLabel.Create(Self);
  FLTitle.Parent := FPanelTop;
  FLTitle.Caption := 'Report Manager Designer';
  FLTitle.Font.Size := 14;
  FLTitle.Font.Style := [fsBold];
  FLTitle.Left := 20;
  FLTitle.Top := 12;

  verStr := TranslateStr(91, 'Version') + ' ' + RM_VERSION;
  if SizeOf(Pointer) = 8 then
    verStr := verStr + ' (64-bit LCL)'
  else
    verStr := verStr + ' (32-bit LCL)';

  FLVersion := TLabel.Create(Self);
  FLVersion.Parent := FPanelTop;
  FLVersion.Caption := verStr;
  FLVersion.Font.Size := 10;
  FLVersion.Font.Color := clGrayText;
  FLVersion.Left := 20;
  FLVersion.Top := 40;

  FLAuthor := TLabel.Create(Self);
  FLAuthor.Parent := FPanelTop;
  FLAuthor.Caption := TranslateStr(89, 'Author: ') + 'Toni Martir <toni@reportman.es>';
  FLAuthor.Left := 20;
  FLAuthor.Top := 68;

  FLProject := TLabel.Create(Self);
  FLProject.Parent := FPanelTop;
  FLProject.Caption := TranslateStr(90, 'Project: ');
  FLProject.Left := 20;
  FLProject.Top := 92;

  FLProjectLink := TLabel.Create(Self);
  FLProjectLink.Parent := FPanelTop;
  FLProjectLink.Caption := 'https://reportman.es';
  FLProjectLink.Font.Color := clHighlight;
  FLProjectLink.Font.Style := [fsUnderline];
  FLProjectLink.Cursor := crHandPoint;
  FLProjectLink.Left := 75;
  FLProjectLink.Top := 92;
  FLProjectLink.OnClick := ProjectLinkClick;

  // Bottom Panel
  FPanelBottom := TPanel.Create(Self);
  FPanelBottom.Parent := Self;
  FPanelBottom.Align := alBottom;
  FPanelBottom.Height := 44;
  FPanelBottom.BevelOuter := bvNone;

  FBOK := TButton.Create(Self);
  FBOK.Parent := FPanelBottom;
  FBOK.Caption := TranslateStr(93, 'OK');
  FBOK.Left := FPanelBottom.Width - 95;
  FBOK.Top := 8;
  FBOK.Width := 80;
  FBOK.Height := 28;
  FBOK.Anchors := [akTop, akRight];
  FBOK.Default := True;
  FBOK.OnClick := BOKClick;

  // Center Memo
  FMemoLicense := TMemo.Create(Self);
  FMemoLicense.Parent := Self;
  FMemoLicense.Align := alClient;
  FMemoLicense.ReadOnly := True;
  FMemoLicense.ScrollBars := ssVertical;
  FMemoLicense.Lines.Add('Report Manager is free software distributed under the Mozilla Public License (MPL).');
  FMemoLicense.Lines.Add('');
  FMemoLicense.Lines.Add('Cross-platform reporting engine and visual designer for Lazarus / Free Pascal and Delphi.');
  FMemoLicense.Lines.Add('');
  FMemoLicense.Lines.Add('Copyright (c) 1994-2026 Toni Martir.');
  FMemoLicense.Lines.Add('All rights reserved.');
end;

procedure TFRpAboutBoxLCL.ProjectLinkClick(Sender: TObject);
begin
  OpenURL('https://reportman.es');
end;

procedure TFRpAboutBoxLCL.BOKClick(Sender: TObject);
begin
  ModalResult := mrOk;
  Close;
end;

end.
