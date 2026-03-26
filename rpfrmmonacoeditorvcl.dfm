object FRpMonacoEditorVCL: TFRpMonacoEditorVCL
  Left = 0
  Top = 0
  Width = 600
  Height = 400
  TabOrder = 0
  object PTop: TPanel
    Left = 0
    Top = 0
    Width = 600
    Height = 40
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object ComboSchema: TComboBox
      Left = 10
      Top = 10
      Width = 150
      Height = 21
      Style = csDropDownList
      TabOrder = 0
    end
    object BLogin: TButton
      Left = 170
      Top = 8
      Width = 80
      Height = 25
      Caption = 'Login'
      TabOrder = 1
    end
  end
  object Edge: TEdgeBrowser
    Left = 0
    Top = 40
    Width = 600
    Height = 360
    Align = alClient
    TabOrder = 1
    OnCreateWebViewCompleted = EdgeCreateWebViewCompleted
    OnWebMessageReceived = EdgeWebMessageReceived
  end
end
