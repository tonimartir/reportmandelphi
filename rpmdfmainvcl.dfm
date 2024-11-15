object FRpMainFVCL: TFRpMainFVCL
  Left = 810
  Top = 196
  Caption = 'Report Manager Designer'
  ClientHeight = 744
  ClientWidth = 1004
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -24
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = MainMenu1
  ShowHint = True
  OnClose = FormClose
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnResize = FormResize
  OnShow = FormShow
  PixelsPerInch = 120
  TextHeight = 32
  object BStatus: TStatusBar
    Left = 0
    Top = 724
    Width = 1004
    Height = 20
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Panels = <
      item
        Width = 50
      end>
  end
  object ToolBar1: TToolBar
    Left = 0
    Top = 0
    Width = 1004
    Height = 78
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    AutoSize = True
    ButtonHeight = 32
    ButtonWidth = 33
    Caption = 'ToolBar1'
    Color = clBtnFace
    Images = VirtualImageList1
    ParentColor = False
    TabOrder = 1
    object ToolButton1: TToolButton
      Left = 0
      Top = 0
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = ANew
    end
    object ToolButton2: TToolButton
      Left = 33
      Top = 0
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = AOpen
    end
    object ToolButton3: TToolButton
      Left = 66
      Top = 0
      Width = 6
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'ToolButton3'
      ImageIndex = 2
      ImageName = 'Item3'
      Style = tbsSeparator
    end
    object BSave: TToolButton
      Left = 72
      Top = 0
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = ASave
    end
    object ToolButton4: TToolButton
      Left = 105
      Top = 0
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = ADataConfig
    end
    object ToolButton5: TToolButton
      Left = 138
      Top = 0
      Width = 6
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'ToolButton5'
      ImageIndex = 5
      ImageName = 'Item6'
      Style = tbsSeparator
    end
    object ToolButton7: TToolButton
      Left = 144
      Top = 0
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = APrint
    end
    object ToolButton8: TToolButton
      Left = 177
      Top = 0
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = APreview
    end
    object ToolButton9: TToolButton
      Left = 210
      Top = 0
      Width = 14
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'ToolButton9'
      ImageIndex = 7
      ImageName = 'Item8'
      Style = tbsSeparator
    end
    object BArrow: TToolButton
      Left = 224
      Top = 0
      Hint = 'Select objects'
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'BArrow'
      Enabled = False
      Grouped = True
      ImageIndex = 8
      ImageName = 'Item9'
      Style = tbsCheck
    end
    object BLabel: TToolButton
      Left = 257
      Top = 0
      Hint = 'Inserts a static text'
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'BLabel'
      Enabled = False
      Grouped = True
      ImageIndex = 9
      ImageName = 'Item10'
      Style = tbsCheck
    end
    object BExpression: TToolButton
      Left = 290
      Top = 0
      Hint = 'Inserts a expression'
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'BExpression'
      Enabled = False
      Grouped = True
      ImageIndex = 10
      ImageName = 'Item11'
      Style = tbsCheck
    end
    object BShape: TToolButton
      Left = 323
      Top = 0
      Hint = 'Inserts a simple drawing'
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'BShape'
      Enabled = False
      Grouped = True
      ImageIndex = 11
      ImageName = 'Item12'
      Style = tbsCheck
    end
    object BImage: TToolButton
      Left = 356
      Top = 0
      Hint = 'Inserts a image'
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'BImage'
      Enabled = False
      Grouped = True
      ImageIndex = 12
      ImageName = 'Item13'
      Style = tbsCheck
    end
    object BChart: TToolButton
      Left = 389
      Top = 0
      Hint = 'Inserts a chart'
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'BChart'
      Enabled = False
      Grouped = True
      ImageIndex = 13
      ImageName = 'Item14'
      Style = tbsCheck
    end
    object BBarcode: TToolButton
      Left = 422
      Top = 0
      Hint = 'Inserts a barcode'
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'BBarcode'
      Enabled = False
      Grouped = True
      ImageIndex = 31
      ImageName = 'Item32'
      Style = tbsCheck
    end
    object ToolButton10: TToolButton
      Left = 0
      Top = 0
      Width = 14
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'ToolButton10'
      ImageIndex = 14
      ImageName = 'Item15'
      Wrap = True
      Style = tbsSeparator
    end
    object ComboScale: TComboBox
      Left = 0
      Top = 46
      Width = 63
      Height = 40
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Style = csDropDownList
      DropDownCount = 12
      TabOrder = 0
      OnClick = ComboScaleClick
      Items.Strings = (
        '50%'
        '75%'
        '100%'
        '125%'
        '150%'
        '175%'
        '200%'
        '250%'
        '300%'
        '350%'
        '400%')
    end
    object BDelete: TToolButton
      Left = 63
      Top = 46
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = ADelete
    end
    object ToolButton11: TToolButton
      Left = 96
      Top = 46
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = ACut
    end
    object ToolButton12: TToolButton
      Left = 129
      Top = 46
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = ACopy
    end
    object ToolButton13: TToolButton
      Left = 162
      Top = 46
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = APaste
    end
    object ToolButton14: TToolButton
      Left = 195
      Top = 46
      Width = 11
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'ToolButton14'
      ImageIndex = 17
      ImageName = 'Item18'
      Style = tbsSeparator
    end
    object ToolButton15: TToolButton
      Left = 206
      Top = 46
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = ALeft
    end
    object ToolButton16: TToolButton
      Left = 239
      Top = 46
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = ARight
    end
    object ToolButton17: TToolButton
      Left = 272
      Top = 46
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = AUp
    end
    object ToolButton18: TToolButton
      Left = 305
      Top = 46
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = ADown
    end
    object ToolButton19: TToolButton
      Left = 338
      Top = 46
      Width = 13
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'ToolButton19'
      ImageIndex = 25
      ImageName = 'Item26'
      Style = tbsSeparator
    end
    object ToolButton20: TToolButton
      Left = 351
      Top = 46
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = AAlignLeft
    end
    object ToolButton21: TToolButton
      Left = 384
      Top = 46
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = AAlignRight
    end
    object ToolButton22: TToolButton
      Left = 417
      Top = 46
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = AAlignUp
    end
    object ToolButton23: TToolButton
      Left = 450
      Top = 46
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = AAlignDown
    end
    object ToolButton24: TToolButton
      Left = 483
      Top = 46
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = AAlignHorz
    end
    object ToolButton25: TToolButton
      Left = 516
      Top = 46
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Action = AAlignVert
    end
  end
  object mainscrollbox: TPanel
    Left = 0
    Top = 78
    Width = 1004
    Height = 646
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    Visible = False
    object Splitter1: TSplitter
      Left = 198
      Top = 0
      Width = 7
      Height = 646
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Beveled = True
      ResizeStyle = rsUpdate
      OnMoved = Splitter1Moved
      ExplicitHeight = 643
    end
    object leftpanel: TPanel
      Left = 0
      Top = 0
      Width = 198
      Height = 646
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Align = alLeft
      BevelOuter = bvNone
      TabOrder = 0
      object Splitter2: TSplitter
        Left = 0
        Top = 0
        Width = 198
        Height = 8
        Cursor = crVSplit
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Align = alTop
        Beveled = True
        ResizeStyle = rsUpdate
      end
    end
  end
  object iconlist: TImageList
    Height = 19
    Width = 19
    Left = 302
    Top = 309
  end
  object ActionList1: TActionList
    Images = VirtualImageList1
    Left = 352
    Top = 160
    object ANew: TAction
      Category = 'File'
      Caption = 'New'
      Hint = 'Creates a new report'
      ImageIndex = 0
      ImageName = 'Item1'
      OnExecute = ANewExecute
    end
    object AOpen: TAction
      Category = 'File'
      Caption = 'Open'
      Hint = 'Opens an existing report'
      ImageIndex = 1
      ImageName = 'Item2'
      OnExecute = AOpenExecute
    end
    object AExit: TAction
      Category = 'File'
      Caption = 'Exit'
      Hint = 'Closes de application'
      ImageIndex = 2
      ImageName = 'Item3'
      OnExecute = AExitExecute
    end
    object ASave: TAction
      Category = 'File'
      Caption = 'Save'
      Enabled = False
      Hint = 'Saves the current report'
      ImageIndex = 3
      ImageName = 'Item4'
      OnExecute = ASaveExecute
    end
    object ASaveas: TAction
      Category = 'File'
      Caption = 'Save as...'
      Enabled = False
      Hint = 'Saves the report to a new file'
      ImageIndex = 7
      ImageName = 'Item8'
      OnExecute = ASaveasExecute
    end
    object APageSetup: TAction
      Category = 'File'
      Caption = 'Page setup...'
      Enabled = False
      Hint = 'Configures the page for the report'
      ImageIndex = 32
      ImageName = 'Item33'
      OnExecute = APageSetupExecute
    end
    object ANewPageHeader: TAction
      Category = 'Report'
      Caption = 'Page header'
      Enabled = False
      Hint = 'Inserts a page header in the selected subreport'
      OnExecute = ANewPageHeaderExecute
    end
    object ANewPageFooter: TAction
      Category = 'Report'
      Caption = 'Page footer'
      Enabled = False
      Hint = 'Inserts a page footer in the selected subreport'
      OnExecute = ANewPageFooterExecute
    end
    object ANewGroup: TAction
      Category = 'Report'
      Caption = 'Group header and footer'
      Enabled = False
      Hint = 'Insert a group header an footer'
      OnExecute = ANewGroupExecute
    end
    object ANewSubreport: TAction
      Category = 'Report'
      Caption = 'Subreport'
      Enabled = False
      Hint = 'Insert a new subreport'
      OnExecute = ANewSubreportExecute
    end
    object ADeleteSelection: TAction
      Category = 'Report'
      Caption = 'Delete section/subreport'
      Enabled = False
      Hint = 'Deletes the selected subreport or section'
      ImageIndex = 20
      ImageName = 'Item21'
      OnExecute = ADeleteSelectionExecute
    end
    object ANewDetail: TAction
      Category = 'Report'
      Caption = 'Detail'
      Enabled = False
      Hint = 'Inserts a detail section in the selected subreport'
      OnExecute = ANewDetailExecute
    end
    object ADataConfig: TAction
      Category = 'Report'
      Caption = 'Data access configuration'
      Enabled = False
      Hint = 'Modifies data access information'
      ImageIndex = 4
      ImageName = 'Item5'
      OnExecute = ADataConfigExecute
    end
    object AParams: TAction
      Category = 'Report'
      Caption = 'Parameter definition'
      Enabled = False
      Hint = 'Shows parameter definition for the report and data configuration'
      OnExecute = AParamsExecute
    end
    object APrint: TAction
      Category = 'File'
      Caption = 'Print...'
      Enabled = False
      Hint = 'Print the report, you can select pages to print'
      ImageIndex = 5
      ImageName = 'Item6'
      OnExecute = APrintExecute
    end
    object APreview: TAction
      Category = 'File'
      Caption = 'Print Preview'
      Enabled = False
      Hint = 'Preview the report in the screen'
      ImageIndex = 6
      ImageName = 'Item7'
      OnExecute = APreviewExecute
    end
    object AGridOptions: TAction
      Category = 'Display'
      Caption = 'Grid'
      Enabled = False
      Hint = 'Grid options for this report'
      OnExecute = AGridOptionsExecute
    end
    object ACut: TAction
      Category = 'Edit'
      Caption = 'Cut'
      Enabled = False
      Hint = 'Cut selected object'
      ImageIndex = 14
      ImageName = 'Item15'
      OnExecute = ACutExecute
    end
    object ACopy: TAction
      Category = 'Edit'
      Caption = 'Copy'
      Enabled = False
      Hint = 'Copy selected object to clipboard'
      ImageIndex = 15
      ImageName = 'Item16'
      OnExecute = ACopyExecute
    end
    object APaste: TAction
      Category = 'Edit'
      Caption = 'Paste'
      Enabled = False
      Hint = 'Paste from clipboard'
      ImageIndex = 16
      ImageName = 'Item17'
      OnExecute = APasteExecute
    end
    object AAbout: TAction
      Category = 'Help'
      Caption = 'About Report Manager'
      Hint = 'Shows information about Report Manger'
      OnExecute = AAboutExecute
    end
    object ADocumentation: TAction
      Category = 'Help'
      Caption = 'Documentation'
      Hint = 'Display Report Manager Designer Documentation'
      OnExecute = ADocumentationExecute
    end
    object APrintSetup: TAction
      Category = 'File'
      Caption = 'Printer setup...'
      Hint = 'Displays printer setup dialog'
      ImageIndex = 17
      ImageName = 'Item18'
      OnExecute = APrintSetupExecute
    end
    object AUnitCms: TAction
      Category = 'Preferences'
      Caption = '&Cms'
      Hint = 'Change measurement units to cms'
      OnExecute = AUnitCmsExecute
    end
    object AUnitsinchess: TAction
      Category = 'Preferences'
      Caption = 'Inches'
      Hint = 'Changes measurement units to inchess'
      OnExecute = AUnitsinchessExecute
    end
    object AUserParams: TAction
      Category = 'Report'
      Caption = 'Parameter values'
      Hint = 'Shows user parameter window'
      ImageIndex = 18
      ImageName = 'Item19'
      OnExecute = AUserParamsExecute
    end
    object ADriverQT: TAction
      Category = 'Preferences'
      Caption = 'Qt driver (CLX)'
      Checked = True
      Hint = 'Activates the Qt cross platform graphics and printing driver'
      OnExecute = ADriverQTExecute
    end
    object ADriverGDI: TAction
      Category = 'Preferences'
      Caption = 'GDI Driver (VCL)'
      Hint = 'Activates the GDI32 direct rendering driver (VCL), Windows only'
      OnExecute = ADriverGDIExecute
    end
    object ASystemPrintDialog: TAction
      Category = 'Preferences'
      Caption = 'Qt System print dialog'
      Hint = 'Shows the system print dialog, or a custom print dialog'
      OnExecute = ASystemPrintDialogExecute
    end
    object AkylixPrintBug: TAction
      Caption = 'Kylix Print Bugfix'
      Checked = True
      Hint = 'Uses kylix print bugfix (use metaprint to print metafiles)'
      Visible = False
      OnExecute = AkylixPrintBugExecute
    end
    object AHide: TAction
      Category = 'Edit'
      Caption = 'Hide'
      Enabled = False
      Hint = 'Hide selected objects'
      OnExecute = AHideExecute
    end
    object AShowAll: TAction
      Category = 'Edit'
      Caption = 'Show all'
      Hint = 'Shows all the hiden components'
      OnExecute = AShowAllExecute
    end
    object ASelectAll: TAction
      Category = 'Edit'
      Caption = 'All'
      Hint = 'Selects all components of the report'
      OnExecute = ASelectAllExecute
    end
    object ASelectAllText: TAction
      Category = 'Edit'
      Caption = 'All Text'
      Hint = 'Selects all text components of the report'
      OnExecute = ASelectAllTextExecute
    end
    object ALeft: TAction
      Category = 'Edit'
      Caption = 'Left'
      Enabled = False
      Hint = 'Moves the selection to the left'
      ImageIndex = 21
      ImageName = 'Item22'
      OnExecute = ALeftExecute
    end
    object ARight: TAction
      Category = 'Edit'
      Caption = 'Right'
      Enabled = False
      Hint = 'Moves the selection to the left'
      ImageIndex = 22
      ImageName = 'Item23'
      OnExecute = ARightExecute
    end
    object AUp: TAction
      Category = 'Edit'
      Caption = 'Up'
      Enabled = False
      Hint = 'Moves the selection up'
      ImageIndex = 23
      ImageName = 'Item24'
      OnExecute = AUpExecute
    end
    object ADown: TAction
      Category = 'Edit'
      Caption = 'Down'
      Enabled = False
      Hint = 'Moves the selection down'
      ImageIndex = 24
      ImageName = 'Item25'
      OnExecute = ADownExecute
    end
    object AAlignLeft: TAction
      Category = 'Edit'
      Caption = 'Left'
      Enabled = False
      Hint = 'Aligns selection to the left'
      ImageIndex = 25
      ImageName = 'Item26'
      OnExecute = AAlignLeftExecute
    end
    object AAlignRight: TAction
      Category = 'Edit'
      Caption = 'Right'
      Enabled = False
      Hint = 'Aligns selection to the right'
      ImageIndex = 26
      ImageName = 'Item27'
      OnExecute = AAlignRightExecute
    end
    object AAlignUp: TAction
      Category = 'Edit'
      Caption = 'Up'
      Enabled = False
      Hint = 'Aligns selection up'
      ImageIndex = 27
      ImageName = 'Item28'
      OnExecute = AAlignUpExecute
    end
    object AAlignDown: TAction
      Category = 'Edit'
      Caption = 'Down'
      Enabled = False
      Hint = 'Aligns selection down'
      ImageIndex = 28
      ImageName = 'Item29'
      OnExecute = AAlignDownExecute
    end
    object AAlignHorz: TAction
      Category = 'Edit'
      Caption = 'Horizontal space'
      Enabled = False
      Hint = 'Aligns selection distributing horzontal space'
      ImageIndex = 29
      ImageName = 'Item30'
      OnExecute = AAlignHorzExecute
    end
    object AAlignVert: TAction
      Category = 'Edit'
      Caption = 'Vertical space'
      Enabled = False
      Hint = 'Aligns selection distributing vertical space'
      ImageIndex = 30
      ImageName = 'Item31'
      OnExecute = AAlignVertExecute
    end
    object AStatusBar: TAction
      Category = 'Preferences'
      Caption = 'Status bar'
      Checked = True
      Hint = 'Shows or hides the status bar'
      OnExecute = AStatusBarExecute
    end
    object ADriverPDF: TAction
      Category = 'Preferences'
      Caption = 'Native driver'
      Hint = 'Activates the Native driver, no graphics dependent'
      OnExecute = ADriverPDFExecute
    end
    object ASysInfo: TAction
      Category = 'Help'
      Caption = 'System information'
      Hint = 'Shows system and printer information'
      OnExecute = ASysInfoExecute
    end
    object AAlign1_6: TAction
      Category = 'Edit'
      Caption = 'Align height 1/6'
      Hint = 
        'Aligns all sections height to 1/6 inchess for dot matrix compati' +
        'bility'
      OnExecute = AAlign1_6Execute
    end
    object ALibraries: TAction
      Category = 'Library'
      Caption = 'Configure'
      Hint = 'Open report libraries dialog'
      OnExecute = ALibrariesExecute
    end
    object ADelete: TAction
      Category = 'Edit'
      Caption = 'Delete'
      Enabled = False
      Hint = 'Delete the selected object'
      ImageIndex = 20
      ImageName = 'Item21'
      OnExecute = ADeleteExecute
    end
    object AOpenFrom: TAction
      Category = 'Library'
      Caption = 'Open from...'
      Hint = 'Open a report from a library'
      OnExecute = AOpenFromExecute
    end
    object ASaveTo: TAction
      Category = 'Library'
      Caption = 'Save to...'
      Hint = 'Save the report to a report library'
      OnExecute = ASaveToExecute
    end
    object APrintDialog: TAction
      Category = 'Preferences'
      Caption = 'APrintDialog'
      OnExecute = APrintDialogExecute
    end
  end
  object Lastusedfiles: TRpLastUsedStrings
    HistoryCount = 7
    SaveIndex = 0
    Left = 280
    Top = 80
  end
  object MainMenu1: TMainMenu
    Images = VirtualImageList1
    Left = 336
    Top = 228
    object File1: TMenuItem
      Caption = 'File'
      object New1: TMenuItem
        Action = ANew
      end
      object Open1: TMenuItem
        Action = AOpen
      end
      object N6: TMenuItem
        Caption = '-'
      end
      object MLibraries: TMenuItem
        Caption = 'Libraries'
        Hint = 'Open report libraries dialog'
        object Configure1: TMenuItem
          Action = ALibraries
        end
        object Openfrom1: TMenuItem
          Action = AOpenFrom
        end
        object Saveto1: TMenuItem
          Action = ASaveTo
        end
      end
      object N1: TMenuItem
        Caption = '-'
        Visible = False
      end
      object Save1: TMenuItem
        Action = ASave
      end
      object Saveas1: TMenuItem
        Action = ASaveas
      end
      object N2: TMenuItem
        Caption = '-'
      end
      object Pagesetup1: TMenuItem
        Action = APageSetup
      end
      object PrintPreview1: TMenuItem
        Action = APreview
      end
      object Print1: TMenuItem
        Action = APrint
      end
      object Printersetup1: TMenuItem
        Action = APrintSetup
      end
      object N3: TMenuItem
        Caption = '-'
      end
      object Exit1: TMenuItem
        Action = AExit
      end
    end
    object MReport: TMenuItem
      Caption = 'Report'
      Enabled = False
      object MAdd: TMenuItem
        Caption = 'Add'
        ImageIndex = 19
        ImageName = 'Item20'
        object Newpageheader1: TMenuItem
          Action = ANewPageHeader
        end
        object Pagefooter1: TMenuItem
          Action = ANewPageFooter
        end
        object Groupheaderandfooter1: TMenuItem
          Action = ANewGroup
        end
        object Subreport1: TMenuItem
          Action = ANewSubreport
        end
        object Detail1: TMenuItem
          Action = ANewDetail
        end
      end
      object Dataaccessconfiguration1: TMenuItem
        Action = ADataConfig
      end
      object Parameters1: TMenuItem
        Action = AParams
      end
      object Userparameters1: TMenuItem
        Action = AUserParams
      end
      object ADeleteSelection1: TMenuItem
        Action = ADeleteSelection
      end
    end
    object MEdit: TMenuItem
      Caption = 'Edit'
      Enabled = False
      object Delete1: TMenuItem
        Action = ADelete
      end
      object Cut1: TMenuItem
        Action = ACut
      end
      object Copy1: TMenuItem
        Action = ACopy
      end
      object APaste1: TMenuItem
        Action = APaste
      end
      object N4: TMenuItem
        Caption = '-'
      end
      object MSelect: TMenuItem
        Caption = 'Select'
        object ASelectAll1: TMenuItem
          Action = ASelectAll
        end
        object ASelectAllText1: TMenuItem
          Action = ASelectAllText
        end
      end
      object MMove: TMenuItem
        Caption = 'Move'
        object Left1: TMenuItem
          Action = ALeft
        end
        object Right1: TMenuItem
          Action = ARight
        end
        object Up1: TMenuItem
          Action = AUp
        end
        object Down1: TMenuItem
          Action = ADown
        end
      end
      object MAlign: TMenuItem
        Caption = 'Align'
        object Left2: TMenuItem
          Action = AAlignLeft
        end
        object Right2: TMenuItem
          Action = AAlignRight
        end
        object Up2: TMenuItem
          Action = AAlignUp
        end
        object Down2: TMenuItem
          Action = AAlignDown
        end
        object Horizontalspace1: TMenuItem
          Action = AAlignHorz
        end
        object Verticalspace1: TMenuItem
          Action = AAlignVert
        end
      end
      object N5: TMenuItem
        Caption = '-'
      end
      object Hide1: TMenuItem
        Action = AHide
      end
      object Showall1: TMenuItem
        Action = AShowAll
      end
      object AboutReportManager1: TMenuItem
        Caption = '-'
      end
      object Malign1_6: TMenuItem
        Action = AAlign1_6
      end
    end
    object MDisplay: TMenuItem
      Caption = 'Display'
      Enabled = False
      object Grid1: TMenuItem
        Action = AGridOptions
      end
    end
    object MPreferences: TMenuItem
      Caption = 'Preferences'
      object MMeasurement: TMenuItem
        Caption = 'Measurement'
        object Cms1: TMenuItem
          Action = AUnitCms
        end
        object Inchess1: TMenuItem
          Action = AUnitsinchess
        end
      end
      object MDriverSelect: TMenuItem
        Caption = 'Driver'
        object MQtDriver: TMenuItem
          Action = ADriverQT
          Visible = False
        end
        object MGDIDriver: TMenuItem
          Action = ADriverGDI
        end
        object Nativedriver1: TMenuItem
          Action = ADriverPDF
        end
      end
      object MSystemPrint: TMenuItem
        Action = ASystemPrintDialog
      end
      object MKylixPrintBug: TMenuItem
        Action = AkylixPrintBug
      end
      object Statusbar1: TMenuItem
        Action = AStatusBar
      end
      object MAppFont: TMenuItem
        Caption = 'Application Font'
        Visible = False
        OnClick = MAppFontClick
      end
      object MObjFont: TMenuItem
        Caption = 'Object inspector Font'
        OnClick = MObjFontClick
      end
      object MTypeInfo: TMenuItem
        Caption = 'Data type information'
        OnClick = MTypeInfoClick
      end
      object MAsync: TMenuItem
        Caption = 'Asynchronous execution'
        OnClick = MAsyncClick
      end
      object APrintDialog1: TMenuItem
        Action = APrintDialog
      end
      object menutheme: TMenuItem
        Caption = 'Theme'
      end
    end
    object MHelp: TMenuItem
      Caption = 'Help'
      object MDoc: TMenuItem
        Action = ADocumentation
      end
      object MSysInfo: TMenuItem
        Action = ASysInfo
      end
      object MAbout: TMenuItem
        Action = AAbout
      end
    end
  end
  object OpenDialog1: TOpenDialog
    DefaultExt = 'rep'
    Left = 245
    Top = 149
  end
  object SaveDialog1: TSaveDialog
    DefaultExt = 'rep'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Left = 597
    Top = 151
  end
  object RpAlias1: TRpAlias
    List = <>
    Connections = <>
    Left = 136
    Top = 142
  end
  object FontDialog1: TFontDialog
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    Left = 480
    Top = 121
  end
  object VirtualImageList1: TVirtualImageList
    Images = <
      item
        CollectionIndex = 0
        CollectionName = 'Item1'
        Name = 'Item1'
      end
      item
        CollectionIndex = 1
        CollectionName = 'Item2'
        Name = 'Item2'
      end
      item
        CollectionIndex = 2
        CollectionName = 'Item3'
        Name = 'Item3'
      end
      item
        CollectionIndex = 3
        CollectionName = 'Item4'
        Name = 'Item4'
      end
      item
        CollectionIndex = 4
        CollectionName = 'Item5'
        Name = 'Item5'
      end
      item
        CollectionIndex = 5
        CollectionName = 'Item6'
        Name = 'Item6'
      end
      item
        CollectionIndex = 6
        CollectionName = 'Item7'
        Name = 'Item7'
      end
      item
        CollectionIndex = 7
        CollectionName = 'Item8'
        Name = 'Item8'
      end
      item
        CollectionIndex = 8
        CollectionName = 'Item9'
        Name = 'Item9'
      end
      item
        CollectionIndex = 9
        CollectionName = 'Item10'
        Name = 'Item10'
      end
      item
        CollectionIndex = 10
        CollectionName = 'Item11'
        Name = 'Item11'
      end
      item
        CollectionIndex = 11
        CollectionName = 'Item12'
        Name = 'Item12'
      end
      item
        CollectionIndex = 12
        CollectionName = 'Item13'
        Name = 'Item13'
      end
      item
        CollectionIndex = 13
        CollectionName = 'Item14'
        Name = 'Item14'
      end
      item
        CollectionIndex = 14
        CollectionName = 'Item15'
        Name = 'Item15'
      end
      item
        CollectionIndex = 15
        CollectionName = 'Item16'
        Name = 'Item16'
      end
      item
        CollectionIndex = 16
        CollectionName = 'Item17'
        Name = 'Item17'
      end
      item
        CollectionIndex = 17
        CollectionName = 'Item18'
        Name = 'Item18'
      end
      item
        CollectionIndex = 18
        CollectionName = 'Item19'
        Name = 'Item19'
      end
      item
        CollectionIndex = 19
        CollectionName = 'Item20'
        Name = 'Item20'
      end
      item
        CollectionIndex = 20
        CollectionName = 'Item21'
        Name = 'Item21'
      end
      item
        CollectionIndex = 21
        CollectionName = 'Item22'
        Name = 'Item22'
      end
      item
        CollectionIndex = 22
        CollectionName = 'Item23'
        Name = 'Item23'
      end
      item
        CollectionIndex = 23
        CollectionName = 'Item24'
        Name = 'Item24'
      end
      item
        CollectionIndex = 24
        CollectionName = 'Item25'
        Name = 'Item25'
      end
      item
        CollectionIndex = 25
        CollectionName = 'Item26'
        Name = 'Item26'
      end
      item
        CollectionIndex = 26
        CollectionName = 'Item27'
        Name = 'Item27'
      end
      item
        CollectionIndex = 27
        CollectionName = 'Item28'
        Name = 'Item28'
      end
      item
        CollectionIndex = 28
        CollectionName = 'Item29'
        Name = 'Item29'
      end
      item
        CollectionIndex = 29
        CollectionName = 'Item30'
        Name = 'Item30'
      end
      item
        CollectionIndex = 30
        CollectionName = 'Item31'
        Name = 'Item31'
      end
      item
        CollectionIndex = 31
        CollectionName = 'Item32'
        Name = 'Item32'
      end
      item
        CollectionIndex = 32
        CollectionName = 'Item33'
        Name = 'Item33'
      end>
    ImageCollection = ImageCollection1
    Width = 26
    Height = 26
    Left = 523
    Top = 276
  end
  object ImageCollection1: TImageCollection
    Images = <
      item
        Name = 'Item1'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000494944415478DA63FCCFF09F815A8071E818C60812C20380EA194932
              0C08B02B6664C46B20C98681E4C0341603C972192E2F936418862B470D1B358C
              02C3089A0405040DA3040C5EC300843170EE57955E470000000049454E44AE42
              6082}
          end>
      end
      item
        Name = 'Item2'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC0000007B4944415478DADDD44B0EC020080540DEBD5D7A6F2B561A53110CED
              4A364653874F1351A8D05F813330F0E73DEA3D8431864640F6E3F9A736A55215
              F3DAF05A7EB0566ECFD37606B54AF4C26E48406D45CDB289910949C5A1CA604E
              6D6EDD9C59CE3E92D2F207C42175665168C2788D422AB63B6CEDFC9027C88B0B
              F0CD79EE7BC730570000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item3'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC0000007B4944415478DAE594D10980300C0593715CA31D47C7719DCEE138F1
              05E29F9AD446107C50520A398E40CA424259E103C67A0D063DECC256D4458CC9
              4C7282C7730CD6502B080D1D550D46606A36E16C6A380A6B065260AAD92CD628
              0F61AF997D77663F312B179BDA6D566E56BECBAC387F471846C1B8B08CA4C276
              58688CEE01196BED0000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item4'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000C94944415478DACD92BD11C2300C85A58E32EEF00AE9921158833219
              813118212DEBB8CC0AA6734A3A211D8823774EEC8470A0E645FE79FAEEC54840
              B055E157CC503E5714DFC7A8197956CB073CAFED78F10651458340811E9A6336
              84010A530004DE3430EAB1C48DC9F46C965984487B531AA05E087F4196CACC33
              99CD214B3E07FFBC9C22BBF2E43D9328D15C9FCC4C27E6D025C9746277EEA0B6
              3538EF5EDA1C9B65992999BBB891916875A896FD4DC9C4CE9065BD33351415A3
              F6D44EE6F5BE3F69F669FDAFD91D1A0FE0EEA6C533DD0000000049454E44AE42
              6082}
          end>
      end
      item
        Name = 'Item5'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000CA4944415478DAB594C11285200845E1BB75A9DF6D60618838EA9B9E
              9B2683C3F5826181025F2DFC1B2C27AC2F211644C0A10AC5E2112CC63E208400
              893EC87BA44A39E7617F80EDA859C23C08AF94EE231FC358818632A81DD50025
              7EEA9906CA73065CC2B4671238036EC1DC763BC023653549196C813C3E4B9874
              AA505DA4FA03D0511E14B475D3260AB057E08D9003B3C6FBB03B2557457C634C
              97DB9C3DC9155A9E71D980755D6698F6AA4BFB05A6CD6F4E4CD5BD30DED4576E
              3A6772F411F8C200FA99FBF4E7780155F8DCEECADA40250000000049454E44AE
              426082}
          end>
      end
      item
        Name = 'Item6'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000A34944415478DACD93410E8530084499A5C7D06BBAF69A7A0C973835
              A9A916526ACCCF674353869781A65051F92AF0331852B911EC47139640BAB336
              F0B85364E45313865168B9CBF725C8855D42C751CA182071D8AA820955CDBACF
              D00AD6B3AB2A97B0C8EB3D77967B6E306BA15E349D455D99BBB2609E33C842D1
              CCD342F57C07147DB13195B28D793C3B2E98FB9A6FC7349DF53C82356205EB75
              18FA016FE37F610720FDABEEC6FD9BAC0000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item7'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000BF4944415478DAB594010EC2200C457F8FB023E02DF4FED15BE8113C
              02FEC2984C082D0936591A3AFAFB563A24226295C97231516718F7895B6CB4B9
              14B304CF626F2E3634BEBC378BCE90599FEC22ABBD6CE214FB379992007706AE
              92857596FA7443B24CF4647AC844A287F1622CA02738243B4E91EBA8F19D4CD1
              7A0026599340B288E010EB90A57663A7CA71DA83CF0D5364DFBE5582A9671768
              2F95707ACEDA7F97879204CF63E29AB35E1FEB0225D77D6BD47624FF5C00EBEF
              B355F601F0D1C4EE9DB7422D0000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item8'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000784944415478DABD944B0EC0200844E1DE2EBDB7950509E2075AA1B3
              220E3EC74FC4060DA2842930EC65AF71DB78F0D91B9279269CC673B6A957F302
              64DA2DAC568052C6E6E98CD4D63FC34293ADFC10D8F434383A9BD44CA2095AD2
              7327B3F41AB64AC6E9AE61F218FE87C90BB1B485593F87A5BC2FE8560F40B09D
              EED31F2A2A0000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item9'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000694944415478DAC5D3DB0A0021080450E7FF3FBAB52088C5CD1992D6
              A7E8723231346B56158830F4690F5F4309E6610024708B8DB100A6980252180B
              D218034A5806CAD80E949FB9C61BBC57B39909DB73D477629BF83BB3E5C01116
              6E24C07FB0A89647587A5925F600D58388EE371B0E350000000049454E44AE42
              6082}
          end>
      end
      item
        Name = 'Item10'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000844944415478DAD5D4CB0E80200C4451FADD6549BF1B6581A9652610
              626260E9E37AA846A9A9A6AF969C199376DA2D554DC58A6CC5B2E66A66AF63F7
              F57BB1289BE968CCAB9AC687998EC6FACD5DE2E34C07635185B68D74301655E8
              214837C4D01B642BEA861853ADE85E31362B368661A63E3653CD744F2C7EA0AB
              321F3CF4AFF16BEC02D64F87EE26F776750000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item11'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC0000006D4944415478DAE592E10A80300884BDE76E3FF5B98D461323623617
              05F96737E13E4F362829CD2A7C1B56969226B2300CC6CCB1E9403D55D574BD93
              F66140D9CD7C826E40D38FC29AD19B7DEFD80F26F369AEF58D6429984804F006
              ACB7E6F003A43FADB43D07CB60B3EA27B015114FC3EE15B832C7000000004945
              4E44AE426082}
          end>
      end
      item
        Name = 'Item12'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000AF4944415478DAADD34B0E85200C40D176DD65D8AEBB0F2A105E453E
              01274683872B222A28DC3A7005C3382C8EC3632C50501101220216C623CCAA62
              1722C2AC6E8895AA82CDEA8658A9AAD7194C136C616D95C7AC2E3D18672BE734
              F127E6AB5AD0EE37902DA671194308AF2755B98B591D3374CB7AD00CB42FEBCB
              0068E11790CE24FA2E5BC11418EB1ABAB5DA2EAB987BB5A3B2D9B8656CBEAE79
              D30EBFE62254B127B1B3CF36A03FECC67115FB01092099F75CEEA6F100000000
              49454E44AE426082}
          end>
      end
      item
        Name = 'Item13'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000884944415478DAADD4410E80200C04C0EED7CAB3F4EAB3E8D7501A31
              48C080ED1EA05C26AB4690289157A0988308E08D8148873F3BD598054A5FCD44
              44AB07665BB30C31073DE5791AEC358B8AB19E44A2CEA67716EFC79C86F66B3D
              C8FE3515CAA9B165A820257F9A518BF4B0E526230CB4F03B6D70C446A8096B51
              17EC090A06974B0DFE97A3534EBE1393FEC1A410910000000049454E44AE4260
              82}
          end>
      end
      item
        Name = 'Item14'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000AA4944415478DAED93D112C5100C44B3DFCDA37CB71B3424ADDB4E5B
              8FCD8C3116278B40A64CAB027B1844120DAF6105547A0B534DE32C51875547E2
              0940DFD0B4BE1257AE2B4C41314662E6294CA664AE39B36EDD29141642A0C4C9
              659FC11A40C6D2F81FAC8831C47CED6C1B9FC1AC3377E14F60E32EFCF2C7CE98
              993ED81B18DC6B02A3C62CCC16EEE435B524DAD7D218C9E8A01D60B5CE52A23B
              61FFB183DDA2EC8EE760AB6229EC073967E6EE3843DF460000000049454E44AE
              426082}
          end>
      end
      item
        Name = 'Item15'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC0000006D4944415478DA63FCCFF09F815A8071681AC6089406CA33E2E20F23
              C34034C8006436598621BB8690AB88360CC6A6D83062C28A0497D50015B40259
              D540952D947AB3E63FC81088A130EF623714A761E89A6186225B409461D8340E
              5EC390BD4E7698118A41926293144055C300119B80EEE20B2859000000004945
              4E44AE426082}
          end>
      end
      item
        Name = 'Item16'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC0000007E4944415478DAE58F410EC0200804D977EBD17F53358DAD610D6AEC
              A97BC1800E2354544E059FC0508E24798E2D584E3F0496802EACF46A9D001A58
              B369E7401FAA24B8307301318393E931E0D0EC49A0B0D2ABF5059C36EBBF1FE9
              97B7CCCCB211CC33EB8C6E4B0AE3BB37CC869725EAB299073B66264EA6612BF9
              09EC0204998EEEB7B60FEB0000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item17'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000A54944415478DACD945B1280200800E1DCF429E7AE406DF019364D13
              1F998ACB9A15EEB0C35B819FC050A64C9C79E886D58B159046B083E9C1152620
              22E9CA858139823224DF13C579C9E333A9061A98D2BA4976EB19A805C730B82A
              CE6256B432E36BAB77ADCBAC5C4013C745B37810A17D76B8A5130D6B6623988C
              6B6B802EB36C125F93B26F0D1F9935962DCC675618555B9D7E4E025C361B26C2
              E6FAA5B860ABF15FD801AC26A7EE2DADA9B50000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item18'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000B74944415478DAC5944B0E83300C443DB768B7B926DD724DBA2CB730
              E30AA789089F04502D2407277E1EC506A8A8D41AC4929044BE14A00D66697C46
              AE1F1680E172D8B2E28A19E8CD93C1CF1694794541CFFD2E56CEFC93FE932B8A
              F9B729BBF4CEFED2CDD5228B06349837A100B3777653BA83FEB5053BA90CD2AB
              55F0AD5A659E37C3A03A1012B81C1868F0C6F8C16C4EE4786B751E0DC414E4CA
              105A6E4C0AB04A659BB0339A22CE472305A67F825D2D49CEA59FD304885D98F3
              9B123B310000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item19'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000A94944415478DAADD34112802008055039B72EEDDCA44E91C5FFE434
              B16A925E82289A34FD15C23051810BEDB52C63866CE48B7C477BFEF53C610362
              0841477EA94DC96298835A828B5A301C62C7A2EB49DA14A233B60285AD70985C
              65318CF6F459E66A58A98FF884853FB2324944438AB14AA6BD28EF1DE831C518
              6418387DBEB38C4B44C3FD8E1DA00B0279ECBC42ECDA240EDDB179BB7D96827B
              3837DD61B0C9C170F283F97168773CEB94EEB32F37DA0000000049454E44AE42
              6082}
          end>
      end
      item
        Name = 'Item20'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000804944415478DACD91410EC0200804D977EB91BE9B5AAB561B424D30
              A99C362A93412024B4AAF02B0C574BA9D40B3F4C72D800D68F56E6CBB0F148D0
              60208B6ADF56CB0196126A5B9F150D8F996269FD5935732D809925C480674C48
              D356F27B349799F55659806D76E749D83233E6636A9F3106FA844D91DAE71BB0
              15B52FEC04077973EEF44332900000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item21'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000734944415478DAD594E10AC0200884F3FD1FFA5641309A775A1B83FC
              67E897DE518682F255D819306B690D003D918D4EAD0B1BC1A0ECD2C79A11504D
              4F35BB4347633B53124803E629233D4337BD0969ED2F9331CD14D085A9D596DC
              CC68C45CDD8231205D33F3A4D206A49AA74B0FF982DEC605CC3079EE93AD1430
              0000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item22'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC0000003D4944415478DA63FCCFF09F815A8071D4B0216218235029502D23C5
              86810C02D1141B06338862C3900D1A5C2EA37A98211B4835C388B270D4B08135
              0C006D403AEEDDECE4FB0000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item23'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC0000003B4944415478DA63FCCFF09F815A8071D4B0416E18235009500D23D5
              0C03D1C41848B461C418489261840C1C1897512DCCA8169BA48051C306D83000
              A9403AEEAC3029350000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item24'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC0000003A4944415478DA63FCCFF09F815A8071D4B0916618235019501D23C5
              86810C82B1091988D7306483883110A761D80C2264E0108FCD51C386886100B3
              D831EE78CBA5480000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item25'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC0000003E4944415478DA63FCCFF09F815A8071D4B051C348348C1124850300
              F53092EC326C06E23288286F221B88CF20A2C30C6420218388368C58306AD870
              320C0017AB31EE71DE916B0000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item26'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000744944415478DA63FCCFF09F815A80F13F1010AD98911168F57F46BC
              865DBF7E9EA041EBD66D63A8A9A919350C6A586B6B2B41C34080A061404C52DA
              C0EF32AAA633BA1946824DA0040D370CC4C4080FA00029310D360CAB41E418C6
              802336C1860FA8CB08851929091A6F6C82E387043078132D006ACE8EF5E9EA38
              200000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item27'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC0000006F4944415478DA63FCCFF09F815A8091AA86013149A6012D67C46B58
              4B4B0B5106555757837430A21AC0F81F6601DCB0A0202F8286696A1A6218866C
              2059868134E3F5E680B90C6F980101511100D38D536AF0265A7C86E18A35B20D
              232541136518B1313D6A1834759390A0A99ACE0071A958E44719CBC000000000
              49454E44AE426082}
          end>
      end
      item
        Name = 'Item28'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000714944415478DA63FCCFF09F010E50380C0CADADAD0C353535206146
              98182303E37F643E32604437ECFAF5F370EEBA75DB500C031984A494916CC360
              2E42A7C9761955BD39480D2326A649318CA0ABD10D03D9880CC8360C391D2103
              F25C860F8C1A366A186EC3702668520DC39BA0A10000247809FD826EB3DF0000
              000049454E44AE426082}
          end>
      end
      item
        Name = 'Item29'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC0000006B4944415478DA63FCCFF09F0106181918111C240054C3C840046044
              37ACA5A505454175753558826CC38282BCE0629A9A86A3868D1A86CF30621234
              4986114AD0241B862F08B01A06B6112530C8300C4DFF7F94F0185E86C10CC146
              93E532E43405731D4DBC892DA6614C0082B197EE203480E50000000049454E44
              AE426082}
          end>
      end
      item
        Name = 'Item30'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000954944415478DADD94510E80200886E1DCFA28D7E9B16BF4E8712899
              6EA16C96B6B6E205F70B9FE014646068AC12111198759C68C0A834C94B6A9510
              E3267E5956F0DECB5EA359304CAE149581C3B07365C53F029B6EF35F30E75CF3
              54A660758C092322756A0A0C2128ED322CAD7B66DDA1DDE6D17E9F06FC619835
              0D6EC19A8FFE769B14480D38B3B27C681756E788664EDA41DB0116F84F08CF5D
              DF110000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item31'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000804944415478DAED94B10E80200C44AFFFCDCAEF30FA1B8E7C4E2D46
              899AE8B509D1C55BE8501EE58E200054A1622B04D26B8F8EFDAD961D16055D81
              1D1605DC83474F36CC3335B14D3967A494C00E5A61B5CE8FB052A68F60ED1A4C
              2E18024FC3351983FC019C612001382CED9E8AB230ADC16BC3FB30AFA714D67E
              034ADAB4009D44A4F8CBCB9A4E0000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item32'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000384944415478DAED8CC109004008C39AFD87F654101CC0D7D17EA2A5
              8450E82A948C4446409773177BB4FAF9F7A6A9C032CB2CB3EC2BD9551E43468A
              FD3F06B93E0000000049454E44AE426082}
          end>
      end
      item
        Name = 'Item33'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000A94944415478DAAD92DB1680200804DDFFFF68134C435AD12E3C6449
              8E7300E494D35F0106836C2FA29CC336ACC4DC00A04085351349CEAC2C5C60F2
              ADAB0156983E600E41D17695740336587F3F8103CC83006E089798C0D2CD2832
              FC6CE66B18C0F6CD5813A8596454ADEAA57E4486D160DDF426D7DE051C607E60
              23137AD90CD680F721E5F50CCD3CCCCE14036E9B79235BABDEA8ACA867667406
              CF7F96B0B40A53D310F6367E851DC42AD1EE1875CDB00000000049454E44AE42
              6082}
          end>
      end>
    Left = 566
    Top = 202
  end
end
