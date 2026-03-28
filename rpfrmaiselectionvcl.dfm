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
          Value = 50.000000000000000000
        end
        item
          SizeStyle = ssPercent
          Value = 50.000000000000000000
        end
        item
          SizeStyle = ssAuto
          Value = 30.000000000000000000
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
        end
        item
          Column = 2
          Control = PaintBoxGauge
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
      object PaintBoxGauge: TPaintBox
        AlignWithMargins = True
        Left = 493
        Top = 10
        Width = 30
        Height = 30
        Hint = 'Credits'
        Margins.Left = 4
        Margins.Top = 10
        Margins.Right = 4
        Margins.Bottom = 10
        Align = alClient
        ParentShowHint = False
        ShowHint = True
        OnPaint = PaintBoxGaugePaint
      end
    end
    object ProgressBarAI: TProgressBar
      Left = 5
      Top = 20
      Width = 20
      Height = 20
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      MarqueeInterval = 30
      TabOrder = 2
      Visible = False
    end
  end
end
