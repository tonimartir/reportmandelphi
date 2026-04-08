object FRpAIReportVCL: TFRpAIReportVCL
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Report AI-generated content'
  ClientHeight = 484
  ClientWidth = 620
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -15
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 120
  TextHeight = 20
  object LTitle: TLabel
    Left = 24
    Top = 16
    Width = 238
    Height = 28
    Caption = 'Report AI-generated content'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -21
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object LProblem: TLabel
    Left = 24
    Top = 60
    Width = 87
    Height = 20
    Caption = 'Issue detected:'
  end
  object LDetails: TLabel
    Left = 24
    Top = 112
    Width = 48
    Height = 20
    Caption = 'Details:'
  end
  object LAIContent: TLabel
    Left = 24
    Top = 220
    Width = 112
    Height = 20
    Caption = 'AI-generated text:'
  end
  object ComboProblem: TComboBox
    Left = 24
    Top = 84
    Width = 572
    Height = 28
    Style = csDropDownList
    TabOrder = 0
  end
  object MemoDetails: TMemo
    Left = 24
    Top = 136
    Width = 572
    Height = 68
    ScrollBars = ssVertical
    TabOrder = 1
    WantReturns = True
  end
  object MemoAIContent: TMemo
    Left = 24
    Top = 244
    Width = 572
    Height = 128
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 2
    WantReturns = True
  end
  object PDisclaimer: TPanel
    Left = 24
    Top = 384
    Width = 572
    Height = 60
    BevelOuter = bvNone
    Color = 16777192
    ParentBackground = False
    TabOrder = 3
    object LDisclaimer: TLabel
      Left = 10
      Top = 8
      Width = 550
      Height = 44
      AutoSize = False
      Caption = 'This report will be sent anonymously to our servers. It will only be used to reduce incorrect, offensive, or inappropriate responses.'
      WordWrap = True
    end
  end
  object BSend: TButton
    Left = 356
    Top = 446
    Width = 112
    Height = 28
    Caption = 'Send'
    Default = True
    TabOrder = 4
    OnClick = BSendClick
  end
  object BCancel: TButton
    Left = 484
    Top = 446
    Width = 112
    Height = 28
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 5
  end
end
