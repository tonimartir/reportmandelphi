object FRpExpressionChatFrame: TFRpExpressionChatFrame
  Left = 0
  Top = 0
  Width = 320
  Height = 558
  TabOrder = 0
  object PRoot: TPanel
    Left = 0
    Top = 0
    Width = 320
    Height = 558
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object PTop: TPanel
      Left = 0
      Top = 0
      Width = 320
      Height = 90
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object GridTop: TGridPanel
        Left = 0
        Top = 0
        Width = 320
        Height = 90
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 0
        ColumnCollection = <
          item
            SizeStyle = ssPercent
            Value = 100.000000000000000000
          end>
        ControlCollection = <
          item
            Column = 0
            Control = PLoginHost
            Row = 0
          end
          item
            Column = 0
            Control = PAISelectionHost
            Row = 1
          end>
        ParentBackground = False
        RowCollection = <
          item
            SizeStyle = ssAuto
            Value = 40.000000000000000000
          end
          item
            SizeStyle = ssAuto
            Value = 50.000000000000000000
          end>
        object PLoginHost: TPanel
          AlignWithMargins = True
          Left = 0
          Top = 0
          Width = 320
          Height = 40
          Margins.Left = 0
          Margins.Top = 0
          Margins.Right = 0
          Margins.Bottom = 0
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 0
        end
        object PAISelectionHost: TPanel
          AlignWithMargins = True
          Left = 0
          Top = 40
          Width = 320
          Height = 50
          Margins.Left = 0
          Margins.Top = 0
          Margins.Right = 0
          Margins.Bottom = 0
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 1
        end
      end
    end
    object MemoConversation: TMemo
      Left = 0
      Top = 90
      Width = 320
      Height = 380
      Align = alClient
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 1
      WordWrap = True
    end
    object PBottom: TPanel
      Left = 0
      Top = 470
      Width = 320
      Height = 88
      Align = alBottom
      BevelOuter = bvNone
      Padding.Left = 6
      Padding.Top = 6
      Padding.Right = 6
      Padding.Bottom = 6
      TabOrder = 2
      object MemoPrompt: TMemo
        Left = 6
        Top = 6
        Width = 226
        Height = 76
        Align = alClient
        OnChange = MemoPromptChange
        ScrollBars = ssVertical
        TabOrder = 0
        WantReturns = False
      end
      object PButtons: TPanel
        Left = 232
        Top = 6
        Width = 82
        Height = 76
        Align = alRight
        BevelOuter = bvNone
        TabOrder = 1
        object BSend: TButton
          Left = 0
          Top = 0
          Width = 82
          Height = 24
          Align = alTop
          Caption = 'Send'
          TabOrder = 0
          OnClick = BSendClick
        end
        object BApply: TButton
          Left = 0
          Top = 24
          Width = 82
          Height = 24
          Align = alTop
          Caption = 'Apply'
          TabOrder = 1
          OnClick = BApplyClick
        end
        object BClear: TButton
          Left = 0
          Top = 48
          Width = 82
          Height = 24
          Align = alTop
          Caption = 'Clear'
          TabOrder = 2
          OnClick = BClearClick
        end
      end
    end
  end
end