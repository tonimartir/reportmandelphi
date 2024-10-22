object FRpPageSetupVCL: TFRpPageSetupVCL
  Left = 245
  Top = 108
  BorderStyle = bsDialog
  Caption = 'Dialog'
  ClientHeight = 599
  ClientWidth = 664
  Color = clBtnFace
  ParentFont = True
  Position = poScreenCenter
  ShowHint = True
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 120
  TextHeight = 20
  object PControl: TPageControl
    Left = 0
    Top = 0
    Width = 664
    Height = 548
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    ActivePage = TabOptions
    Align = alClient
    TabOrder = 0
    object TabPage: TTabSheet
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Page setup'
      DesignSize = (
        656
        513)
      object SColor: TShape
        Left = 200
        Top = 345
        Width = 41
        Height = 41
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        OnMouseDown = SColorMouseDown
      end
      object LLinesperInch: TLabel
        Left = 5
        Top = 315
        Width = 90
        Height = 20
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Lines per inch'
      end
      object GUserDefined: TGroupBox
        Left = 230
        Top = 10
        Width = 420
        Height = 116
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Anchors = [akLeft, akTop, akRight]
        Caption = 'Custom page size (Windows only)'
        TabOrder = 1
        Visible = False
        DesignSize = (
          420
          116)
        object LMetrics7: TLabel
          Left = 366
          Top = 30
          Width = 30
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akTop, akRight]
          Caption = 'inch.'
          ExplicitLeft = 373
        end
        object LMetrics8: TLabel
          Left = 366
          Top = 60
          Width = 30
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akTop, akRight]
          Caption = 'inch.'
          ExplicitLeft = 373
        end
        object LWidth: TLabel
          Left = 15
          Top = 30
          Width = 40
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Width'
        end
        object LHeight: TLabel
          Left = 15
          Top = 60
          Width = 45
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Height'
        end
        object LForceFormName: TLabel
          Left = 15
          Top = 90
          Width = 113
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Force form name'
        end
        object EPageheight: TRpMaskEdit
          Left = 160
          Top = 55
          Width = 190
          Height = 28
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 1
          Text = ''
          EditType = tecurrency
        end
        object EPageWidth: TRpMaskEdit
          Left = 160
          Top = 25
          Width = 190
          Height = 28
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
          Text = ''
          EditType = tecurrency
        end
        object EForceFormName: TRpMaskEdit
          Left = 160
          Top = 85
          Width = 190
          Height = 28
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 2
          Text = ''
        end
      end
      object RPageSize: TRadioGroup
        Left = 5
        Top = 10
        Width = 221
        Height = 116
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Page size'
        Items.Strings = (
          'Default'
          'Custom'
          'User defined')
        TabOrder = 0
        OnClick = RPageSizeClick
      end
      object GPageSize: TGroupBox
        Left = 230
        Top = 15
        Width = 419
        Height = 81
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Anchors = [akLeft, akTop, akRight]
        Caption = 'Custom size'
        TabOrder = 2
        Visible = False
        object ComboPageSize: TComboBox
          Left = 5
          Top = 40
          Width = 336
          Height = 28
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Style = csDropDownList
          TabOrder = 0
        end
      end
      object RPageOrientation: TRadioGroup
        Left = 5
        Top = 130
        Width = 221
        Height = 84
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Page orientation'
        Items.Strings = (
          'Default'
          'Custom')
        TabOrder = 3
        OnClick = RPageOrientationClick
      end
      object RCustomOrientation: TRadioGroup
        Left = 235
        Top = 130
        Width = 415
        Height = 84
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Anchors = [akLeft, akTop, akRight]
        Caption = 'Custom page orientation'
        Items.Strings = (
          'Portrait'
          'Landscape')
        TabOrder = 4
        Visible = False
      end
      object BBackground: TButton
        Left = 5
        Top = 345
        Width = 186
        Height = 41
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Background color'
        TabOrder = 7
        OnClick = BBackgroundClick
      end
      object GPageMargins: TGroupBox
        Left = 5
        Top = 215
        Width = 645
        Height = 86
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Anchors = [akLeft, akTop, akRight]
        Caption = 'Page Margins'
        TabOrder = 5
        DesignSize = (
          645
          86)
        object LLeft: TLabel
          Left = 20
          Top = 20
          Width = 25
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Left'
        end
        object LTop: TLabel
          Left = 20
          Top = 55
          Width = 25
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Top'
        end
        object LMetrics3: TLabel
          Left = 210
          Top = 20
          Width = 30
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'inch.'
        end
        object LMetrics4: TLabel
          Left = 210
          Top = 50
          Width = 30
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'inch.'
        end
        object LMetrics5: TLabel
          Left = 584
          Top = 20
          Width = 30
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akTop, akRight]
          Caption = 'inch.'
          ExplicitLeft = 591
        end
        object LRight: TLabel
          Left = 305
          Top = 20
          Width = 35
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Right'
        end
        object LBottom: TLabel
          Left = 305
          Top = 55
          Width = 50
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Bottom'
        end
        object LMetrics6: TLabel
          Left = 584
          Top = 55
          Width = 30
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akTop, akRight]
          Caption = 'inch.'
          ExplicitLeft = 591
        end
        object ELeftMargin: TRpMaskEdit
          Left = 100
          Top = 15
          Width = 96
          Height = 28
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          TabOrder = 0
          Text = ''
          EditType = tecurrency
        end
        object ETopMargin: TRpMaskEdit
          Left = 100
          Top = 50
          Width = 96
          Height = 28
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          TabOrder = 2
          Text = ''
          EditType = tecurrency
        end
        object ERightMargin: TRpMaskEdit
          Left = 380
          Top = 15
          Width = 190
          Height = 28
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 1
          Text = ''
          EditType = tecurrency
        end
        object EBottomMargin: TRpMaskEdit
          Left = 380
          Top = 50
          Width = 190
          Height = 28
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 3
          Text = ''
          EditType = tecurrency
        end
      end
      object ELinesPerInch: TRpMaskEdit
        Left = 290
        Top = 310
        Width = 150
        Height = 28
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 6
        Text = ''
        EditType = tecurrency
      end
    end
    object TabPrint: TTabSheet
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Print setup'
      ImageIndex = 1
      DesignSize = (
        656
        513)
      object LSelectPrinter: TLabel
        Left = 10
        Top = 115
        Width = 87
        Height = 20
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Select Printer'
      end
      object LCopies: TLabel
        Left = 10
        Top = 265
        Width = 45
        Height = 20
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Copies'
      end
      object LPrinterFonts: TLabel
        Left = 10
        Top = 10
        Width = 220
        Height = 20
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Printer Fonts (Windows GDI Only)'
      end
      object LRLang: TLabel
        Left = 10
        Top = 45
        Width = 111
        Height = 20
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Report language'
      end
      object LPreview: TLabel
        Left = 10
        Top = 75
        Width = 173
        Height = 20
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Preview window and scale'
      end
      object LPaperSource: TLabel
        Left = 10
        Top = 150
        Width = 130
        Height = 20
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Select paper source'
      end
      object LDuplex: TLabel
        Left = 10
        Top = 185
        Width = 95
        Height = 20
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Duplex option'
      end
      object ComboSelPrinter: TComboBox
        Left = 315
        Top = 110
        Width = 335
        Height = 28
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Style = csDropDownList
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 3
      end
      object BConfigure: TButton
        Left = 10
        Top = 220
        Width = 266
        Height = 31
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Configure printers'
        TabOrder = 5
        OnClick = BConfigureClick
      end
      object CheckPrintOnlyIfData: TCheckBox
        Left = 10
        Top = 355
        Width = 261
        Height = 26
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Print only if data available'
        TabOrder = 9
      end
      object CheckTwoPass: TCheckBox
        Left = 10
        Top = 325
        Width = 261
        Height = 26
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Two pass report'
        TabOrder = 8
      end
      object ECopies: TRpMaskEdit
        Left = 190
        Top = 260
        Width = 86
        Height = 28
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        TabOrder = 6
        Text = ''
        EditType = teinteger
      end
      object CheckCollate: TCheckBox
        Left = 10
        Top = 295
        Width = 266
        Height = 26
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Collate copies'
        TabOrder = 7
      end
      object ComboPrinterFonts: TComboBox
        Left = 315
        Top = 5
        Width = 335
        Height = 28
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Style = csDropDownList
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 0
        Items.Strings = (
          'Default'
          'Always use printer fonts'
          'Never use printer fonts'
          'Recalculte report')
      end
      object ComboLanguage: TComboBox
        Left = 315
        Top = 40
        Width = 335
        Height = 28
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Style = csDropDownList
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
      end
      object ComboPreview: TComboBox
        Left = 315
        Top = 75
        Width = 148
        Height = 28
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Style = csDropDownList
        TabOrder = 2
        Items.Strings = (
          'Normal'
          'Maxmized')
      end
      object ComboStyle: TComboBox
        Left = 470
        Top = 75
        Width = 180
        Height = 28
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Style = csDropDownList
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 4
        Items.Strings = (
          'Wide'
          'Normal'
          'Page')
      end
      object CheckDrawerAfter: TCheckBox
        Left = 10
        Top = 415
        Width = 466
        Height = 26
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Open drawer after printing'
        TabOrder = 11
      end
      object CheckDrawerBefore: TCheckBox
        Left = 10
        Top = 385
        Width = 506
        Height = 26
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Open drawer before printing'
        TabOrder = 10
      end
      object CheckPreviewAbout: TCheckBox
        Left = 285
        Top = 290
        Width = 365
        Height = 26
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Anchors = [akLeft, akTop, akRight]
        Caption = 'About box in preview'
        TabOrder = 12
      end
      object CheckMargins: TCheckBox
        Left = 285
        Top = 320
        Width = 366
        Height = 26
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Anchors = [akLeft, akTop, akRight]
        Caption = 'Printable margins in preview'
        TabOrder = 13
      end
      object ComboPaperSource: TComboBox
        Left = 375
        Top = 145
        Width = 275
        Height = 28
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Style = csDropDownList
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 14
        OnClick = ComboPaperSourceClick
      end
      object ComboDuplex: TComboBox
        Left = 315
        Top = 180
        Width = 335
        Height = 28
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Style = csDropDownList
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 15
      end
      object EPaperSource: TRpMaskEdit
        Left = 315
        Top = 145
        Width = 56
        Height = 28
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        TabOrder = 16
        OnChange = EPaperSourceChange
        Text = ''
        EditType = teinteger
      end
      object CheckDefaultCopies: TCheckBox
        Left = 285
        Top = 260
        Width = 296
        Height = 26
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Default printer copies'
        TabOrder = 17
        OnClick = CheckDefaultCopiesClick
      end
    end
    object TabOptions: TTabSheet
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Options'
      ImageIndex = 2
      object Panel2: TPanel
        Left = 0
        Top = 0
        Width = 656
        Height = 177
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Align = alTop
        TabOrder = 0
        DesignSize = (
          656
          177)
        object LPreferedFormat: TLabel
          Left = 6
          Top = 15
          Width = 138
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Prefered save format'
        end
        object ComboFormat: TComboBox
          Left = 226
          Top = 10
          Width = 415
          Height = 28
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Style = csDropDownList
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object GPDF: TGroupBox
          Left = 6
          Top = 46
          Width = 875
          Height = 115
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'PDF Options'
          TabOrder = 1
          DesignSize = (
            875
            115)
          object LabelPDFConformance: TLabel
            Left = 16
            Top = 34
            Width = 119
            Height = 20
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Caption = 'PDF Conformance'
          end
          object LabelCompressed: TLabel
            Left = 16
            Top = 74
            Width = 82
            Height = 20
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Caption = 'Compressed'
          end
          object ComboBoxPDFConformance: TComboBox
            Left = 220
            Top = 26
            Width = 415
            Height = 28
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Style = csDropDownList
            Anchors = [akLeft, akTop, akRight]
            TabOrder = 0
            Items.Strings = (
              'PDF 1.4'
              'PDF A/3')
          end
          object CheckBoxPDFCompressed: TCheckBox
            Left = 220
            Top = 72
            Width = 121
            Height = 21
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            TabOrder = 1
          end
        end
      end
      object Panel3: TPanel
        Left = 0
        Top = 177
        Width = 656
        Height = 336
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Align = alClient
        TabOrder = 1
        object PParentListView: TPanel
          Left = 1
          Top = 25
          Width = 654
          Height = 310
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Align = alClient
          Caption = 'PParentListView'
          TabOrder = 0
          object ListViewEmbedded: TListView
            Left = 1
            Top = 38
            Width = 652
            Height = 271
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            Align = alClient
            Columns = <
              item
                Caption = 'File Name'
                Width = 250
              end
              item
                Caption = 'Mime Type'
                Width = 175
              end
              item
                Alignment = taRightJustify
                Caption = 'Size'
                Width = 125
              end>
            TabOrder = 0
            ViewStyle = vsReport
          end
          object ToolBar1: TToolBar
            Left = 1
            Top = 1
            Width = 652
            Height = 37
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            ButtonHeight = 35
            ButtonWidth = 33
            Caption = 'ToolBar1'
            Images = VirtualImageList1
            TabOrder = 1
            object SpeedButton2: TSpeedButton
              Left = 0
              Top = 0
              Width = 103
              Height = 35
              Margins.Left = 4
              Margins.Top = 4
              Margins.Right = 4
              Margins.Bottom = 4
              Action = AFileNew
              Images = VirtualImageList1
            end
            object SpeedButton1: TSpeedButton
              Left = 103
              Top = 0
              Width = 103
              Height = 35
              Margins.Left = 4
              Margins.Top = 4
              Margins.Right = 4
              Margins.Bottom = 4
              Action = AFileDelete
              Images = VirtualImageList1
            end
          end
        end
        object Panel4: TPanel
          Left = 1
          Top = 1
          Width = 654
          Height = 24
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Align = alTop
          Caption = 'PDF Embedded Files'
          TabOrder = 1
        end
      end
    end
  end
  object Panel1: TPanel
    Left = 0
    Top = 548
    Width = 664
    Height = 51
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alBottom
    TabOrder = 1
    object BOK: TButton
      Left = 10
      Top = 10
      Width = 126
      Height = 31
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'OK'
      TabOrder = 0
      OnClick = BOKClick
    end
    object BCancel: TButton
      Left = 145
      Top = 10
      Width = 121
      Height = 31
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Cancel'
      TabOrder = 1
      OnClick = BCancelClick
    end
  end
  object ColorDialog1: TColorDialog
    Left = 336
    Top = 288
  end
  object FileActions: TActionList
    Images = VirtualImageList1
    Left = 180
    Top = 352
    object AFileNew: TAction
      Caption = 'New'
      ImageIndex = 0
      ImageName = 'Item1'
      OnExecute = AFileNewExecute
    end
    object AFileDelete: TAction
      Caption = 'Delete'
      ImageIndex = 1
      ImageName = 'Item2'
      OnExecute = AFileDeleteExecute
    end
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
      end>
    ImageCollection = ImageCollection1
    Width = 26
    Height = 26
    Left = 158
    Top = 386
  end
  object ImageList1: TImageList
    BkColor = clFuchsia
    Height = 19
    Width = 19
    Left = 232
    Top = 307
    Bitmap = {
      494C010102000900040013001300FF00FF00FF10FFFFFFFFFFFFFFFF424D3600
      00000000000036000000280000004C0000001300000001002000000000009016
      000000000000000000000000000000000000FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000FF00FF00FF00FF00FF000000FF000000FF000000FF000000FF000000FF00
      0000FF000000FF000000FF000000FF000000FF000000FF000000FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF0000000000FFFFFF00FF00FF00FF00FF00000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000FF00FF00FF00FF00FF0000008484
      8400848484008484840084848400848484008484840084848400848484008484
      840084848400FF000000FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF0000000000FFFFFF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000FF00FF00FF00FF00FF000000FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF000000FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF000000
      00000000000000000000FFFFFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF0000000000FFFFFF00FF00FF00FF00FF00FF00FF00000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000FF00FF00FF00FF00FF000000FF00
      FF000000000000000000FF00FF000000000000000000FF00FF00000000000000
      0000FF00FF00FF000000FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00000000000000000000000000FFFFFF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF0000000000FFFFFF00FF00FF00FF00
      FF00FF00FF00FF00FF0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000FF00FF00FF00FF00FF000000FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF000000FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00000000000000000000000000FFFFFF00FF00FF00FF00FF00FF00FF000000
      000000000000FFFFFF00FF00FF00FF00FF00FF00FF00FF00FF00000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000000000000084848400FF00FF00FF000000FF00
      FF000000000000000000FF00FF000000000000000000FF00FF00000000000000
      0000000000000000000000000000FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF0000000000000000000000
      0000FFFFFF00FF00FF000000000000000000FFFFFF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000FF00FF00FF00FF00FF000000FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF000000000000FF000000000000FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF000000000000000000000000000000000000000000FFFF
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000FF00FF00FF00FF00FF000000FF00
      0000FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF00
      00000000000000FF000000000000FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF000000
      00000000000000000000FFFFFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000FF00FF00FF00FF00FF000000FF00FF00FF000000FF000000FF00FF00FF00
      0000FF0000000000000000000000000000000000000000FF0000000000000000
      00000000000000000000FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF000000000000000000000000000000000000000000FFFF
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000FF00FF00FF00FF00FF000000FF00
      0000FF000000FF000000FF000000FF000000FF0000000000000000FF000000FF
      000000FF000000FF000000FF000000FF000000FF000000000000FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF0000000000000000000000
      0000FFFFFF00FF00FF0000000000FFFFFF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF000000000000000000000000000000000000FF0000000000000000
      00000000000000000000FF00FF00FF00FF00FF00FF00FF00FF00FF00FF000000
      0000000000000000000000000000FFFFFF00FF00FF00FF00FF00FF00FF000000
      000000000000FFFFFF00FF00FF00FF00FF00FF00FF00FF00FF00000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF000000000000FF000000000000FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF0000000000000000000000000000000000FFFFFF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF000000000000000000FFFFFF00FF00
      FF00FF00FF00FF00FF0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF000000000000FF000000000000FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00000000000000
      0000FFFFFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF000000000000000000FFFFFF00FF00FF00FF00FF00000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00000000000000000000000000FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00
      FF00FF00FF00FF00FF0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000424D3E000000000000003E000000280000004C0000001300000001000100
      00000000E40000000000000000000000000000000000000000000000FFFFFF00
      FFFFFFFFFC00000000000000FFFFFFFFFC00000000000000FFFFFFFFFC000000
      00000000C003FFFFCC00000000000000C003FF3FFC00000000000000DFFBFE1F
      9C00000000000000D24BFE1F3C00000000000000DFFBFF0E3C00000000000000
      5241FF847C00000000000000DFF1FFC0FC00000000000000C001FFE1FC000000
      00000000D2003FC0FC00000000000000C0003F84FC00000000000000FF803E0E
      3C00000000000000FFF1FC1F1C00000000000000FFF1FC7F8C00000000000000
      FFF1FFFFFC00000000000000FFFFFFFFFC00000000000000FFFFFFFFFC000000
      0000000000000000000000000000000000000000000000000000}
  end
  object ImageCollection1: TImageCollection
    Images = <
      item
        Name = 'Item1'
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
        Name = 'Item2'
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
      end>
    Left = 166
    Top = 305
  end
  object FileOpenDialog1: TFileOpenDialog
    FavoriteLinks = <>
    FileName = '*.xml'
    FileTypes = <
      item
        DisplayName = 'XML File'
        FileMask = '*.XML'
      end
      item
        DisplayName = 'PDF File'
        FileMask = '*.PDF'
      end
      item
        DisplayName = 'Image file'
        FileMask = '*.png;*.jpeg;*.bmp'
      end
      item
        DisplayName = 'Other file'
        FileMask = '*.*'
      end>
    Options = []
    Left = 404
    Top = 296
  end
end
