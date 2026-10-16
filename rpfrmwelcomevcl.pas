{*******************************************************}
{                                                       }
{       Report Manager Designer                         }
{                                                       }
{       rpfrmwelcomevcl                                 }
{                                                       }
{       The welcome window: the sample reports, each    }
{       with the picture of its first page              }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpfrmwelcomevcl;

{ Built in code, no form file; design_lcl/rpfrmwelcomelcl is the Lazarus twin
  and Reportman.Designer/WelcomeForm.cs the .NET one. Shown at startup unless
  the user hides it ([Preferences] ShowWelcome of repmand.ini) and from Help.
  The samples come from rpsamplesutil. }

interface

{$I rpconf.inc}

uses
  Windows, Types, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  ShellAPI, pngimage, rpmdconsts, rpsamplesutil;

type
  TRpWelcomeAction = (rwaNone, rwaOpenSample, rwaNewReport, rwaOpenReport);

// Shows the welcome window. AShowAtStartup is the "do not show at startup"
// check box (inverted) in and out; ASamplePath, the sample to open (in the
// working copy) when the result is rwaOpenSample.
function RpShowWelcomeVCL(AOwner: TComponent; var AShowAtStartup: Boolean;
  out ASamplePath: string): TRpWelcomeAction;

implementation

const
  BandColor = $00794E1F;       // RGB 1F 4E 79, as the samples
  AccentColor = $00B6752E;     // RGB 2E 75 B6
  SelectedColor = $00F6ECE3;   // RGB E3 EC F6
  DescriptionColor = $00595959;
  SubtitleColor = $00F2E4D6;   // RGB D6 E4 F2

type
  TFRpWelcomeVCL = class(TForm)
  private
    FInstalled: string;
    FSamples: TList;
    FList: TListBox;
    FImage: TImage;
    FCheckHide: TCheckBox;
    FButtonOpen: TButton;
    FInfo: TLinkLabel;
    FAction: TRpWelcomeAction;
    FSamplePath: string;
    function S(AValue: Integer): Integer;
    procedure BuildControls;
    function MakeButton(AParent: TWinControl; const ACaption: string): TButton;
    function TextWidth: Integer;
    procedure ListMeasureItem(Control: TWinControl; Index: Integer; var Height: Integer);
    procedure ListDrawItem(Control: TWinControl; Index: Integer; ARect: TRect;
      State: TOwnerDrawState);
    procedure ListClick(Sender: TObject);
    procedure ListDblClick(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure NewClick(Sender: TObject);
    procedure OpenReportClick(Sender: TObject);
    procedure InfoLinkClick(Sender: TObject; const Link: string; LinkType: TSysLinkType);
    procedure ShowThumbnail;
    function TextHeightWrapped(const AText: string; AFont: TFont; AWidth: Integer): Integer;
  public
    constructor CreateWelcome(AOwner: TComponent);
    destructor Destroy; override;
  end;

function RpShowWelcomeVCL(AOwner: TComponent; var AShowAtStartup: Boolean;
  out ASamplePath: string): TRpWelcomeAction;
var
  form: TFRpWelcomeVCL;
begin
  ASamplePath := '';
  form := TFRpWelcomeVCL.CreateWelcome(AOwner);
  try
    form.FCheckHide.Checked := not AShowAtStartup;
    form.ShowModal;
    AShowAtStartup := not form.FCheckHide.Checked;
    Result := form.FAction;
    ASamplePath := form.FSamplePath;
  finally
    form.Free;
  end;
end;

{ TFRpWelcomeVCL }

function TFRpWelcomeVCL.S(AValue: Integer): Integer;
begin
  Result := (AValue * Screen.PixelsPerInch) div 96;
end;

constructor TFRpWelcomeVCL.CreateWelcome(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  FSamples := TList.Create;
  FInstalled := RpInstalledSamplesFolder;
  if FInstalled <> '' then
    RpLoadSamples(FInstalled, FSamples);
  BuildControls;
end;

destructor TFRpWelcomeVCL.Destroy;
begin
  RpFreeSamples(FSamples);
  FSamples.Free;
  inherited Destroy;
end;

function TFRpWelcomeVCL.MakeButton(AParent: TWinControl; const ACaption: string): TButton;
var
  needed: Integer;
begin
  Result := TButton.Create(Self);
  Result.Parent := AParent;
  Result.Caption := ACaption;
  Result.Width := S(132);
  Result.Height := S(32);
  Canvas.Font.Assign(Font);
  needed := Canvas.TextWidth(ACaption) + S(24);
  if needed > Result.Width then
    Result.Width := needed;
end;

procedure TFRpWelcomeVCL.BuildControls;
var
  band, bottom, info, content, pictureFrame, pictureBack, listFrame, gap, line: TPanel;
  title, subtitle: TLabel;
  buttonClose, buttonOpenReport, buttonNew: TButton;
  buttons: array[0..3] of TButton;
  i, x: Integer;
  working: string;
begin
  Caption := TranslateStr(1, 'Report Manager Designer');
  BorderStyle := bsDialog;
  Position := poMainFormCenter;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  Color := clWhite;
  ClientWidth := S(920);
  ClientHeight := S(620);

  // The band, with the welcome and what the samples are
  band := TPanel.Create(Self);
  band.Parent := Self;
  band.Align := alTop;
  band.Height := S(104);
  band.BevelOuter := bvNone;
  band.ParentBackground := False;
  band.Color := BandColor;
  title := TLabel.Create(Self);
  title.Parent := band;
  title.Caption := TranslateStr(2010, 'Welcome to Report Manager');
  title.Font.Name := 'Segoe UI';
  title.Font.Size := 17;
  title.Font.Style := [fsBold];
  title.Font.Color := clWhite;
  title.SetBounds(S(28), S(14), S(860), S(40));
  subtitle := TLabel.Create(Self);
  subtitle.Parent := band;
  subtitle.AutoSize := False;
  subtitle.WordWrap := True;
  subtitle.Caption := TranslateStr(2011, 'Open a sample report to see what Report Manager can do.');
  subtitle.Font.Name := 'Segoe UI';
  subtitle.Font.Size := 10;
  subtitle.Font.Color := SubtitleColor;
  subtitle.SetBounds(S(30), S(56), S(860), S(42));

  // Buttons and "do not show again"
  bottom := TPanel.Create(Self);
  bottom.Parent := Self;
  bottom.Align := alBottom;
  bottom.Height := S(60);
  bottom.BevelOuter := bvNone;
  bottom.ParentBackground := False;
  bottom.Color := $00F3F3F3;
  line := TPanel.Create(Self);
  line.Parent := bottom;
  line.Align := alTop;
  line.Height := 1;
  line.BevelOuter := bvNone;
  line.ParentBackground := False;
  line.Color := $00DDDDDD;
  FCheckHide := TCheckBox.Create(Self);
  FCheckHide.Parent := bottom;
  FCheckHide.Caption := TranslateStr(2016, 'Do not show this window at startup');
  FCheckHide.SetBounds(S(28), S(20), S(360), S(20));
  buttonClose := MakeButton(bottom, TranslateStr(1891, 'Close'));
  buttonClose.ModalResult := mrCancel;
  buttonClose.Cancel := True;
  buttonOpenReport := MakeButton(bottom, TranslateStr(214, 'Open report') + '...');
  buttonOpenReport.OnClick := OpenReportClick;
  buttonNew := MakeButton(bottom, TranslateStr(2015, 'New report'));
  buttonNew.OnClick := NewClick;
  FButtonOpen := MakeButton(bottom, TranslateStr(2014, 'Open sample'));
  FButtonOpen.Font.Style := [fsBold];
  FButtonOpen.Default := True;
  FButtonOpen.OnClick := OpenClick;
  buttons[0] := buttonClose;
  buttons[1] := buttonOpenReport;
  buttons[2] := buttonNew;
  buttons[3] := FButtonOpen;
  x := ClientWidth - S(28);
  for i := 0 to High(buttons) do
  begin
    x := x - buttons[i].Width;
    buttons[i].Left := x;
    buttons[i].Top := S(14);
    x := x - S(8);
  end;

  // Where the samples are opened from
  info := TPanel.Create(Self);
  info.Parent := Self;
  info.Align := alBottom;
  info.Height := S(34);
  info.BevelOuter := bvNone;
  info.ParentBackground := False;
  info.Color := clWhite;
  FInfo := TLinkLabel.Create(Self);
  FInfo.Parent := info;
  FInfo.SetBounds(S(28), S(8), ClientWidth - S(56), S(20));
  FInfo.Font.Color := DescriptionColor;
  FInfo.OnLinkClick := InfoLinkClick;
  working := ExcludeTrailingPathDelimiter(RpSamplesWorkingFolder);
  if FSamples.Count > 0 then
    FInfo.Caption := Format(TranslateStr(2017, 'The samples are copied to %s, where you can change and save them.'),
      ['<a>' + working + '</a>'])
  else
    FInfo.Caption := Format(TranslateStr(2018, 'The sample reports are not installed: folder %s not found.'),
      [ExtractFilePath(ParamStr(0)) + 'samples']);

  // The list and the picture of the selected sample
  content := TPanel.Create(Self);
  content.Parent := Self;
  content.Align := alClient;
  content.BevelOuter := bvNone;
  content.ParentBackground := False;
  content.Color := clWhite;
  content.Padding.SetBounds(S(28), S(20), S(28), S(4));
  pictureFrame := TPanel.Create(Self);
  pictureFrame.Parent := content;
  pictureFrame.Align := alRight;
  pictureFrame.Width := S(290);
  pictureFrame.BevelOuter := bvNone;
  pictureFrame.ParentBackground := False;
  pictureFrame.Color := $00C8C8C8;
  pictureFrame.Padding.SetBounds(1, 1, 1, 1);
  pictureBack := TPanel.Create(Self);
  pictureBack.Parent := pictureFrame;
  pictureBack.Align := alClient;
  pictureBack.BevelOuter := bvNone;
  pictureBack.ParentBackground := False;
  pictureBack.Color := clWhite;
  FImage := TImage.Create(Self);
  FImage.Parent := pictureBack;
  FImage.Align := alClient;
  FImage.Center := True;
  FImage.Proportional := True;
  FImage.Stretch := True;
  gap := TPanel.Create(Self);
  gap.Parent := content;
  gap.Align := alRight;
  gap.Width := S(20);
  gap.BevelOuter := bvNone;
  gap.ParentBackground := False;
  gap.Color := clWhite;
  listFrame := TPanel.Create(Self);
  listFrame.Parent := content;
  listFrame.Align := alClient;
  listFrame.BevelOuter := bvNone;
  listFrame.ParentBackground := False;
  listFrame.Color := $00DDDDDD;
  listFrame.Padding.SetBounds(1, 1, 1, 1);
  FList := TListBox.Create(Self);
  FList.Parent := listFrame;
  FList.Align := alClient;
  FList.BorderStyle := bsNone;
  FList.Style := lbOwnerDrawVariable;
  FList.OnMeasureItem := ListMeasureItem;
  FList.OnDrawItem := ListDrawItem;
  FList.OnClick := ListClick;
  FList.OnDblClick := ListDblClick;
  // The list measures an item as it is added, before its object is set:
  // measure and draw read FSamples, in the same order
  for i := 0 to FSamples.Count - 1 do
    FList.Items.AddObject(TRpSampleInfo(FSamples[i]).Title, TObject(FSamples[i]));
  if FList.Items.Count > 0 then
  begin
    FList.ItemIndex := 0;
    ShowThumbnail;
  end
  else
    FButtonOpen.Enabled := False;
  ActiveControl := FList;
end;

function TFRpWelcomeVCL.TextWidth: Integer;
begin
  // The list: the client minus the margins, the picture and the gap
  Result := ClientWidth - S(28) * 2 - S(290) - S(20) - 2 - S(36) -
    GetSystemMetrics(SM_CXVSCROLL);
end;

function TFRpWelcomeVCL.TextHeightWrapped(const AText: string; AFont: TFont;
  AWidth: Integer): Integer;
var
  r: TRect;
begin
  Canvas.Font.Assign(AFont);
  r := Rect(0, 0, AWidth, 0);
  DrawText(Canvas.Handle, PChar(AText), Length(AText), r,
    DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
  Result := r.Bottom;
end;

procedure TFRpWelcomeVCL.ListMeasureItem(Control: TWinControl; Index: Integer;
  var Height: Integer);
var
  sample: TRpSampleInfo;
  titleFont, descriptionFont: TFont;
begin
  sample := TRpSampleInfo(FSamples[Index]);
  titleFont := TFont.Create;
  descriptionFont := TFont.Create;
  try
    titleFont.Name := 'Segoe UI';
    titleFont.Size := 10;
    titleFont.Style := [fsBold];
    descriptionFont.Name := 'Segoe UI';
    descriptionFont.Size := 9;
    Height := S(12) + TextHeightWrapped(sample.Title, titleFont, TextWidth) + S(3) +
      TextHeightWrapped(sample.Description, descriptionFont, TextWidth) + S(12);
    if Height > 255 then
      Height := 255;
  finally
    titleFont.Free;
    descriptionFont.Free;
  end;
end;

procedure TFRpWelcomeVCL.ListDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
var
  sample: TRpSampleInfo;
  c: TCanvas;
  r: TRect;
  titleHeight: Integer;
begin
  sample := TRpSampleInfo(FSamples[Index]);
  c := FList.Canvas;
  c.Brush.Style := bsSolid;
  if odSelected in State then
    c.Brush.Color := SelectedColor
  else
    c.Brush.Color := clWhite;
  c.FillRect(ARect);
  if odSelected in State then
  begin
    c.Brush.Color := AccentColor;
    c.FillRect(Rect(ARect.Left, ARect.Top, ARect.Left + S(4), ARect.Bottom));
  end
  else
  if Index < FList.Items.Count - 1 then
  begin
    c.Pen.Color := $00ECECEC;
    c.MoveTo(ARect.Left + S(18), ARect.Bottom - 1);
    c.LineTo(ARect.Right - S(18), ARect.Bottom - 1);
  end;
  c.Brush.Style := bsClear;
  c.Font.Name := 'Segoe UI';
  c.Font.Size := 10;
  c.Font.Style := [fsBold];
  c.Font.Color := BandColor;
  r := Rect(ARect.Left + S(18), ARect.Top + S(12), ARect.Left + S(18) + TextWidth, ARect.Bottom);
  titleHeight := DrawText(c.Handle, PChar(sample.Title), Length(sample.Title), r,
    DT_WORDBREAK or DT_NOPREFIX);
  c.Font.Size := 9;
  c.Font.Style := [];
  c.Font.Color := DescriptionColor;
  r.Top := r.Top + titleHeight + S(3);
  DrawText(c.Handle, PChar(sample.Description), Length(sample.Description), r,
    DT_WORDBREAK or DT_NOPREFIX);
  if odFocused in State then
    c.DrawFocusRect(ARect);
end;

procedure TFRpWelcomeVCL.ShowThumbnail;
var
  sample: TRpSampleInfo;
  fileName: string;
begin
  FImage.Picture := nil;
  if FList.ItemIndex < 0 then
    Exit;
  sample := TRpSampleInfo(FSamples[FList.ItemIndex]);
  if sample.Thumbnail = '' then
    Exit;
  fileName := FInstalled + sample.Thumbnail;
  if FileExists(fileName) then
  try
    FImage.Picture.LoadFromFile(fileName);
  except
    FImage.Picture := nil;
  end;
end;

procedure TFRpWelcomeVCL.ListClick(Sender: TObject);
begin
  ShowThumbnail;
end;

procedure TFRpWelcomeVCL.ListDblClick(Sender: TObject);
begin
  OpenClick(Sender);
end;

procedure TFRpWelcomeVCL.OpenClick(Sender: TObject);
var
  sample: TRpSampleInfo;
  working: string;
begin
  if FList.ItemIndex < 0 then
    Exit;
  sample := TRpSampleInfo(FSamples[FList.ItemIndex]);
  working := RpSamplesWorkingFolder;
  try
    RpUpdateSamplesWorkingCopy(FInstalled, working);
    FSamplePath := working + sample.FileName;
  except
    // Without a working copy (no documents folder, no space...) the installed
    // sample still opens; saving it may need another folder
    FSamplePath := FInstalled + sample.FileName;
  end;
  FAction := rwaOpenSample;
  ModalResult := mrOk;
end;

procedure TFRpWelcomeVCL.NewClick(Sender: TObject);
begin
  FAction := rwaNewReport;
  ModalResult := mrOk;
end;

procedure TFRpWelcomeVCL.OpenReportClick(Sender: TObject);
begin
  FAction := rwaOpenReport;
  ModalResult := mrOk;
end;

procedure TFRpWelcomeVCL.InfoLinkClick(Sender: TObject; const Link: string;
  LinkType: TSysLinkType);
var
  working: string;
begin
  working := RpSamplesWorkingFolder;
  if FInstalled <> '' then
    RpUpdateSamplesWorkingCopy(FInstalled, working);
  ShellExecute(Handle, 'open', PChar(working), nil, nil, SW_SHOWNORMAL);
end;

end.
