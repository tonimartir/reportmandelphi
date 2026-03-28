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
    object LProvider: TLabel
      Left = 30
      Top = 23
      Width = 17
      Height = 20
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'AI:'
    end
    object PaintBoxGauge: TPaintBox
      Left = 350
      Top = 16
      Width = 30
      Height = 30
      Hint = 'Credits'
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      ParentShowHint = False
      ShowHint = True
      OnPaint = PaintBoxGaugePaint
    end
    object LCredits: TLabel
      Left = 385
      Top = 23
      Width = 37
      Height = 20
      Hint = 'Credits'
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Guest'
      ParentShowHint = False
      ShowHint = True
      Visible = False
    end
    object ComboAIProvider: TComboBox
      Left = 55
      Top = 18
      Width = 138
      Height = 28
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
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
      Left = 200
      Top = 18
      Width = 138
      Height = 28
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 1
      Text = 'Fast'
      OnChange = ComboAIModeChange
      Items.Strings = (
        'Fast'
        'Reasoning')
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
