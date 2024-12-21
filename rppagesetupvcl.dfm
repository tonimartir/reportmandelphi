object FRpPageSetupVCL: TFRpPageSetupVCL
  Left = 245
  Top = 108
  BorderStyle = bsDialog
  Caption = 'Dialog'
  ClientHeight = 551
  ClientWidth = 781
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -15
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  ShowHint = True
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 120
  TextHeight = 20
  object PControl: TPageControl
    Left = 0
    Top = 0
    Width = 781
    Height = 500
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    ActivePage = TabPage
    Align = alClient
    TabOrder = 0
    object TabPage: TTabSheet
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Page setup'
      DesignSize = (
        773
        465)
      object SColor: TShape
        Left = 200
        Top = 353
        Width = 41
        Height = 41
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        OnMouseDown = SColorMouseDown
      end
      object LLinesperInch: TLabel
        Left = 6
        Top = 325
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
        Width = 537
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
          537
          116)
        object LMetrics7: TLabel
          Left = 483
          Top = 30
          Width = 30
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akTop, akRight]
          Caption = 'inch.'
        end
        object LMetrics8: TLabel
          Left = 483
          Top = 60
          Width = 30
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akTop, akRight]
          Caption = 'inch.'
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
          Left = 216
          Top = 55
          Width = 251
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
          Left = 216
          Top = 25
          Width = 251
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
          Left = 216
          Top = 85
          Width = 251
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
      object GPageSize: TGroupBox
        Left = 230
        Top = 15
        Width = 536
        Height = 81
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Anchors = [akLeft, akTop, akRight]
        Caption = 'Custom size'
        TabOrder = 2
        Visible = False
        DesignSize = (
          536
          81)
        object ComboPageSize: TComboBox
          Left = 5
          Top = 40
          Width = 508
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
        Width = 532
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
        Top = 353
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
        Left = 6
        Top = 215
        Width = 761
        Height = 99
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Anchors = [akLeft, akTop, akRight]
        Caption = 'Page Margins'
        TabOrder = 5
        DesignSize = (
          761
          99)
        object LLeft: TLabel
          Left = 12
          Top = 28
          Width = 25
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Left'
        end
        object LTop: TLabel
          Left = 12
          Top = 63
          Width = 25
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Top'
        end
        object LMetrics3: TLabel
          Left = 202
          Top = 28
          Width = 30
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'inch.'
        end
        object LMetrics4: TLabel
          Left = 202
          Top = 58
          Width = 30
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'inch.'
        end
        object LMetrics5: TLabel
          Left = 692
          Top = 28
          Width = 30
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akTop, akRight]
          Caption = 'inch.'
        end
        object LRight: TLabel
          Left = 297
          Top = 28
          Width = 35
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Right'
        end
        object LBottom: TLabel
          Left = 297
          Top = 63
          Width = 50
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Caption = 'Bottom'
        end
        object LMetrics6: TLabel
          Left = 692
          Top = 63
          Width = 30
          Height = 20
          Margins.Left = 4
          Margins.Top = 4
          Margins.Right = 4
          Margins.Bottom = 4
          Anchors = [akTop, akRight]
          Caption = 'inch.'
        end
        object ELeftMargin: TRpMaskEdit
          Left = 92
          Top = 23
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
          Left = 92
          Top = 58
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
          Left = 372
          Top = 23
          Width = 306
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
          Left = 372
          Top = 58
          Width = 306
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
        Left = 249
        Top = 322
        Width = 267
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
        773
        465)
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
        Width = 452
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
        Width = 452
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
        Width = 452
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
        Width = 297
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
        Width = 482
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
        Width = 483
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
        Width = 392
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
        Width = 452
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
        Width = 773
        Height = 178
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Align = alTop
        TabOrder = 0
        DesignSize = (
          773
          178)
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
          Width = 532
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
            Top = 73
            Width = 121
            Height = 20
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
        Top = 178
        Width = 773
        Height = 287
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Align = alClient
        TabOrder = 1
        object PParentListView: TPanel
          Left = 1
          Top = 25
          Width = 771
          Height = 261
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
            Width = 769
            Height = 222
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
              end
              item
                Caption = 'Relationship'
                Width = 100
              end
              item
                Caption = 'Description'
                Width = 200
              end
              item
                Caption = 'Creation Date'
                Width = 100
              end
              item
                Caption = 'Modification Date'
                Width = 100
              end>
            TabOrder = 0
            ViewStyle = vsReport
          end
          object ToolBar1: TToolBar
            Left = 1
            Top = 1
            Width = 769
            Height = 37
            Margins.Left = 4
            Margins.Top = 4
            Margins.Right = 4
            Margins.Bottom = 4
            ButtonHeight = 35
            ButtonWidth = 35
            Caption = 'ToolBar1'
            Images = VirtualImageList1
            TabOrder = 1
            object bnew: TSpeedButton
              Left = 0
              Top = 0
              Width = 104
              Height = 35
              Margins.Left = 4
              Margins.Top = 4
              Margins.Right = 4
              Margins.Bottom = 4
              Action = AFileNew
              Images = VirtualImageList1
            end
            object bdelete: TSpeedButton
              Left = 104
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
            object bmodify: TSpeedButton
              Left = 207
              Top = 0
              Width = 104
              Height = 35
              Margins.Left = 4
              Margins.Top = 4
              Margins.Right = 4
              Margins.Bottom = 4
              Action = AFileModify
              Images = VirtualImageList1
            end
          end
        end
        object Panel4: TPanel
          Left = 1
          Top = 1
          Width = 771
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
    object TabMetadata: TTabSheet
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Metadata'
      ImageIndex = 3
      DesignSize = (
        773
        465)
      object LabelDocAuthor: TLabel
        Left = 20
        Top = 16
        Width = 45
        Height = 20
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Caption = 'Author'
      end
      object labelDocTitle: TLabel
        Left = 20
        Top = 57
        Width = 29
        Height = 20
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Title'
      end
      object labeldocSubject: TLabel
        Left = 20
        Top = 96
        Width = 49
        Height = 20
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Subject'
      end
      object LabelDocKeywords: TLabel
        Left = 20
        Top = 136
        Width = 64
        Height = 20
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Keywords'
      end
      object labelDocCreator: TLabel
        Left = 20
        Top = 176
        Width = 49
        Height = 20
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Creator'
      end
      object LabelDocProducer: TLabel
        Left = 20
        Top = 216
        Width = 59
        Height = 20
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Producer'
      end
      object labelCreationDate: TLabel
        Left = 20
        Top = 257
        Width = 92
        Height = 20
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Creation Date'
      end
      object labelModifyDate: TLabel
        Left = 20
        Top = 296
        Width = 83
        Height = 20
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Caption = 'Modify Date'
      end
      object LabelXmpContent: TLabel
        Left = 20
        Top = 334
        Width = 98
        Height = 20
        Margins.Left = 6
        Margins.Top = 6
        Margins.Right = 6
        Margins.Bottom = 6
        Caption = 'XMP Metadata'
      end
      object textDocAuthor: TEdit
        Left = 216
        Top = 12
        Width = 542
        Height = 28
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 0
      end
      object textDocTitle: TEdit
        Left = 216
        Top = 53
        Width = 542
        Height = 28
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
      end
      object textDocSubject: TEdit
        Left = 216
        Top = 94
        Width = 542
        Height = 28
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 2
      end
      object textDocKeywords: TEdit
        Left = 216
        Top = 133
        Width = 542
        Height = 28
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 3
      end
      object textDocCreator: TEdit
        Left = 216
        Top = 173
        Width = 542
        Height = 28
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 4
      end
      object textDocProducer: TEdit
        Left = 216
        Top = 213
        Width = 542
        Height = 28
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 5
      end
      object textDocCreationDate: TEdit
        Left = 216
        Top = 253
        Width = 542
        Height = 28
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 6
      end
      object textDocModDate: TEdit
        Left = 216
        Top = 294
        Width = 542
        Height = 28
        Margins.Left = 5
        Margins.Top = 5
        Margins.Right = 5
        Margins.Bottom = 5
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 7
      end
      object TextXMPContent: TMemo
        Left = 216
        Top = 331
        Width = 543
        Height = 118
        Margins.Left = 4
        Margins.Top = 4
        Margins.Right = 4
        Margins.Bottom = 4
        Anchors = [akLeft, akTop, akRight, akBottom]
        Lines.Strings = (
          'TextXMPContent')
        ScrollBars = ssBoth
        TabOrder = 8
        WordWrap = False
      end
    end
  end
  object Panel1: TPanel
    Left = 0
    Top = 500
    Width = 781
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
    Left = 412
    Top = 368
  end
  object FileActions: TActionList
    Images = VirtualImageList1
    Left = 128
    Top = 347
    object AFileNew: TAction
      Caption = 'New'
      ImageIndex = 0
      ImageName = 'addprops'
      OnExecute = AFileNewExecute
    end
    object AFileDelete: TAction
      Caption = 'Delete'
      ImageIndex = 1
      ImageName = 'delete'
      OnExecute = AFileDeleteExecute
    end
    object AFileModify: TAction
      Caption = 'Modify'
      ImageIndex = 2
      ImageName = 'tables'
      OnExecute = AFileModifyExecute
    end
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
  object VirtualImageList1: TVirtualImageList
    Images = <
      item
        CollectionIndex = 0
        CollectionName = 'addprops'
        Name = 'addprops'
      end
      item
        CollectionIndex = 1
        CollectionName = 'delete'
        Name = 'delete'
      end
      item
        CollectionIndex = 2
        CollectionName = 'tables'
        Name = 'tables'
      end>
    ImageCollection = ImageCollection1
    Width = 26
    Height = 26
    Left = 271
    Top = 298
  end
  object ImageCollection1: TImageCollection
    Images = <
      item
        Name = 'addprops'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000017352474200AECE1CE90000000467414D410000B18F0BFC61050000
              00097048597300000EC400000EC401952B0E1B0000008E49444154384FDD915B
              0E80200C04C18B8B2747564AD84278FA639C44298F9D14359FC5CAB8829711A8
              FC21E31AAC23F6640D66AFA97BC1AC4E5A5AF28DE64138D6D915B155D7645DA5
              46203DA09C07A8EC75C684084EC624E50BD98CCEE2CB3464D5DFC4E127D0A9B5
              2243CB739D81E84CE6CC5E670D68F77D674AE6DC25751FE7CEF01EC8A4986470
              E7BF62CC0DD7BB223A5B5D538D0000000049454E44AE426082}
          end>
      end
      item
        Name = 'delete'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000017352474200AECE1CE90000000467414D410000B18F0BFC61050000
              00097048597300000EC400000EC401952B0E1B0000007D49444154384FE590DB
              0E80300843C1FFFF67B588C4B8029A98ECC193905D2CA553FEC98A02C7B1A4D5
              9AE0AC42D87D0FC20C451AB2FB126678DD0F2CBE32D45751B5EDAB24192C2125
              A6270CCDF0DB93D2BEEA9961E481CC003E5DC23B105B91C6EC9E260B11F4E449
              E9AFA99E596133583A06748F845F3265E8544436696166B859B4DDBF00000000
              49454E44AE426082}
          end>
      end
      item
        Name = 'tables'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000013000000130806000000725036
              CC000000017352474200AECE1CE90000000467414D410000B18F0BFC61050000
              00097048597300000EC400000EC401952B0E1B0000009649444154384FE59151
              1280200844A98B87272756B130B51CFBABE75888B8AD449F456C46567BCF20A2
              3A18993762B4E8F0CC8A89DA22662E049D18B647671BE7533FA6658B657A318E
              2439D15C4C1E3BC535CF03FD381342B0E8C495256777C049CF15A87E008AACB0
              8A332D57C0298F3973140B30E50CD76CE12A467B867EA5554C3A0A31E6762FAE
              306FFA7C10B360905AEC1710ED917E49A29C4E43250000000049454E44AE4260
              82}
          end>
      end>
    Left = 192
    Top = 298
  end
  object ImageList1: TImageList
    Height = 19
    Width = 19
    Left = 352
    Top = 337
    Bitmap = {
      494C010103000800040013001300FFFFFFFFFF10FFFFFFFFFFFFFFFF424D3600
      00000000000036000000280000004C0000001300000001002000000000009016
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000FF006C00FF005600FF005600FF005600FF005600FF00
      5600FF005600FF005600FF005600FF005600FF005600FF006C00000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000FFFFFF000000000000000000000000000000
      0000FF005E00FF004B00FF004B00FF004B00FF004B00FF004B00FF004B00FF00
      4B00FF004B00FF004B00FF004B00FF005E000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000FF0056008080
      8000808080008080800080808000808080008080800080808000808080008080
      800080808000FF00560000000000000000000000000000000000000000000000
      00000000000000000000000000000000000000000000FFFFFF00000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000FF004B0080808000808080008080
      800080808000808080008080800080808000808080008080800080808000FF00
      4B00000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000FF005600FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFF
      FF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FF005600000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000FFFFFF00000000000000000000000000000000000000
      00000000000000000000FFFFFF00000000000000000000000000000000000000
      0000FF004B00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFF
      FF00FFFFFF0000000000FFFFFF00FF004B000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000FF005600FFFF
      FF000000000000000000FFFFFF000000000000000000FFFFFF00000000000000
      0000FFFFFF00FF00560000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000FFFFFF000000
      00000000000000000000000000000000000000000000FFFFFF00000000000000
      000000000000000000000000000000000000FF004B00FFFFFF00000000000000
      0000FFFFFF000000000000000000FFFFFF00000000000000000000000000FF00
      4B00000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000FF005600FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFF
      FF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FF005600000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000FFFFFF000000000000000000000000000000
      000000000000FFFFFF0000000000000000000000000000000000000000000000
      0000FF004B00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFF
      FF00FFFFFF000000000000000000220022000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000FF005600FFFF
      FF000000000000000000FFFFFF000000000000000000FFFFFF00000000000000
      0000000000001A001A006C006C00000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000FFFFFF00000000000000000000000000FFFFFF0000000000000000000000
      000000000000000000000000000000000000FF004B00FFFFFF00000000000000
      0000FFFFFF000000000000000000FFFFFF00000000000000000000FFFF009569
      95002B002B000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000FF005600FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFF
      FF00FFFFFF00FFFFFF00FFFFFF00FFFFFF000000000000FF0000560056000000
      0000000000000000000000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000000000000000000000FFFF
      FF00000000000000000000000000000000000000000000000000000000000000
      0000FF004B00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFFFF00FFFF
      FF00FFFFFF000000000000FFFF00FFFFFF002200220000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000FF005600FF00
      0000FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF00
      00000000000000FF000056005600000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000FFFFFF00000000000000000000000000000000000000
      000000000000000000000000000000000000FF004B00FF000000FF000000FF00
      0000FF000000FF000000FF000000FF000000FF000000FF0000000000000000FF
      FF00956995002B002B0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000FF005600FFFFFF00FF000000FF000000FFFFFF00FF00
      0000FF0000000000000000000000000000000000000000FF00001A001A005600
      5600560056006C006C0000000000000000000000000000000000000000000000
      000000000000000000000000000000000000000000000000000000000000FFFF
      FF00000000000000000000000000000000000000000000000000000000000000
      0000FF004B00FFFFFF00FF000000FF000000FFFFFF00FF000000FF000000FFFF
      FF00FF000000FF0000000000000000FFFF00FFFFFF0022002200000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000FF006C00FF00
      5600FF005600FF005600FF005600FF005600FF0056001A001A0000FF000000FF
      000000FF000000FF000000FF000000FF000000FF000056005600000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000FFFFFF000000000000000000FFFFFF000000000000000000000000000000
      000000000000000000000000000000000000FF005E00FF004B00FF004B00FF00
      4B00FF004B00FF004B00FF004B00FF004B00FF004B00FF004B00FF004B000A00
      0A0000FFFF00956995002B002B00000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000006C006C0056005600560056001A001A0000FF00001A001A005600
      5600560056006C006C0000000000000000000000000000000000000000000000
      0000000000000000000000000000FFFFFF000000000000000000000000000000
      000000000000FFFFFF0000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00000000000000000000000000002B002B0026D9FF0080808000220022000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00005600560000FF000056005600000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000FFFFFF000000
      0000000000000000000000000000000000000000000000000000FFFFFF000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000220022000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000005600560000FF0000560056000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000FFFFFF000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000FFFFFF000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000002B002B0000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      00006C006C00560056006C006C00000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000002B002B002B002B00000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000000000000000000000000000000000000000000000000000000000000000
      0000424D3E000000000000003E000000280000004C0000001300000001000100
      00000000E40000000000000000000000000000000000000000000000FFFFFF00
      FFFFFFFFFFFFFF8000000000FFFFFFFFFFFFFF8000000000FFFFFFFFFFFFFF80
      00000000C003FFFFCF000F8000000000C003FF3FFF000F8000000000C003FE1F
      9F000F8000000000C003FE1F3F000F8000000000C003FF0E3F000F8000000000
      C001FF847F00078000000000C001FFC0FF00078000000000C001FFE1FF000380
      00000000C0003FC0FF00038000000000C0003F84FF00018000000000FF803E0E
      3FFFE18000000000FFF1FC1F1FFFF38000000000FFF1FC7F8FFFF78000000000
      FFF1FFFFFFFFF98000000000FFFFFFFFFFFFFF8000000000FFFFFFFFFFFFFF80
      0000000000000000000000000000000000000000000000000000}
  end
end
