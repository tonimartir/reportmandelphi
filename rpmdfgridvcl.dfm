object FRpGridOptionsVCL: TFRpGridOptionsVCL
  Left = 245
  Top = 108
  BorderStyle = bsDialog
  Caption = 'Dialog'
  ClientHeight = 261
  ClientWidth = 361
  Color = clBtnFace
  ParentFont = True
  Position = poScreenCenter
  ShowHint = True
  OnCreate = FormCreate
  PixelsPerInch = 120
  TextHeight = 20
  object GridColor: TShape
    Left = 150
    Top = 160
    Width = 51
    Height = 36
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    OnMouseDown = GridColorMouseDown
  end
  object Lhorizontal: TLabel
    Left = 10
    Top = 10
    Width = 156
    Height = 25
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Horizontal spacing'
  end
  object Lvertical: TLabel
    Left = 10
    Top = 40
    Width = 130
    Height = 25
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Vertical spacing'
  end
  object LGridColor: TLabel
    Left = 10
    Top = 170
    Width = 85
    Height = 25
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Grid Color'
  end
  object LUnits1: TLabel
    Left = 290
    Top = 10
    Width = 15
    Height = 25
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = '   '
  end
  object LUnits2: TLabel
    Left = 290
    Top = 40
    Width = 15
    Height = 25
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = '   '
  end
  object BOK: TButton
    Left = 24
    Top = 210
    Width = 94
    Height = 31
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'OK'
    Default = True
    TabOrder = 0
    OnClick = BOKClick
  end
  object BCancel: TButton
    Left = 224
    Top = 210
    Width = 94
    Height = 31
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 1
  end
  object EGridX: TRpMaskEdit
    Left = 180
    Top = 5
    Width = 101
    Height = 21
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    TabOrder = 2
    Text = ''
    EditType = tecurrency
  end
  object EGridY: TRpMaskEdit
    Left = 180
    Top = 35
    Width = 101
    Height = 21
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    TabOrder = 3
    Text = ''
    EditType = tecurrency
  end
  object CheckEnabled: TCheckBox
    Left = 10
    Top = 70
    Width = 271
    Height = 26
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Enabled'
    TabOrder = 4
  end
  object CheckVisible: TCheckBox
    Left = 10
    Top = 100
    Width = 261
    Height = 26
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Visible'
    TabOrder = 5
  end
  object CheckLines: TCheckBox
    Left = 10
    Top = 130
    Width = 281
    Height = 26
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Draw lines'
    TabOrder = 6
  end
  object ColorDialog1: TColorDialog
    Left = 152
    Top = 92
  end
end
