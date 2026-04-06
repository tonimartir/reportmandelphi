object FRpAISelectionVCL: TFRpAISelectionVCL
  Left = 0
  Top = 0
  Width = 525
  Height = 63
  Margins.Left = 4
  Margins.Top = 4
  Margins.Right = 4
  Margins.Bottom = 4
  TabOrder = 0
  PixelsPerInch = 120
  object PAI: TPanel
    Left = 0
    Top = 0
    Width = 525
    Height = 63
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object GridAI: TGridPanel
      Left = 0
      Top = 0
      Width = 525
      Height = 63
      Align = alClient
      BevelOuter = bvNone
      ColumnCollection = <
        item
          SizeStyle = ssPercent
          Value = 100.000000000000000000
        end
        item
          SizeStyle = ssAuto
          Value = 30.000000000000000000
        end>
      ControlCollection = <
        item
          Column = 0
          Control = PActionHost
          Row = 0
        end
        item
          Column = 1
          Control = PGaugeHost
          Row = 0
        end>
      ParentBackground = False
      RowCollection = <
        item
          SizeStyle = ssPercent
          Value = 100.000000000000000000
        end>
      TabOrder = 0
      object PActionHost: TPanel
        AlignWithMargins = True
        Left = 0
        Top = 0
        Width = 495
        Height = 63
        Margins.Left = 0
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 0
        object GridCombos: TGridPanel
          Left = 0
          Top = 0
          Width = 495
          Height = 63
          Align = alClient
          BevelOuter = bvNone
          ColumnCollection = <
            item
              SizeStyle = ssPercent
              Value = 50.000000000000000000
            end
            item
              SizeStyle = ssPercent
              Value = 50.000000000000000000
            end>
          ControlCollection = <
            item
              Column = 0
              Control = ComboAIProvider
              Row = 0
            end
            item
              Column = 1
              Control = ComboAIMode
              Row = 0
            end>
          ParentBackground = False
          RowCollection = <
            item
              SizeStyle = ssPercent
              Value = 100.000000000000000000
            end>
          TabOrder = 0
      object ComboAIProvider: TComboBox
        AlignWithMargins = True
        Left = 4
        Top = 11
        Width = 241
        Height = 28
        Margins.Left = 4
        Margins.Top = 11
        Margins.Right = 4
        Margins.Bottom = 11
        Align = alClient
        Style = csDropDownList
        ItemIndex = 0
        TabOrder = 0
        Text = 'Standard'
        OnChange = ComboAIProviderChange
        Items.Strings = (
          'Standard'
          'Precision')
      end
      object ComboAIMode: TComboBox
        AlignWithMargins = True
        Left = 253
        Top = 11
        Width = 241
        Height = 28
        Margins.Left = 4
        Margins.Top = 11
        Margins.Right = 4
        Margins.Bottom = 11
        Align = alClient
        Style = csDropDownList
        ItemIndex = 0
        TabOrder = 1
        Text = 'Fast'
        OnChange = ComboAIModeChange
        Items.Strings = (
          'Fast'
          'Reasoning')
      end
        end
        object PInferenceProgress: TPanel
          Left = 0
          Top = 0
          Width = 495
          Height = 63
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 1
          Visible = False
          object BStopInference: TButton
            Left = 4
            Top = 16
            Width = 60
            Height = 30
            Caption = 'Stop'
            TabOrder = 0
            OnClick = BStopInferenceClick
          end
          object LTokensInfo: TLabel
            Left = 74
            Top = 24
            Width = 150
            Height = 15
            Caption = 'Tokens (In/Out): 0 / 0'
          end
          object ProgressBarAI: TProgressBar
            Left = 220
            Top = 22
            Width = 150
            Height = 15
            MarqueeInterval = 30
            TabOrder = 1
          end
        end
      end
      object PGaugeHost: TPanel
        AlignWithMargins = True
        Left = 493
        Top = 0
        Width = 32
        Height = 63
        Margins.Left = 4
        Margins.Top = 0
        Margins.Right = 4
        Margins.Bottom = 0
        Align = alClient
        BevelOuter = bvNone
        ParentShowHint = False
        ShowHint = True
        TabOrder = 2
        object PaintBoxGauge: TPaintBox
          Left = 1
          Top = 16
          Width = 30
          Height = 30
          Hint = 'Credits'
          ParentShowHint = False
          ShowHint = True
          OnPaint = PaintBoxGaugePaint
        end
      end
    end
  end
end
