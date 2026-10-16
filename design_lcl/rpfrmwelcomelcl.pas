{*******************************************************}
{                                                       }
{       Report Manager Designer LCL                     }
{                                                       }
{       rpfrmwelcomelcl                                 }
{                                                       }
{       The welcome window: the sample reports, each    }
{       with the picture of its first page              }
{       (LCL port of rpfrmwelcomevcl)                   }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{       This file is under the MPL license              }
{                                                       }
{*******************************************************}

unit rpfrmwelcomelcl;

{ Built in code, no form file, as rpfrmwelcomevcl (and the .NET
  WelcomeForm). The list draws its items (a title and a description): with a
  fixed height, the one of the longest item, which every widgetset supports
  (Cocoa, GTK and Qt). The samples come from rpsamplesutil. }

{$mode delphi}

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, LCLType,
  LCLIntf, rpsamplesutil;

type
  TRpWelcomeAction = (rwaNone, rwaOpenSample, rwaNewReport, rwaOpenReport);

// Shows the welcome window. AShowAtStartup is the "do not show at startup"
// check box (inverted) in and out; ASamplePath, the sample to open (in the
// working copy) when the result is rwaOpenSample.
function RpShowWelcomeLCL(AOwner: TComponent; var AShowAtStartup: Boolean;
  out ASamplePath: string): TRpWelcomeAction;

implementation

uses
  rpmdconsts, rpchatmodernstylelcl, rplcllayout;

const
  BandColor = $00794E1F;       // RGB 1F 4E 79, as the samples
  AccentColor = $00B6752E;     // RGB 2E 75 B6
  SelectedColor = $00F6ECE3;   // RGB E3 EC F6
  DescriptionColor = $00595959;
  SubtitleColor = $00F2E4D6;   // RGB D6 E4 F2

type
  TFRpWelcomeLCL = class(TForm)
  private
    FInstalled: string;
    FSamples: TList;
    FList: TListBox;
    FImage: TImage;
    FCheckHide: TCheckBox;
    FButtonOpen: TButton;
    FAction: TRpWelcomeAction;
    FSamplePath: string;
    FTextWidth: Integer;
    procedure BuildControls;
    function MakeButton(AParent: TWinControl; const ACaption: string): TButton;
    function ItemHeightFor(ACanvas: TCanvas; ASample: TRpSampleInfo): Integer;
    procedure SetTitleFont(AFont: TFont);
    procedure SetDescriptionFont(AFont: TFont);
    procedure ListDrawItem(Control: TWinControl; Index: Integer; ARect: TRect;
      State: TOwnerDrawState);
    procedure ListSelectionChange(Sender: TObject; User: Boolean);
    procedure ListDblClick(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure NewClick(Sender: TObject);
    procedure OpenReportClick(Sender: TObject);
    procedure InfoClick(Sender: TObject);
    procedure ShowThumbnail;
  public
    constructor CreateWelcome(AOwner: TComponent);
    destructor Destroy; override;
  end;

function RpShowWelcomeLCL(AOwner: TComponent; var AShowAtStartup: Boolean;
  out ASamplePath: string): TRpWelcomeAction;
var
  form: TFRpWelcomeLCL;
begin
  ASamplePath := '';
  form := TFRpWelcomeLCL.CreateWelcome(AOwner);
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

{ TFRpWelcomeLCL }

constructor TFRpWelcomeLCL.CreateWelcome(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  // Sizes in pixels of the screen: the LCL does not scale it again
  RpBuiltInScreenPixels(Self);
  FSamples := TList.Create;
  FInstalled := RpInstalledSamplesFolder;
  if FInstalled <> '' then
    RpLoadSamples(FInstalled, FSamples);
  BuildControls;
end;

destructor TFRpWelcomeLCL.Destroy;
begin
  RpFreeSamples(FSamples);
  FSamples.Free;
  inherited Destroy;
end;

procedure TFRpWelcomeLCL.SetTitleFont(AFont: TFont);
begin
  AFont.Size := 11;
  AFont.Style := [fsBold];
  AFont.Color := BandColor;
end;

procedure TFRpWelcomeLCL.SetDescriptionFont(AFont: TFont);
begin
  AFont.Size := 9;
  AFont.Style := [];
  AFont.Color := DescriptionColor;
end;

function TFRpWelcomeLCL.MakeButton(AParent: TWinControl; const ACaption: string): TButton;
var
  needed: Integer;
  measure: TBitmap;
begin
  Result := TButton.Create(Self);
  Result.Parent := AParent;
  Result.Caption := ACaption;
  Result.Width := Scale(132);
  Result.Height := Scale(32);
  // A button has no canvas: the width of the caption on a bitmap
  measure := TBitmap.Create;
  try
    measure.SetSize(8, 8);
    measure.Canvas.Font.Assign(Result.Font);
    needed := measure.Canvas.TextWidth(ACaption) + Scale(28);
  finally
    measure.Free;
  end;
  if needed > Result.Width then
    Result.Width := needed;
end;

// Title, a gap and the description, wrapped in the width of the text
function TFRpWelcomeLCL.ItemHeightFor(ACanvas: TCanvas; ASample: TRpSampleInfo): Integer;
var
  r: TRect;
begin
  Result := Scale(12);
  SetTitleFont(ACanvas.Font);
  r := Rect(0, 0, FTextWidth, 0);
  DrawText(ACanvas.Handle, PChar(ASample.Title), Length(ASample.Title), r,
    DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
  Result := Result + r.Bottom + Scale(3);
  SetDescriptionFont(ACanvas.Font);
  r := Rect(0, 0, FTextWidth, 0);
  DrawText(ACanvas.Handle, PChar(ASample.Description), Length(ASample.Description), r,
    DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
  Result := Result + r.Bottom + Scale(12);
end;

procedure TFRpWelcomeLCL.BuildControls;
var
  band, bottom, info, content, pictureFrame, pictureBack, listFrame, gap: TPanel;
  title, subtitle, infoLabel: TLabel;
  buttonClose, buttonOpenReport, buttonNew: TButton;
  buttons: array[0..3] of TButton;
  i, x, maxHeight: Integer;
  measure: TBitmap;
begin
  Caption := TranslateStr(1, 'Report Manager Designer');
  BorderStyle := bsDialog;
  Position := poMainFormCenter;
  Color := clWhite;
  ClientWidth := Scale(920);
  ClientHeight := Scale(620);

  // The band, with the welcome and what the samples are
  band := TPanel.Create(Self);
  band.Parent := Self;
  band.Align := alTop;
  band.Height := Scale(104);
  band.BevelOuter := bvNone;
  band.Color := BandColor;
  title := TLabel.Create(Self);
  title.Parent := band;
  title.AutoSize := False;
  title.Caption := TranslateStr(2010, 'Welcome to Report Manager');
  title.Font.Size := 17;
  title.Font.Style := [fsBold];
  title.Font.Color := clWhite;
  title.SetBounds(Scale(28), Scale(14), Scale(860), Scale(40));
  subtitle := TLabel.Create(Self);
  subtitle.Parent := band;
  subtitle.AutoSize := False;
  subtitle.WordWrap := True;
  subtitle.Caption := TranslateStr(2011, 'Open a sample report to see what Report Manager can do.');
  subtitle.Font.Size := 10;
  subtitle.Font.Color := SubtitleColor;
  subtitle.SetBounds(Scale(30), Scale(56), Scale(860), Scale(44));

  // Buttons and "do not show again"
  bottom := TPanel.Create(Self);
  bottom.Parent := Self;
  bottom.Align := alBottom;
  bottom.Height := Scale(60);
  bottom.BevelOuter := bvNone;
  bottom.Color := $00F3F3F3;
  FCheckHide := TCheckBox.Create(Self);
  FCheckHide.Parent := bottom;
  FCheckHide.Caption := TranslateStr(2016, 'Do not show this window at startup');
  FCheckHide.SetBounds(Scale(28), Scale(20), Scale(360), Scale(22));
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
  x := ClientWidth - Scale(28);
  for i := 0 to High(buttons) do
  begin
    x := x - buttons[i].Width;
    buttons[i].Left := x;
    buttons[i].Top := Scale(14);
    x := x - Scale(8);
  end;

  // Where the samples are opened from (a click opens the folder)
  info := TPanel.Create(Self);
  info.Parent := Self;
  info.Align := alBottom;
  info.Height := Scale(34);
  info.BevelOuter := bvNone;
  info.Color := clWhite;
  infoLabel := TLabel.Create(Self);
  infoLabel.Parent := info;
  infoLabel.AutoSize := False;
  infoLabel.SetBounds(Scale(28), Scale(8), ClientWidth - Scale(56), Scale(20));
  if FSamples.Count > 0 then
  begin
    infoLabel.Caption := Format(TranslateStr(2017,
      'The samples are copied to %s, where you can change and save them.'),
      [ExcludeTrailingPathDelimiter(RpSamplesWorkingFolder)]);
    infoLabel.Font.Color := AccentColor;
    infoLabel.Cursor := crHandPoint;
    infoLabel.OnClick := InfoClick;
  end
  else
  begin
    infoLabel.Caption := Format(TranslateStr(2018,
      'The sample reports are not installed: folder %s not found.'),
      [ExtractFilePath(ParamStr(0)) + 'samples']);
    infoLabel.Font.Color := DescriptionColor;
  end;

  // The list and the picture of the selected sample
  content := TPanel.Create(Self);
  content.Parent := Self;
  content.Align := alClient;
  content.BevelOuter := bvNone;
  content.Color := clWhite;
  content.BorderSpacing.Left := Scale(28);
  content.BorderSpacing.Right := Scale(28);
  content.BorderSpacing.Top := Scale(20);
  content.BorderSpacing.Bottom := Scale(4);
  pictureFrame := TPanel.Create(Self);
  pictureFrame.Parent := content;
  pictureFrame.Align := alRight;
  pictureFrame.Width := Scale(290);
  pictureFrame.BevelOuter := bvNone;
  pictureFrame.Color := $00C8C8C8;
  pictureBack := TPanel.Create(Self);
  pictureBack.Parent := pictureFrame;
  pictureBack.Align := alClient;
  pictureBack.BorderSpacing.Around := 1;
  pictureBack.BevelOuter := bvNone;
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
  gap.Width := Scale(20);
  gap.BevelOuter := bvNone;
  gap.Color := clWhite;
  listFrame := TPanel.Create(Self);
  listFrame.Parent := content;
  listFrame.Align := alClient;
  listFrame.BevelOuter := bvNone;
  listFrame.Color := $00DDDDDD;
  FList := TListBox.Create(Self);
  FList.Parent := listFrame;
  FList.Align := alClient;
  FList.BorderSpacing.Around := 1;
  FList.BorderStyle := bsNone;
  FList.Color := clWhite;
  FList.Style := lbOwnerDrawFixed;
  FList.OnDrawItem := ListDrawItem;
  FList.OnSelectionChange := ListSelectionChange;
  FList.OnDblClick := ListDblClick;

  // The width of the text: the list minus the margins, the picture, the gap
  // and room for a scroll bar
  FTextWidth := ClientWidth - Scale(28) * 2 - Scale(290) - Scale(20) - 2 -
    Scale(36) - Scale(18);
  maxHeight := Scale(60);
  measure := TBitmap.Create;
  try
    measure.SetSize(8, 8);
    for i := 0 to FSamples.Count - 1 do
    begin
      x := ItemHeightFor(measure.Canvas, TRpSampleInfo(FSamples[i]));
      if x > maxHeight then
        maxHeight := x;
    end;
  finally
    measure.Free;
  end;
  FList.ItemHeight := maxHeight;
  for i := 0 to FSamples.Count - 1 do
    FList.Items.Add(TRpSampleInfo(FSamples[i]).Title);
  if FList.Items.Count > 0 then
  begin
    FList.ItemIndex := 0;
    ShowThumbnail;
  end
  else
    FButtonOpen.Enabled := False;
  ActiveControl := FList;
end;

procedure TFRpWelcomeLCL.ListDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
var
  sample: TRpSampleInfo;
  c: TCanvas;
  r: TRect;
  titleHeight: Integer;
begin
  if (Index < 0) or (Index >= FSamples.Count) then
    Exit;
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
    c.FillRect(Rect(ARect.Left, ARect.Top, ARect.Left + Scale(4), ARect.Bottom));
  end
  else
  if Index < FSamples.Count - 1 then
  begin
    c.Pen.Color := $00ECECEC;
    c.Line(ARect.Left + Scale(18), ARect.Bottom - 1, ARect.Right - Scale(18), ARect.Bottom - 1);
  end;
  c.Brush.Style := bsClear;
  SetTitleFont(c.Font);
  r := Rect(ARect.Left + Scale(18), ARect.Top + Scale(12),
    ARect.Left + Scale(18) + FTextWidth, ARect.Bottom);
  titleHeight := DrawText(c.Handle, PChar(sample.Title), Length(sample.Title), r,
    DT_WORDBREAK or DT_NOPREFIX);
  SetDescriptionFont(c.Font);
  r.Top := r.Top + titleHeight + Scale(3);
  DrawText(c.Handle, PChar(sample.Description), Length(sample.Description), r,
    DT_WORDBREAK or DT_NOPREFIX);
end;

procedure TFRpWelcomeLCL.ShowThumbnail;
var
  sample: TRpSampleInfo;
  fileName: string;
begin
  FImage.Picture.Clear;
  if (FList.ItemIndex < 0) or (FList.ItemIndex >= FSamples.Count) then
    Exit;
  sample := TRpSampleInfo(FSamples[FList.ItemIndex]);
  if sample.Thumbnail = '' then
    Exit;
  fileName := FInstalled + sample.Thumbnail;
  if FileExists(fileName) then
  try
    FImage.Picture.LoadFromFile(fileName);
  except
    FImage.Picture.Clear;
  end;
end;

procedure TFRpWelcomeLCL.ListSelectionChange(Sender: TObject; User: Boolean);
begin
  ShowThumbnail;
end;

procedure TFRpWelcomeLCL.ListDblClick(Sender: TObject);
begin
  OpenClick(Sender);
end;

procedure TFRpWelcomeLCL.OpenClick(Sender: TObject);
var
  sample: TRpSampleInfo;
  working: string;
begin
  if (FList.ItemIndex < 0) or (FList.ItemIndex >= FSamples.Count) then
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

procedure TFRpWelcomeLCL.NewClick(Sender: TObject);
begin
  FAction := rwaNewReport;
  ModalResult := mrOk;
end;

procedure TFRpWelcomeLCL.OpenReportClick(Sender: TObject);
begin
  FAction := rwaOpenReport;
  ModalResult := mrOk;
end;

procedure TFRpWelcomeLCL.InfoClick(Sender: TObject);
var
  working: string;
begin
  working := RpSamplesWorkingFolder;
  if FInstalled <> '' then
    RpUpdateSamplesWorkingCopy(FInstalled, working);
  OpenDocument(ExcludeTrailingPathDelimiter(working));
end;

end.
