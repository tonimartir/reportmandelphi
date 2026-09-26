{*******************************************************}
{                                                       }
{       Report Manager Designer - LCL                   }
{                                                       }
{       rpmdfmainlcl.pas                                }
{       Main reusable report designer form for LCL      }
{                                                       }
{       Copyright (c) 1994-2026 Toni Martir             }
{       toni@reportman.es                               }
{                                                       }
{*******************************************************}

unit rpmdfmainlcl;

{$mode delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, StdCtrls, ComCtrls, Menus, LCLType,
  rpreport, rpsubreport, rpmdfdesignlcl, rprulerlcl, rpmunits,
  rpmdobinsintlcl, rpmdfsectionintlcl, rpmdobjinsplcl, rpmdconsts,
  rplabelitem, rpdrawitem, rpmdbarcode, rpmdchart, rpsection, rptypes,
  rpmdimageslcl, rpmdfstruclcl, rpdbbrowserlcl, rpmdfdinfolcl,
  rppagesetuplcl, rplclpreview, rppreviewcontrol;

type
  TFRpMainFLCL = class(TForm)
  private
    FReport: TRpReport;
    FFileName: string;
    FOwnsReport: Boolean;

    // Visual Controls
    MainMenu1: TMainMenu;
    MainToolBar: TToolBar;
    ImageList1: TImageList;
    PLeft: TPanel;
    SplitterStruct: TSplitter;
    SplitterMain: TSplitter;
    PClient: TPanel;
    StatusBar: TStatusBar;

    // Frames
    FDesignerFrame: TFRpDesignFrameLCL;
    FObjInsp: TFRpObjInspLCL;
    FStructure: TFRpStructureLCL;

    // Toolbar buttons
    BtnNew: TToolButton;
    BtnOpen: TToolButton;
    BtnSave: TToolButton;
    BtnDataConfig: TToolButton;
    BtnPageSetup: TToolButton;
    Sep1: TToolButton;
    BtnPrint: TToolButton;
    BtnPreview: TToolButton;
    Sep2: TToolButton;
    BtnUndo: TToolButton;
    BtnRedo: TToolButton;
    Sep3: TToolButton;
    BtnToolArrow: TToolButton;
    BtnToolLabel: TToolButton;
    BtnToolExpr: TToolButton;
    BtnToolShape: TToolButton;
    BtnToolImage: TToolButton;
    BtnToolChart: TToolButton;
    BtnToolBarcode: TToolButton;
    Sep4: TToolButton;
    ComboScale: TComboBox;
    Sep5: TToolButton;
    BtnDelete: TToolButton;
    BtnCut: TToolButton;
    BtnCopy: TToolButton;
    BtnPaste: TToolButton;
    Sep6: TToolButton;
    BtnToFront: TToolButton;
    BtnToBack: TToolButton;
    BtnSelectAll: TToolButton;

    // Dialogs
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;

    // Menu items
    MenuFile: TMenuItem;
    MenuFileNew: TMenuItem;
    MenuFileOpen: TMenuItem;
    MenuFileSave: TMenuItem;
    MenuFileSaveAs: TMenuItem;
    MenuFilePageSetup: TMenuItem;
    MenuFilePreview: TMenuItem;
    MenuFilePrint: TMenuItem;
    MenuFileExit: TMenuItem;
    MenuEdit: TMenuItem;
    MenuEditUndo: TMenuItem;
    MenuEditRedo: TMenuItem;
    MenuEditCut: TMenuItem;
    MenuEditCopy: TMenuItem;
    MenuEditPaste: TMenuItem;
    MenuEditDelete: TMenuItem;
    MenuEditSelectAll: TMenuItem;
    MenuView: TMenuItem;
    MenuViewGrid: TMenuItem;
    MenuViewRulers: TMenuItem;
    MenuViewUnitsCm: TMenuItem;
    MenuViewUnitsInches: TMenuItem;
    MenuViewScale50: TMenuItem;
    MenuViewScale100: TMenuItem;
    MenuViewScale150: TMenuItem;
    MenuViewScale200: TMenuItem;
    MenuReport: TMenuItem;
    MenuReportDataConfig: TMenuItem;
    MenuReportPageSetup: TMenuItem;
    MenuHelp: TMenuItem;
    MenuHelpAbout: TMenuItem;

    procedure BuildMenus;
    procedure BuildControls;
    procedure SetReport(Value: TRpReport);
    procedure SetFileName(const Value: string);

    // Event handlers
    procedure BtnNewClick(Sender: TObject);
    procedure BtnOpenClick(Sender: TObject);
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnSaveAsClick(Sender: TObject);
    procedure BtnDataConfigClick(Sender: TObject);
    procedure BtnPageSetupClick(Sender: TObject);
    procedure BtnPrintClick(Sender: TObject);
    procedure BtnPreviewClick(Sender: TObject);
    procedure BtnUndoClick(Sender: TObject);
    procedure BtnRedoClick(Sender: TObject);
    procedure BtnToolClick(Sender: TObject);
    procedure BtnDeleteClick(Sender: TObject);
    procedure BtnCutClick(Sender: TObject);
    procedure BtnCopyClick(Sender: TObject);
    procedure BtnPasteClick(Sender: TObject);
    procedure BtnToFrontClick(Sender: TObject);
    procedure BtnToBackClick(Sender: TObject);
    procedure BtnSelectAllClick(Sender: TObject);
    procedure ComboScaleChange(Sender: TObject);
    procedure MenuViewGridClick(Sender: TObject);
    procedure MenuViewUnitsClick(Sender: TObject);
    procedure MenuViewScaleClick(Sender: TObject);
    procedure MenuHelpAboutClick(Sender: TObject);
    procedure MenuFileExitClick(Sender: TObject);
    procedure DesignerToolChange(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure OpenReportFile(const AFileName: string);
    procedure SaveReportFile(const AFileName: string);
    procedure NewReport;
    procedure RefreshInterface;
    procedure UpdateStatus;
    procedure EmbedInControl(AParent: TWinControl);

    property Report: TRpReport read FReport write SetReport;
    property FileName: string read FFileName write SetFileName;
    property DesignerFrame: TFRpDesignFrameLCL read FDesignerFrame;
    property ObjInsp: TFRpObjInspLCL read FObjInsp;
    property Structure: TFRpStructureLCL read FStructure;
  end;

implementation

{$R *.lfm}

{ TFRpMainFLCL }

constructor TFRpMainFLCL.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Width := 980;
  Height := 680;
  Caption := 'Report Manager Designer';
  Position := poScreenCenter;
  Color := clBtnFace;
  FFileName := '';
  FOwnsReport := True;

  BuildMenus;
  BuildControls;

  // Initialize with a blank report
  NewReport;
end;

destructor TFRpMainFLCL.Destroy;
begin
  if FOwnsReport and Assigned(FReport) then
  begin
    if Assigned(FDesignerFrame) then
      FDesignerFrame.Report := nil;
    if Assigned(FStructure) then
      FStructure.Report := nil;
    FreeAndNil(FReport);
  end;
  inherited Destroy;
end;

procedure TFRpMainFLCL.BuildMenus;
var
  sep: TMenuItem;
begin
  MainMenu1 := TMainMenu.Create(Self);

  // File Menu
  MenuFile := TMenuItem.Create(MainMenu1);
  MenuFile.Caption := '&Archivo';
  MainMenu1.Items.Add(MenuFile);

  MenuFileNew := TMenuItem.Create(MenuFile);
  MenuFileNew.Caption := '&Nuevo';
  MenuFileNew.ShortCut := ShortCut(VK_N, [ssCtrl]);
  MenuFileNew.OnClick := BtnNewClick;
  MenuFile.Add(MenuFileNew);

  MenuFileOpen := TMenuItem.Create(MenuFile);
  MenuFileOpen.Caption := '&Abrir...';
  MenuFileOpen.ShortCut := ShortCut(VK_O, [ssCtrl]);
  MenuFileOpen.OnClick := BtnOpenClick;
  MenuFile.Add(MenuFileOpen);

  MenuFileSave := TMenuItem.Create(MenuFile);
  MenuFileSave.Caption := '&Guardar';
  MenuFileSave.ShortCut := ShortCut(VK_S, [ssCtrl]);
  MenuFileSave.OnClick := BtnSaveClick;
  MenuFile.Add(MenuFileSave);

  MenuFileSaveAs := TMenuItem.Create(MenuFile);
  MenuFileSaveAs.Caption := 'Guardar &como...';
  MenuFileSaveAs.OnClick := BtnSaveAsClick;
  MenuFile.Add(MenuFileSaveAs);

  sep := TMenuItem.Create(MenuFile);
  sep.Caption := '-';
  MenuFile.Add(sep);

  MenuFilePageSetup := TMenuItem.Create(MenuFile);
  MenuFilePageSetup.Caption := '&Configurar página...';
  MenuFilePageSetup.OnClick := BtnPageSetupClick;
  MenuFile.Add(MenuFilePageSetup);

  sep := TMenuItem.Create(MenuFile);
  sep.Caption := '-';
  MenuFile.Add(sep);

  MenuFilePreview := TMenuItem.Create(MenuFile);
  MenuFilePreview.Caption := '&Vista previa';
  MenuFilePreview.ShortCut := ShortCut(VK_P, [ssCtrl]);
  MenuFilePreview.OnClick := BtnPreviewClick;
  MenuFile.Add(MenuFilePreview);

  MenuFilePrint := TMenuItem.Create(MenuFile);
  MenuFilePrint.Caption := '&Imprimir...';
  MenuFilePrint.OnClick := BtnPrintClick;
  MenuFile.Add(MenuFilePrint);

  sep := TMenuItem.Create(MenuFile);
  sep.Caption := '-';
  MenuFile.Add(sep);

  MenuFileExit := TMenuItem.Create(MenuFile);
  MenuFileExit.Caption := '&Salir';
  MenuFileExit.OnClick := MenuFileExitClick;
  MenuFile.Add(MenuFileExit);

  // Edit Menu
  MenuEdit := TMenuItem.Create(MainMenu1);
  MenuEdit.Caption := '&Edición';
  MainMenu1.Items.Add(MenuEdit);

  MenuEditUndo := TMenuItem.Create(MenuEdit);
  MenuEditUndo.Caption := '&Deshacer';
  MenuEditUndo.ShortCut := ShortCut(VK_Z, [ssCtrl]);
  MenuEditUndo.OnClick := BtnUndoClick;
  MenuEdit.Add(MenuEditUndo);

  MenuEditRedo := TMenuItem.Create(MenuEdit);
  MenuEditRedo.Caption := '&Rehacer';
  MenuEditRedo.ShortCut := ShortCut(VK_Y, [ssCtrl]);
  MenuEditRedo.OnClick := BtnRedoClick;
  MenuEdit.Add(MenuEditRedo);

  sep := TMenuItem.Create(MenuEdit);
  sep.Caption := '-';
  MenuEdit.Add(sep);

  MenuEditCut := TMenuItem.Create(MenuEdit);
  MenuEditCut.Caption := 'Cor&tar';
  MenuEditCut.ShortCut := ShortCut(VK_X, [ssCtrl]);
  MenuEditCut.OnClick := BtnCutClick;
  MenuEdit.Add(MenuEditCut);

  MenuEditCopy := TMenuItem.Create(MenuEdit);
  MenuEditCopy.Caption := '&Copiar';
  MenuEditCopy.ShortCut := ShortCut(VK_C, [ssCtrl]);
  MenuEditCopy.OnClick := BtnCopyClick;
  MenuEdit.Add(MenuEditCopy);

  MenuEditPaste := TMenuItem.Create(MenuEdit);
  MenuEditPaste.Caption := '&Pegar';
  MenuEditPaste.ShortCut := ShortCut(VK_V, [ssCtrl]);
  MenuEditPaste.OnClick := BtnPasteClick;
  MenuEdit.Add(MenuEditPaste);

  sep := TMenuItem.Create(MenuEdit);
  sep.Caption := '-';
  MenuEdit.Add(sep);

  MenuEditDelete := TMenuItem.Create(MenuEdit);
  MenuEditDelete.Caption := '&Eliminar selección';
  MenuEditDelete.ShortCut := ShortCut(VK_DELETE, []);
  MenuEditDelete.OnClick := BtnDeleteClick;
  MenuEdit.Add(MenuEditDelete);

  MenuEditSelectAll := TMenuItem.Create(MenuEdit);
  MenuEditSelectAll.Caption := '&Seleccionar todo';
  MenuEditSelectAll.ShortCut := ShortCut(VK_A, [ssCtrl]);
  MenuEditSelectAll.OnClick := BtnSelectAllClick;
  MenuEdit.Add(MenuEditSelectAll);

  // View Menu
  MenuView := TMenuItem.Create(MainMenu1);
  MenuView.Caption := '&Ver';
  MainMenu1.Items.Add(MenuView);

  MenuViewGrid := TMenuItem.Create(MenuView);
  MenuViewGrid.Caption := '&Cuadrícula (Grid)';
  MenuViewGrid.Checked := True;
  MenuViewGrid.OnClick := MenuViewGridClick;
  MenuView.Add(MenuViewGrid);

  MenuViewUnitsCm := TMenuItem.Create(MenuView);
  MenuViewUnitsCm.Caption := 'Unidades: Centímetros (cm)';
  MenuViewUnitsCm.Checked := True;
  MenuViewUnitsCm.RadioItem := True;
  MenuViewUnitsCm.Tag := 0;
  MenuViewUnitsCm.OnClick := MenuViewUnitsClick;
  MenuView.Add(MenuViewUnitsCm);

  MenuViewUnitsInches := TMenuItem.Create(MenuView);
  MenuViewUnitsInches.Caption := 'Unidades: Pulgadas (in)';
  MenuViewUnitsInches.RadioItem := True;
  MenuViewUnitsInches.Tag := 1;
  MenuViewUnitsInches.OnClick := MenuViewUnitsClick;
  MenuView.Add(MenuViewUnitsInches);

  sep := TMenuItem.Create(MenuView);
  sep.Caption := '-';
  MenuView.Add(sep);

  MenuViewScale50 := TMenuItem.Create(MenuView);
  MenuViewScale50.Caption := 'Escala 50%';
  MenuViewScale50.Tag := 50;
  MenuViewScale50.OnClick := MenuViewScaleClick;
  MenuView.Add(MenuViewScale50);

  MenuViewScale100 := TMenuItem.Create(MenuView);
  MenuViewScale100.Caption := 'Escala 100%';
  MenuViewScale100.Tag := 100;
  MenuViewScale100.OnClick := MenuViewScaleClick;
  MenuView.Add(MenuViewScale100);

  MenuViewScale150 := TMenuItem.Create(MenuView);
  MenuViewScale150.Caption := 'Escala 150%';
  MenuViewScale150.Tag := 150;
  MenuViewScale150.OnClick := MenuViewScaleClick;
  MenuView.Add(MenuViewScale150);

  MenuViewScale200 := TMenuItem.Create(MenuView);
  MenuViewScale200.Caption := 'Escala 200%';
  MenuViewScale200.Tag := 200;
  MenuViewScale200.OnClick := MenuViewScaleClick;
  MenuView.Add(MenuViewScale200);

  // Report Menu
  MenuReport := TMenuItem.Create(MainMenu1);
  MenuReport.Caption := '&Informe';
  MainMenu1.Items.Add(MenuReport);

  MenuReportDataConfig := TMenuItem.Create(MenuReport);
  MenuReportDataConfig.Caption := '&Configuración de acceso a datos...';
  MenuReportDataConfig.OnClick := BtnDataConfigClick;
  MenuReport.Add(MenuReportDataConfig);

  MenuReportPageSetup := TMenuItem.Create(MenuReport);
  MenuReportPageSetup.Caption := '&Configuración de página...';
  MenuReportPageSetup.OnClick := BtnPageSetupClick;
  MenuReport.Add(MenuReportPageSetup);

  // Help Menu
  MenuHelp := TMenuItem.Create(MainMenu1);
  MenuHelp.Caption := 'A&yuda';
  MainMenu1.Items.Add(MenuHelp);

  MenuHelpAbout := TMenuItem.Create(MenuHelp);
  MenuHelpAbout.Caption := '&Acerca de Report Manager...';
  MenuHelpAbout.OnClick := MenuHelpAboutClick;
  MenuHelp.Add(MenuHelpAbout);
end;

procedure TFRpMainFLCL.BuildControls;
begin
  // 1. ImageList (19x19 sharp premultiplied icons)
  ImageList1 := TImageList.Create(Self);
  ImageList1.Width := 19;
  ImageList1.Height := 19;
  LoadDesignerImageList(ImageList1);

  // 2. Toolbar
  MainToolBar := TToolBar.Create(Self);
  MainToolBar.Parent := Self;
  MainToolBar.Align := alTop;
  MainToolBar.Height := 32;
  MainToolBar.ButtonWidth := 26;
  MainToolBar.ButtonHeight := 26;
  MainToolBar.Flat := True;
  MainToolBar.ShowHint := True;
  MainToolBar.Images := ImageList1;

  BtnNew := TToolButton.Create(MainToolBar);
  BtnNew.Parent := MainToolBar;
  BtnNew.ImageIndex := IMG_NEW;
  BtnNew.Hint := 'Nuevo reporte';
  BtnNew.OnClick := BtnNewClick;

  BtnOpen := TToolButton.Create(MainToolBar);
  BtnOpen.Parent := MainToolBar;
  BtnOpen.ImageIndex := IMG_OPEN;
  BtnOpen.Hint := 'Abrir reporte...';
  BtnOpen.OnClick := BtnOpenClick;

  BtnSave := TToolButton.Create(MainToolBar);
  BtnSave.Parent := MainToolBar;
  BtnSave.ImageIndex := IMG_SAVE;
  BtnSave.Hint := 'Guardar reporte';
  BtnSave.OnClick := BtnSaveClick;

  BtnDataConfig := TToolButton.Create(MainToolBar);
  BtnDataConfig.Parent := MainToolBar;
  BtnDataConfig.ImageIndex := IMG_DATACONFIG;
  BtnDataConfig.Hint := 'Configuración de acceso a datos';
  BtnDataConfig.OnClick := BtnDataConfigClick;

  BtnPageSetup := TToolButton.Create(MainToolBar);
  BtnPageSetup.Parent := MainToolBar;
  BtnPageSetup.ImageIndex := IMG_PAGESETUP;
  BtnPageSetup.Hint := 'Configuración de página e informe';
  BtnPageSetup.OnClick := BtnPageSetupClick;

  Sep1 := TToolButton.Create(MainToolBar);
  Sep1.Parent := MainToolBar;
  Sep1.Style := tbsSeparator;
  Sep1.Width := 8;

  BtnPrint := TToolButton.Create(MainToolBar);
  BtnPrint.Parent := MainToolBar;
  BtnPrint.ImageIndex := IMG_PRINT;
  BtnPrint.Hint := 'Imprimir...';
  BtnPrint.OnClick := BtnPrintClick;

  BtnPreview := TToolButton.Create(MainToolBar);
  BtnPreview.Parent := MainToolBar;
  BtnPreview.ImageIndex := IMG_PREVIEW;
  BtnPreview.Hint := 'Vista previa';
  BtnPreview.OnClick := BtnPreviewClick;

  Sep2 := TToolButton.Create(MainToolBar);
  Sep2.Parent := MainToolBar;
  Sep2.Style := tbsSeparator;
  Sep2.Width := 8;

  BtnUndo := TToolButton.Create(MainToolBar);
  BtnUndo.Parent := MainToolBar;
  BtnUndo.ImageIndex := IMG_UNDO;
  BtnUndo.Hint := 'Deshacer';
  BtnUndo.OnClick := BtnUndoClick;

  BtnRedo := TToolButton.Create(MainToolBar);
  BtnRedo.Parent := MainToolBar;
  BtnRedo.ImageIndex := IMG_REDO;
  BtnRedo.Hint := 'Rehacer';
  BtnRedo.OnClick := BtnRedoClick;

  Sep3 := TToolButton.Create(MainToolBar);
  Sep3.Parent := MainToolBar;
  Sep3.Style := tbsSeparator;
  Sep3.Width := 8;

  BtnToolArrow := TToolButton.Create(MainToolBar);
  BtnToolArrow.Parent := MainToolBar;
  BtnToolArrow.ImageIndex := IMG_ARROW;
  BtnToolArrow.Hint := 'Herramienta Selección';
  BtnToolArrow.Grouped := True;
  BtnToolArrow.Style := tbsCheck;
  BtnToolArrow.Down := True;
  BtnToolArrow.OnClick := BtnToolClick;

  BtnToolLabel := TToolButton.Create(MainToolBar);
  BtnToolLabel.Parent := MainToolBar;
  BtnToolLabel.ImageIndex := IMG_LABEL;
  BtnToolLabel.Hint := 'Insertar Etiqueta';
  BtnToolLabel.Grouped := True;
  BtnToolLabel.Style := tbsCheck;
  BtnToolLabel.OnClick := BtnToolClick;

  BtnToolExpr := TToolButton.Create(MainToolBar);
  BtnToolExpr.Parent := MainToolBar;
  BtnToolExpr.ImageIndex := IMG_EXPRESSION;
  BtnToolExpr.Hint := 'Insertar Expresión';
  BtnToolExpr.Grouped := True;
  BtnToolExpr.Style := tbsCheck;
  BtnToolExpr.OnClick := BtnToolClick;

  BtnToolShape := TToolButton.Create(MainToolBar);
  BtnToolShape.Parent := MainToolBar;
  BtnToolShape.ImageIndex := IMG_SHAPE;
  BtnToolShape.Hint := 'Insertar Forma (Línea / Rectángulo / Elipse)';
  BtnToolShape.Grouped := True;
  BtnToolShape.Style := tbsCheck;
  BtnToolShape.OnClick := BtnToolClick;

  BtnToolImage := TToolButton.Create(MainToolBar);
  BtnToolImage.Parent := MainToolBar;
  BtnToolImage.ImageIndex := IMG_IMAGE;
  BtnToolImage.Hint := 'Insertar Imagen';
  BtnToolImage.Grouped := True;
  BtnToolImage.Style := tbsCheck;
  BtnToolImage.OnClick := BtnToolClick;

  BtnToolChart := TToolButton.Create(MainToolBar);
  BtnToolChart.Parent := MainToolBar;
  BtnToolChart.ImageIndex := IMG_CHART;
  BtnToolChart.Hint := 'Insertar Gráfico';
  BtnToolChart.Grouped := True;
  BtnToolChart.Style := tbsCheck;
  BtnToolChart.OnClick := BtnToolClick;

  BtnToolBarcode := TToolButton.Create(MainToolBar);
  BtnToolBarcode.Parent := MainToolBar;
  BtnToolBarcode.ImageIndex := IMG_BARCODE;
  BtnToolBarcode.Hint := 'Insertar Código de Barras';
  BtnToolBarcode.Grouped := True;
  BtnToolBarcode.Style := tbsCheck;
  BtnToolBarcode.OnClick := BtnToolClick;

  Sep4 := TToolButton.Create(MainToolBar);
  Sep4.Parent := MainToolBar;
  Sep4.Style := tbsSeparator;
  Sep4.Width := 8;

  ComboScale := TComboBox.Create(MainToolBar);
  ComboScale.Parent := MainToolBar;
  ComboScale.Style := csDropDownList;
  ComboScale.Width := 75;
  ComboScale.Items.Add('25%');
  ComboScale.Items.Add('50%');
  ComboScale.Items.Add('75%');
  ComboScale.Items.Add('100%');
  ComboScale.Items.Add('125%');
  ComboScale.Items.Add('150%');
  ComboScale.Items.Add('200%');
  ComboScale.ItemIndex := 3;
  ComboScale.OnChange := ComboScaleChange;

  Sep5 := TToolButton.Create(MainToolBar);
  Sep5.Parent := MainToolBar;
  Sep5.Style := tbsSeparator;
  Sep5.Width := 8;

  BtnDelete := TToolButton.Create(MainToolBar);
  BtnDelete.Parent := MainToolBar;
  BtnDelete.ImageIndex := IMG_DELETE;
  BtnDelete.Hint := 'Eliminar componentes seleccionados (Supr)';
  BtnDelete.OnClick := BtnDeleteClick;

  BtnCut := TToolButton.Create(MainToolBar);
  BtnCut.Parent := MainToolBar;
  BtnCut.ImageIndex := IMG_CUT;
  BtnCut.Hint := 'Cortar';
  BtnCut.OnClick := BtnCutClick;

  BtnCopy := TToolButton.Create(MainToolBar);
  BtnCopy.Parent := MainToolBar;
  BtnCopy.ImageIndex := IMG_COPY;
  BtnCopy.Hint := 'Copiar';
  BtnCopy.OnClick := BtnCopyClick;

  BtnPaste := TToolButton.Create(MainToolBar);
  BtnPaste.Parent := MainToolBar;
  BtnPaste.ImageIndex := IMG_PASTE;
  BtnPaste.Hint := 'Pegar';
  BtnPaste.OnClick := BtnPasteClick;

  Sep6 := TToolButton.Create(MainToolBar);
  Sep6.Parent := MainToolBar;
  Sep6.Style := tbsSeparator;
  Sep6.Width := 8;

  BtnToFront := TToolButton.Create(MainToolBar);
  BtnToFront.Parent := MainToolBar;
  BtnToFront.ImageIndex := IMG_NAV_UP;
  BtnToFront.Hint := 'Traer al frente';
  BtnToFront.OnClick := BtnToFrontClick;

  BtnToBack := TToolButton.Create(MainToolBar);
  BtnToBack.Parent := MainToolBar;
  BtnToBack.ImageIndex := IMG_NAV_DOWN;
  BtnToBack.Hint := 'Enviar al fondo';
  BtnToBack.OnClick := BtnToBackClick;

  BtnSelectAll := TToolButton.Create(MainToolBar);
  BtnSelectAll.Parent := MainToolBar;
  BtnSelectAll.ImageIndex := IMG_ALIGN_HCENTER;
  BtnSelectAll.Hint := 'Seleccionar todo (Ctrl+A)';
  BtnSelectAll.OnClick := BtnSelectAllClick;

  // 3. StatusBar
  StatusBar := TStatusBar.Create(Self);
  StatusBar.Parent := Self;
  StatusBar.SimplePanel := True;

  // 4. Left Panel (Structure + Inspector)
  PLeft := TPanel.Create(Self);
  PLeft.Parent := Self;
  PLeft.Align := alLeft;
  PLeft.Width := 235;
  PLeft.BevelOuter := bvNone;

  FStructure := TFRpStructureLCL.Create(Self);
  FStructure.Parent := PLeft;
  FStructure.Align := alTop;
  FStructure.Height := 280;

  SplitterStruct := TSplitter.Create(PLeft);
  SplitterStruct.Parent := PLeft;
  SplitterStruct.Align := alTop;
  SplitterStruct.Height := 5;

  FObjInsp := TFRpObjInspLCL.Create(Self);
  FObjInsp.Parent := PLeft;
  FObjInsp.Align := alClient;

  // Connect structure and object inspector
  FStructure.ObjInsp := FObjInsp;

  // 5. Main Splitter
  SplitterMain := TSplitter.Create(Self);
  SplitterMain.Parent := Self;
  SplitterMain.Align := alLeft;
  SplitterMain.Width := 5;

  // 6. Client Area (Canvas Frame)
  PClient := TPanel.Create(Self);
  PClient.Parent := Self;
  PClient.Align := alClient;
  PClient.BevelOuter := bvNone;

  FDesignerFrame := TFRpDesignFrameLCL.Create(Self);
  FDesignerFrame.Parent := PClient;
  FDesignerFrame.Align := alClient;
  FDesignerFrame.ObjInsp := FObjInsp;
  FDesignerFrame.freportstructure := FStructure;
  FDesignerFrame.OnToolChange := DesignerToolChange;

  FObjInsp.DesignFrame := FDesignerFrame;
  FStructure.designframe := FDesignerFrame;

  // 7. Dialogs
  OpenDialog1 := TOpenDialog.Create(Self);
  OpenDialog1.Filter := 'Report Manager Files (*.rep)|*.rep|All Files (*.*)|*.*';

  SaveDialog1 := TSaveDialog.Create(Self);
  SaveDialog1.Filter := 'Report Manager Files (*.rep)|*.rep|All Files (*.*)|*.*';
  SaveDialog1.DefaultExt := 'rep';
end;

procedure TFRpMainFLCL.SetReport(Value: TRpReport);
begin
  if FReport = Value then Exit;
  if FOwnsReport and Assigned(FReport) then
    FreeAndNil(FReport);

  FReport := Value;
  FOwnsReport := False;
  RefreshInterface;
end;

procedure TFRpMainFLCL.SetFileName(const Value: string);
begin
  FFileName := Value;
  if Length(FFileName) > 0 then
    Caption := 'Report Manager Designer - [' + ExtractFileName(FFileName) + ']'
  else
    Caption := 'Report Manager Designer - [Sin título]';
end;

procedure TFRpMainFLCL.OpenReportFile(const AFileName: string);
begin
  if not FileExists(AFileName) then
  begin
    ShowMessage('El archivo no existe: ' + AFileName);
    Exit;
  end;

  if Assigned(FDesignerFrame) then
    FDesignerFrame.Report := nil;
  if Assigned(FStructure) then
    FStructure.Report := nil;

  if FOwnsReport and Assigned(FReport) then
    FreeAndNil(FReport);

  FReport := TRpReport.Create(Self);
  FOwnsReport := True;
  FReport.LoadFromFile(AFileName);
  FileName := AFileName;

  RefreshInterface;
end;

procedure TFRpMainFLCL.SaveReportFile(const AFileName: string);
begin
  if not Assigned(FReport) then Exit;
  FReport.SaveToFile(AFileName);
  FileName := AFileName;
  UpdateStatus;
end;

procedure TFRpMainFLCL.NewReport;
var
  subrep: TRpSubReport;
begin
  if Assigned(FDesignerFrame) then
    FDesignerFrame.Report := nil;
  if Assigned(FStructure) then
    FStructure.Report := nil;

  if FOwnsReport and Assigned(FReport) then
    FreeAndNil(FReport);

  FReport := TRpReport.Create(Self);
  FOwnsReport := True;

  subrep := FReport.AddSubReport;
  subrep.AddPageHeader;
  subrep.AddDetail;
  subrep.AddPageFooter;

  FileName := '';
  RefreshInterface;
end;

procedure TFRpMainFLCL.RefreshInterface;
begin
  if not Assigned(FReport) then Exit;

  if Assigned(FDesignerFrame) then
  begin
    FDesignerFrame.Report := FReport;
    FDesignerFrame.UpdateInterface(True);
    FDesignerFrame.UpdateSelection(False);
  end;

  if Assigned(FStructure) then
  begin
    FStructure.Report := FReport;
    if Assigned(FStructure.browser) then
      FStructure.browser.Report := FReport;
  end;

  UpdateStatus;
end;

procedure TFRpMainFLCL.UpdateStatus;
var
  sInfo: string;
begin
  if not Assigned(FReport) then
  begin
    StatusBar.SimpleText := 'Sin informe cargado';
    Exit;
  end;

  sInfo := Format('Subinformes: %d | Escala: %d%%',
    [FReport.SubReports.Count, Round(FDesignerFrame.Scale * 100)]);
  if Length(FFileName) > 0 then
    sInfo := sInfo + ' | ' + ExtractFileName(FFileName);
  StatusBar.SimpleText := sInfo;
end;

procedure TFRpMainFLCL.EmbedInControl(AParent: TWinControl);
begin
  BorderStyle := bsNone;
  Parent := AParent;
  Align := alClient;
  Visible := True;
end;

procedure TFRpMainFLCL.BtnNewClick(Sender: TObject);
begin
  NewReport;
end;

procedure TFRpMainFLCL.BtnOpenClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
    OpenReportFile(OpenDialog1.FileName);
end;

procedure TFRpMainFLCL.BtnSaveClick(Sender: TObject);
begin
  if Length(FFileName) > 0 then
    SaveReportFile(FFileName)
  else
    BtnSaveAsClick(Sender);
end;

procedure TFRpMainFLCL.BtnSaveAsClick(Sender: TObject);
begin
  if SaveDialog1.Execute then
    SaveReportFile(SaveDialog1.FileName);
end;

procedure TFRpMainFLCL.BtnDataConfigClick(Sender: TObject);
begin
  if not Assigned(FReport) then Exit;
  ShowDataConfig(FReport);
  if Assigned(FStructure) and Assigned(FStructure.browser) then
    FStructure.browser.Report := FReport;
  if Assigned(FDesignerFrame) then
    FDesignerFrame.UpdateSelection(False);
end;

procedure TFRpMainFLCL.BtnPageSetupClick(Sender: TObject);
begin
  if not Assigned(FReport) then Exit;
  if ExecutePageSetup(FReport) then
  begin
    if Assigned(FDesignerFrame) then
    begin
      FDesignerFrame.UpdateInterface(True);
      FDesignerFrame.Refresh;
    end;
    UpdateStatus;
  end;
end;

procedure TFRpMainFLCL.BtnPrintClick(Sender: TObject);
begin
  BtnPreviewClick(Sender);
end;

procedure TFRpMainFLCL.BtnPreviewClick(Sender: TObject);
var
  previewCtrl: TRpPreviewControl;
begin
  if not Assigned(FReport) then Exit;
  try
    previewCtrl := TRpPreviewControl.Create(nil);
    try
      previewCtrl.Report := FReport;
      rplclpreview.ShowPreview(previewCtrl, 'Vista Previa - ' + Caption);
    finally
      previewCtrl.Free;
    end;
  except
    on E: Exception do
      ShowMessage('Error al previsualizar el informe: ' + E.Message);
  end;
end;

procedure TFRpMainFLCL.BtnUndoClick(Sender: TObject);
begin
  // Undo cue integration
end;

procedure TFRpMainFLCL.BtnRedoClick(Sender: TObject);
begin
  // Redo cue integration
end;

procedure TFRpMainFLCL.BtnToolClick(Sender: TObject);
begin
  if Sender = BtnToolArrow then
    FDesignerFrame.ActiveTool := dtArrow
  else if Sender = BtnToolLabel then
    FDesignerFrame.ActiveTool := dtLabel
  else if Sender = BtnToolExpr then
    FDesignerFrame.ActiveTool := dtExpression
  else if Sender = BtnToolShape then
    FDesignerFrame.ActiveTool := dtShape
  else if Sender = BtnToolImage then
    FDesignerFrame.ActiveTool := dtImage
  else if Sender = BtnToolChart then
    FDesignerFrame.ActiveTool := dtChart
  else if Sender = BtnToolBarcode then
    FDesignerFrame.ActiveTool := dtBarcode;
end;

procedure TFRpMainFLCL.DesignerToolChange(Sender: TObject);
begin
  case FDesignerFrame.ActiveTool of
    dtArrow: BtnToolArrow.Down := True;
    dtLabel: BtnToolLabel.Down := True;
    dtExpression: BtnToolExpr.Down := True;
    dtShape: BtnToolShape.Down := True;
    dtImage: BtnToolImage.Down := True;
    dtChart: BtnToolChart.Down := True;
    dtBarcode: BtnToolBarcode.Down := True;
  end;
end;

procedure TFRpMainFLCL.BtnDeleteClick(Sender: TObject);
begin
  FDesignerFrame.DeleteSelection;
end;

procedure TFRpMainFLCL.BtnCutClick(Sender: TObject);
begin
  // Cut selection
end;

procedure TFRpMainFLCL.BtnCopyClick(Sender: TObject);
begin
  // Copy selection
end;

procedure TFRpMainFLCL.BtnPasteClick(Sender: TObject);
begin
  // Paste selection
end;

procedure TFRpMainFLCL.BtnToFrontClick(Sender: TObject);
begin
  FDesignerFrame.BringSelectionToFront;
end;

procedure TFRpMainFLCL.BtnToBackClick(Sender: TObject);
begin
  FDesignerFrame.SendSelectionToBack;
end;

procedure TFRpMainFLCL.BtnSelectAllClick(Sender: TObject);
begin
  FDesignerFrame.SelectAll;
end;

procedure TFRpMainFLCL.ComboScaleChange(Sender: TObject);
var
  s: string;
  val: Integer;
begin
  s := ComboScale.Text;
  s := StringReplace(s, '%', '', [rfReplaceAll]);
  val := StrToIntDef(Trim(s), 100);
  if val > 0 then
  begin
    FDesignerFrame.Scale := val / 100.0;
    UpdateStatus;
  end;
end;

procedure TFRpMainFLCL.MenuViewGridClick(Sender: TObject);
begin
  MenuViewGrid.Checked := not MenuViewGrid.Checked;
  if Assigned(FReport) then
  begin
    FReport.GridVisible := MenuViewGrid.Checked;
    FDesignerFrame.UpdateInterface(False);
  end;
end;

procedure TFRpMainFLCL.MenuViewUnitsClick(Sender: TObject);
begin
  if TMenuItem(Sender).Tag = 0 then
  begin
    rpmunits.defaultunit := rpUnitCms;
    MenuViewUnitsCm.Checked := True;
    MenuViewUnitsInches.Checked := False;
    FDesignerFrame.TopRuler.Metrics := rCms;
  end
  else
  begin
    rpmunits.defaultunit := rpUnitInchess;
    MenuViewUnitsCm.Checked := False;
    MenuViewUnitsInches.Checked := True;
    FDesignerFrame.TopRuler.Metrics := rInchess;
  end;
  FDesignerFrame.UpdateInterface(False);
end;

procedure TFRpMainFLCL.MenuViewScaleClick(Sender: TObject);
begin
  ComboScale.Text := IntToStr(TMenuItem(Sender).Tag) + '%';
  ComboScaleChange(ComboScale);
end;

procedure TFRpMainFLCL.MenuHelpAboutClick(Sender: TObject);
begin
  ShowMessage('Report Manager Designer LCL' + LineEnding +
              'Versión 4.0 (Free Pascal / Lazarus LCL)' + LineEnding +
              'Copyright (c) 1994-2026 Toni Martir' + LineEnding +
              'https://reportman.es');
end;

procedure TFRpMainFLCL.MenuFileExitClick(Sender: TObject);
begin
  Close;
end;

end.
