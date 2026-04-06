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
            SizeStyle = ssPercent
            Value = 100.000000000000000000
          end
          item
            SizeStyle = ssAuto
            Value = 30.000000000000000000
          end>
        ControlCollection = <
          item
            Column = 0
            Control = PActionHost
            Row = 0
          end
          item
            Column = 1
            Control = PGaugeHost
            Row = 0
          end>
        ParentBackground = False
        RowCollection = <
          item
            SizeStyle = ssPercent
            Value = 100.000000000000000000
          end>
        TabOrder = 0
        object PActionHost: TPanel
          AlignWithMargins = True
          Left = 0
          Top = 0
          Width = 495
          Height = 63
          Margins.Left = 0
          Margins.Top = 0
          Margins.Right = 0
          Margins.Bottom = 0
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 0
          object GridCombos: TGridPanel
            Left = 0
            Top = 0
            Width = 495
            Height = 63
            Align = alClient
            BevelOuter = bvNone
            ColumnCollection = <
              item
                SizeStyle = ssPercent
                Value = 50.000000000000000000
              end
              item
                SizeStyle = ssPercent
                Value = 50.000000000000000000
              end>
            ControlCollection = <
              item
                Column = 0
                Control = ComboAIProvider
                Row = 0
              end
              item
                Column = 1
                Control = ComboAIMode
                Row = 0
              end>
            ParentBackground = False
            RowCollection = <
              item
                SizeStyle = ssPercent
                Value = 100.000000000000000000
              end>
            TabOrder = 0
            object ComboAIProvider: TComboBox
              AlignWithMargins = True
              Left = 4
              Top = 11
              Width = 241
              Height = 28
              Margins.Left = 4
              Margins.Top = 11
              Margins.Right = 4
              Margins.Bottom = 11
              Align = alClient
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
              AlignWithMargins = True
              Left = 253
              Top = 11
              Width = 241
              Height = 28
              Margins.Left = 4
              Margins.Top = 11
              Margins.Right = 4
              Margins.Bottom = 11
              Align = alClient
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
        object PGaugeHost: TPanel
          AlignWithMargins = True
          Left = 493
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
            SizeStyle = ssPercent
            Value = 100.000000000000000000
          end
          item
            SizeStyle = ssAuto
            Value = 120.000000000000000000
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
            SizeStyle = ssPercent
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
          Width = 338
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
            Width = 338
            Height = 63
            Align = alClient
            Alignment = taCenter
            Caption = 'Tokens (In/Out): 0 / 0'
            Layout = tlCenter
          end
        end
        object PProgressHost: TPanel
          AlignWithMargins = True
          Left = 421
          Top = 0
          Width = 104
          Height = 63
          Margins.Left = 8
          Margins.Top = 0
          Margins.Right = 0
          Margins.Bottom = 0
          Align = alClient
          BevelOuter = bvNone
          Constraints.MinWidth = 30
          TabOrder = 2
          object ProgressBarAI: TProgressBar
            AlignWithMargins = True
            Left = 0
            Top = 22
            Width = 104
            Height = 18
            Margins.Left = 0
            Margins.Top = 22
            Margins.Right = 0
            Margins.Bottom = 23
            Align = alClient
            MarqueeInterval = 30
            TabOrder = 0
          end
        end
      end
    end
  end
end
          AutoSize = True
          Caption = 'Tokens (In/Out): 0 / 0'
        end
        object PProgressHost: TPanel
          AlignWithMargins = True
          Left = 197
          Top = 0
          Width = 328
          Height = 63
          Margins.Left = 4
          Margins.Top = 0
          Margins.Right = 0
          Margins.Bottom = 0
          Align = alClient
          BevelOuter = bvNone
          Constraints.MinWidth = 30
          TabOrder = 1
          object ProgressBarAI: TProgressBar
            AlignWithMargins = True
            Left = 0
            Top = 22
            Width = 328
            Height = 18
            Margins.Left = 0
            Margins.Top = 22
            Margins.Right = 0
            Margins.Bottom = 23
            Align = alClient
            MarqueeInterval = 30
            TabOrder = 0
          end
        end
      end
    end
  end
end
