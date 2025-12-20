object FRpRTParams: TFRpRTParams
  Left = 18
  Top = 31
  Width = 589
  Height = 304
  VertScrollBar.Range = 41
  Caption = 'Report parameters'
  Color = clBtnFace
  ParentFont = True
  Position = poScreenCenter
  Scaled = False
  ShowHint = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 20
  object PModalButtons: TPanel
    Left = 0
    Top = 211
    Width = 571
    Height = 46
    Align = alBottom
    TabOrder = 0
    object BOK: TButton
      Left = 15
      Top = 6
      Width = 98
      Height = 33
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = BOKClick
    end
    object BCancel: TButton
      Left = 166
      Top = 6
      Width = 102
      Height = 35
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
  object MainScrollBox: TScrollBox
    Left = 0
    Top = 0
    Width = 571
    Height = 211
    Align = alClient
    BorderStyle = bsNone
    TabOrder = 1
    ExplicitHeight = 212
    object PParent: TPanel
      Left = 0
      Top = 0
      Width = 571
      Height = 205
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object Splitter1: TSplitter
        Left = 260
        Top = 0
        Width = 8
        Height = 205
        Beveled = True
      end
      object PLeft: TPanel
        Left = 0
        Top = 0
        Width = 260
        Height = 205
        Align = alLeft
        BevelOuter = bvNone
        TabOrder = 0
      end
      object PRight: TPanel
        Left = 268
        Top = 0
        Width = 303
        Height = 205
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 1
      end
    end
  end
end
