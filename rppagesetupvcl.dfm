object FRpPageSetupVCL: TFRpPageSetupVCL
  Left = 245
  Top = 108
  BorderStyle = bsDialog
  Caption = 'Dialog'
  ClientHeight = 589
  ClientWidth = 671
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
    Width = 671
    Height = 538
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
        663
        503)
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
        Width = 113
        Height = 25
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Lines per inch'
      end
      object GUserDefined: TGroupBox
        Left = 230
        Top = 10
        Width = 427
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
          427
          116)
        object LMetrics7: TLabel
          Left = 373
          Top = 30
          Width = 38
          Height = 25
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akTop, akRight]
          Caption = 'inch.'
          ExplicitLeft = 371
        end
        object LMetrics8: TLabel
          Left = 373
          Top = 60
          Width = 38
          Height = 25
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akTop, akRight]
          Caption = 'inch.'
          ExplicitLeft = 371
        end
        object LWidth: TLabel
          Left = 15
          Top = 30
          Width = 50
          Height = 25
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Width'
        end
        object LHeight: TLabel
          Left = 15
          Top = 60
          Width = 56
          Height = 25
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Height'
        end
        object LForceFormName: TLabel
          Left = 15
          Top = 90
          Width = 141
          Height = 25
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Force form name'
        end
        object EPageheight: TRpMaskEdit
          Left = 160
          Top = 55
          Width = 197
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
          Width = 197
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
          Width = 197
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
        Width = 426
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
        Width = 422
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
        Width = 652
        Height = 86
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Anchors = [akLeft, akTop, akRight]
        Caption = 'Page Margins'
        TabOrder = 5
        DesignSize = (
          652
          86)
        object LLeft: TLabel
          Left = 20
          Top = 20
          Width = 31
          Height = 25
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Left'
        end
        object LTop: TLabel
          Left = 20
          Top = 55
          Width = 31
          Height = 25
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Top'
        end
        object LMetrics3: TLabel
          Left = 210
          Top = 20
          Width = 38
          Height = 25
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'inch.'
        end
        object LMetrics4: TLabel
          Left = 210
          Top = 50
          Width = 38
          Height = 25
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'inch.'
        end
        object LMetrics5: TLabel
          Left = 591
          Top = 20
          Width = 37
          Height = 25
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akTop, akRight]
          Caption = 'inch.'
          ExplicitLeft = 589
        end
        object LRight: TLabel
          Left = 305
          Top = 20
          Width = 44
          Height = 25
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Right'
        end
        object LBottom: TLabel
          Left = 305
          Top = 55
          Width = 63
          Height = 25
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Bottom'
        end
        object LMetrics6: TLabel
          Left = 591
          Top = 55
          Width = 37
          Height = 25
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akTop, akRight]
          Caption = 'inch.'
          ExplicitLeft = 589
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
          Width = 197
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
          Width = 197
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
        Width = 157
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
        663
        503)
      object LSelectPrinter: TLabel
        Left = 10
        Top = 115
        Width = 109
        Height = 25
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Select Printer'
      end
      object LCopies: TLabel
        Left = 10
        Top = 265
        Width = 56
        Height = 25
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Copies'
      end
      object LPrinterFonts: TLabel
        Left = 10
        Top = 10
        Width = 275
        Height = 25
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Printer Fonts (Windows GDI Only)'
      end
      object LRLang: TLabel
        Left = 10
        Top = 45
        Width = 139
        Height = 25
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Report language'
      end
      object LPreview: TLabel
        Left = 10
        Top = 75
        Width = 216
        Height = 25
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Preview window and scale'
      end
      object LPaperSource: TLabel
        Left = 10
        Top = 150
        Width = 163
        Height = 25
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Select paper source'
      end
      object LDuplex: TLabel
        Left = 10
        Top = 185
        Width = 119
        Height = 25
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Duplex option'
      end
      object ComboSelPrinter: TComboBox
        Left = 315
        Top = 110
        Width = 342
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
        Width = 342
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
        Width = 342
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
        Width = 187
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
        Width = 372
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
        Width = 373
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
        Width = 282
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
        Width = 342
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
        Width = 663
        Height = 57
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Align = alTop
        TabOrder = 0
        DesignSize = (
          663
          57)
        object LPreferedFormat: TLabel
          Left = 6
          Top = 15
          Width = 173
          Height = 25
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Prefered save format'
        end
        object ComboFormat: TComboBox
          Left = 226
          Top = 10
          Width = 422
          Height = 28
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Style = csDropDownList
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
      end
      object Panel3: TPanel
        Left = 0
        Top = 57
        Width = 663
        Height = 446
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Align = alClient
        TabOrder = 1
        ExplicitLeft = 80
        ExplicitTop = 150
        ExplicitWidth = 231
        ExplicitHeight = 51
        object ToolBar1: TToolBar
          Left = 1
          Top = 1
          Width = 661
          Height = 37
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          ButtonHeight = 28
          ButtonWidth = 29
          Caption = 'ToolBar1'
          TabOrder = 0
          ExplicitWidth = 827
        end
        object ListView1: TListView
          Left = 1
          Top = 38
          Width = 661
          Height = 407
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Align = alClient
          Columns = <>
          TabOrder = 1
          ExplicitLeft = 200
          ExplicitTop = 130
          ExplicitWidth = 221
          ExplicitHeight = 131
        end
      end
    end
  end
  object Panel1: TPanel
    Left = 0
    Top = 538
    Width = 671
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
end
