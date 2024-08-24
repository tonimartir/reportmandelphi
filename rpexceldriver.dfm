object FRpExcelProgress: TFRpExcelProgress
  Left = 156
  Top = 200
  Width = 731
  Height = 292
  HorzScrollBar.Range = 558
  VertScrollBar.Range = 134
  ActiveControl = BCancel
  BorderStyle = bsDialog
  Caption = 'Print progress'
  Color = clBtnFace
  ParentFont = True
  Position = poScreenCenter
  ShowHint = True
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 20
  object LProcessing: TLabel
    Left = 10
    Top = 49
    Width = 88
    Height = 25
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Processing'
  end
  object LRecordCount: TLabel
    Left = 94
    Top = 49
    Width = 375
    Height = 26
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    AutoSize = False
  end
  object LTitle: TLabel
    Left = 10
    Top = 5
    Width = 43
    Height = 25
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Tittle'
    Visible = False
  end
  object LTittle: TLabel
    Left = 94
    Top = 5
    Width = 459
    Height = 51
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    AutoSize = False
  end
  object BCancel: TButton
    Left = 178
    Top = 153
    Width = 120
    Height = 30
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 0
    OnClick = BCancelClick
  end
  object BOK: TButton
    Left = 9
    Top = 153
    Width = 95
    Height = 26
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'OK'
    Default = True
    TabOrder = 1
    Visible = False
    OnClick = BOKClick
  end
  object GPrintRange: TGroupBox
    Left = 5
    Top = 5
    Width = 316
    Height = 139
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Print Range'
    TabOrder = 2
    Visible = False
    object LTo: TLabel
      Left = 168
      Top = 105
      Width = 20
      Height = 25
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'To'
    end
    object LFrom: TLabel
      Left = 18
      Top = 103
      Width = 42
      Height = 25
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'From'
    end
    object EFrom: TEdit
      Left = 69
      Top = 98
      Width = 65
      Height = 28
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      TabOrder = 0
    end
    object ETo: TEdit
      Left = 223
      Top = 100
      Width = 88
      Height = 28
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      TabOrder = 1
    end
    object RadioAll: TRadioButton
      Left = 15
      Top = 25
      Width = 258
      Height = 30
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'All pages'
      TabOrder = 2
    end
    object RadioRange: TRadioButton
      Left = 15
      Top = 59
      Width = 263
      Height = 31
      Margins.Left = 4
      Margins.Top = 4
      Margins.Right = 4
      Margins.Bottom = 4
      Caption = 'Range'
      TabOrder = 3
    end
  end
end
