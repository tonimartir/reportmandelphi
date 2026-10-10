object FRpNewReportWizardVCL: TFRpNewReportWizardVCL
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'New Report'
  ClientHeight = 540
  ClientWidth = 720
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 15
  object PHeader: TPanel
    Left = 0
    Top = 0
    Width = 720
    Height = 56
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 0
    object LStepTitle: TLabel
      Left = 16
      Top = 12
      Width = 200
      Height = 21
      Caption = 'Step'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'Segoe UI Semibold'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object LStepHelper: TLabel
      Left = 16
      Top = 35
      Width = 680
      Height = 15
      Caption = ''
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 4210752
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
  end
  object PBottom: TPanel
    Left = 0
    Top = 492
    Width = 720
    Height = 48
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    DesignSize = (
      720
      48)
    object BCancel: TButton
      Left = 16
      Top = 10
      Width = 95
      Height = 30
      Anchors = [akLeft, akBottom]
      Caption = 'Cancel'
      TabOrder = 0
      OnClick = BCancelClick
    end
    object BBack: TButton
      Left = 408
      Top = 10
      Width = 95
      Height = 30
      Anchors = [akRight, akBottom]
      Caption = 'Back'
      TabOrder = 1
      OnClick = BBackClick
    end
    object BNext: TButton
      Left = 506
      Top = 10
      Width = 95
      Height = 30
      Anchors = [akRight, akBottom]
      Caption = 'Next'
      Default = True
      TabOrder = 2
      OnClick = BNextClick
    end
    object BFinish: TButton
      Left = 605
      Top = 10
      Width = 100
      Height = 30
      Anchors = [akRight, akBottom]
      Caption = 'Finish'
      TabOrder = 3
      OnClick = BFinishClick
    end
  end
  object PContent: TPanel
    Left = 0
    Top = 56
    Width = 720
    Height = 436
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
  end
end
