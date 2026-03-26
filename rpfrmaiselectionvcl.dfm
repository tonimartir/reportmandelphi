object FRpAISelectionVCL: TFRpAISelectionVCL
  Left = 0
  Top = 0
  Width = 320
  Height = 60
  TabOrder = 0
  object PAI: TPanel
    Left = 0
    Top = 0
    Width = 320
    Height = 60
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object PaintBoxGauge: TPaintBox
      Left = 270
      Top = 10
      Width = 40
      Height = 40
      OnPaint = PaintBoxGaugePaint
    end
    object ComboAIMode: TComboBox
      Left = 10
      Top = 20
      Width = 120
      Height = 21
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 0
      Text = 'AI Speed'
      OnChange = ComboAIModeChange
      Items.Strings = (
        'AI Speed'
        'AI Quality'
        'AI Off')
    end
    object LCredits: TLabel
      Left = 140
      Top = 24
      Width = 120
      Height = 13
      AutoSize = False
      Caption = 'Credits'
      Alignment = taRightJustify
    end
  end
end
