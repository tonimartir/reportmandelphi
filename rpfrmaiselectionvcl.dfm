object FRpAISelectionVCL: TFRpAISelectionVCL
  Left = 0
  Top = 0
  Width = 420
  Height = 32
  TabOrder = 0
  object PAI: TPanel
    Left = 0
    Top = 0
    Width = 420
    Height = 32
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object LProvider: TLabel
      Left = 4
      Top = 9
      Width = 16
      Height = 13
      Caption = 'AI:'
    end
    object PaintBoxGauge: TPaintBox
      Left = 260
      Top = 4
      Width = 24
      Height = 24
      Hint = 'Credits'
      ShowHint = True
      OnPaint = PaintBoxGaugePaint
    end
    object LCredits: TLabel
      Left = 288
      Top = 9
      Width = 120
      Height = 13
      Hint = 'Credits'
      ShowHint = True
      Caption = 'Guest'
    end
    object ComboAIProvider: TComboBox
      Left = 24
      Top = 5
      Width = 110
      Height = 21
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
      Left = 140
      Top = 5
      Width = 110
      Height = 21
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
end
