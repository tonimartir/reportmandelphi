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
    object PNonInference: TPanel
      Left = 0
      Top = 0
      Width = 525
      Height = 63
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 0
      object GridAI: TGridPanel
        Left = 0
        Top = 0
        Width = 525
        Height = 63
        Align = alClient
        BevelOuter = bvNone
        ColumnCollection = <
          item
            Value = 50.000000000000000000
          end
          item
            Value = 50.000000000000000000
          end
          item
            SizeStyle = ssAuto
            Value = 30.000000000000000000
          end>
        ControlCollection = <
          item
            Column = 0
            Control = PProviderHost
            Row = 0
          end
          item
            Column = 1
            Control = PModeHost
            Row = 0
          end
          item
            Column = 2
            Control = PGaugeHost
            Row = 0
          end>
        ParentBackground = False
        RowCollection = <
          item
            Value = 100.000000000000000000
          end>
        TabOrder = 0
        object PProviderHost: TPanel
          AlignWithMargins = True
          Left = 0
          Top = 0
          Width = 238
          Height = 63
          Margins.Left = 0
          Margins.Top = 0
          Margins.Right = 4
          Margins.Bottom = 0
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 0
          ExplicitWidth = 241
          object ComboAIProvider: TComboBox
            Left = 0
            Top = 0
            Width = 238
            Height = 28
            Align = alTop
            Style = csDropDownList
            ItemIndex = 0
            TabOrder = 0
            Text = 'Standard'
            OnChange = ComboAIProviderChange
            Items.Strings = (
              'Standard'
              'Precision')
            ExplicitTop = 17
            ExplicitWidth = 241
            ExplicitHeight = 21
          end
        end
        object PModeHost: TPanel
          AlignWithMargins = True
          Left = 246
          Top = 0
          Width = 235
          Height = 63
          Margins.Left = 4
          Margins.Top = 0
          Margins.Right = 4
          Margins.Bottom = 0
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 2
          ExplicitLeft = 245
          ExplicitWidth = 240
          object ComboAIMode: TComboBox
            Left = 0
            Top = 0
            Width = 235
            Height = 28
            Align = alTop
            Style = csDropDownList
            ItemIndex = 0
            TabOrder = 0
            Text = 'Fast'
            OnChange = ComboAIModeChange
            Items.Strings = (
              'Fast'
              'Reasoning')
            ExplicitTop = 17
            ExplicitWidth = 240
            ExplicitHeight = 21
          end
        end
        object PGaugeHost: TPanel
          AlignWithMargins = True
          Left = 489
          Top = 0
          Width = 32
          Height = 63
          Margins.Left = 4
          Margins.Top = 0
          Margins.Right = 4
          Margins.Bottom = 0
          Align = alClient
          BevelOuter = bvNone
          ParentShowHint = False
          ShowHint = True
          TabOrder = 1
          ExplicitLeft = 493
          object PaintBoxGauge: TPaintBox
            Left = 1
            Top = 16
            Width = 30
            Height = 30
            Hint = 'Credits'
            ParentShowHint = False
            ShowHint = True
            OnPaint = PaintBoxGaugePaint
          end
        end
      end
    end
    object PInferenceProgress: TPanel
      Left = 0
      Top = 0
      Width = 525
      Height = 63
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      Visible = False
      object GridInference: TGridPanel
        Left = 0
        Top = 0
        Width = 525
        Height = 63
        Align = alClient
        BevelOuter = bvNone
        ColumnCollection = <
          item
            SizeStyle = ssAuto
            Value = 60.000000000000000000
          end
          item
            Value = 100.000000000000000000
          end
          item
            SizeStyle = ssAuto
            Value = 80.000000000000000000
          end>
        ControlCollection = <
          item
            Column = 0
            Control = BStopInference
            Row = 0
          end
          item
            Column = 1
            Control = PTokensHost
            Row = 0
          end
          item
            Column = 2
            Control = PProgressHost
            Row = 0
          end>
        ParentBackground = False
        RowCollection = <
          item
            Value = 100.000000000000000000
          end>
        TabOrder = 0
        object BStopInference: TButton
          AlignWithMargins = True
          Left = 4
          Top = 16
          Width = 47
          Height = 30
          Margins.Left = 4
          Margins.Top = 16
          Margins.Right = 8
          Margins.Bottom = 16
          Align = alLeft
          Caption = 'Stop'
          TabOrder = 0
          OnClick = BStopInferenceClick
        end
        object PTokensHost: TPanel
          AlignWithMargins = True
          Left = 67
          Top = 0
          Width = 362
          Height = 63
          Margins.Left = 8
          Margins.Top = 0
          Margins.Right = 8
          Margins.Bottom = 0
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 1
          object LTokensInfo: TLabel
            Left = 0
            Top = 0
            Width = 138
            Height = 20
            Align = alClient
            Alignment = taCenter
            Caption = 'Tokens (In/Out): 0 / 0'
            Layout = tlCenter
          end
        end
        object PProgressHost: TPanel
          AlignWithMargins = True
          Left = 445
          Top = 0
          Width = 36
          Height = 63
          Margins.Left = 8
          Margins.Top = 0
          Margins.Right = 0
          Margins.Bottom = 0
          Align = alClient
          BevelOuter = bvNone
          Constraints.MinWidth = 30
          TabOrder = 2
          object PaintBoxProgress: TPaintBox
            Left = 3
            Top = 16
            Width = 30
            Height = 30
            OnPaint = PaintBoxProgressPaint
          end
        end
      end
    end
  end
  object SpinnerTimer: TTimer
    Enabled = False
    Interval = 90
    OnTimer = SpinnerTimerTimer
    Left = 24
    Top = 24
  end
end
