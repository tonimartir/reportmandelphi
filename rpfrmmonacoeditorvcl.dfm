object FRpMonacoEditorVCL: TFRpMonacoEditorVCL
  Left = 0
  Top = 0
  Width = 750
  Height = 500
  Margins.Left = 4
  Margins.Top = 4
  Margins.Right = 4
  Margins.Bottom = 4
  TabOrder = 0
  PixelsPerInch = 120
  object PTop: TPanel
    Left = 0
    Top = 0
    Width = 750
    Height = 50
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object ComboSchema: TComboBox
      Left = 8
      Top = 13
      Width = 150
      Height = 28
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Style = csDropDownList
      TabOrder = 0
    end
    object PLoginControl: TPanel
      Left = 168
      Top = 5
      Width = 250
      Height = 40
      BevelOuter = bvNone
      TabOrder = 1
    end
  end
  object Edge: TEdgeBrowser
    Left = 0
    Top = 50
    Width = 750
    Height = 450
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alClient
    TabOrder = 1
    OnCreateWebViewCompleted = EdgeCreateWebViewCompleted
  end
end
