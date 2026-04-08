object FRpChatFrame: TFRpChatFrame
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
      Height = 133
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object GridTop: TGridPanel
        Left = 0
        Top = 0
        Width = 320
        Height = 133
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
          end
          item
            Column = 0
            Control = PSchemaHost
            Row = 2
          end>
        ParentBackground = False
        RowCollection = <
          item
            SizeStyle = ssAuto
            Value = 40.000000000000000000
          end
          item
            SizeStyle = ssAuto
            Value = 63.000000000000000000
          end
          item
            SizeStyle = ssAuto
            Value = 30.000000000000000000
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
          Height = 63
          Margins.Left = 0
          Margins.Top = 0
          Margins.Right = 0
          Margins.Bottom = 0
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 1
        end
        object PSchemaHost: TPanel
          AlignWithMargins = True
          Left = 0
          Top = 103
          Width = 320
          Height = 30
          Margins.Left = 0
          Margins.Top = 0
          Margins.Right = 0
          Margins.Bottom = 0
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 2
          object LSchema: TLabel
            Left = 0
            Top = 0
            Width = 44
            Height = 30
            Align = alLeft
            Caption = 'Schema'
            Layout = tlCenter
          end
          object ComboSchema: TComboBox
            Left = 44
            Top = 0
            Width = 216
            Height = 21
            Align = alClient
            Style = csDropDownList
            TabOrder = 0
          end
          object BRefreshSchemas: TButton
            Left = 260
            Top = 0
            Width = 60
            Height = 30
            Align = alRight
            Caption = 'Refresh'
            TabOrder = 1
            OnClick = BRefreshSchemasClick
          end
        end
      end
    end
    object PControl: TPageControl
      Left = 0
      Top = 120
      Width = 320
      Height = 350
      ActivePage = TabChat
      Align = alClient
      TabOrder = 1
      object TabChat: TTabSheet
        Caption = 'Chat'
        object MemoConversation: TMemo
          Left = 0
          Top = 0
          Width = 312
          Height = 322
          Align = alClient
          ReadOnly = True
          ScrollBars = ssVertical
          TabOrder = 0
          WordWrap = True
        end
      end
      object TabLog: TTabSheet
        Caption = 'Log'
        ImageIndex = 1
        object PLogTop: TPanel
          Left = 0
          Top = 0
          Width = 312
          Height = 33
          Align = alTop
          BevelOuter = bvNone
          Padding.Left = 6
          Padding.Top = 4
          Padding.Right = 6
          Padding.Bottom = 4
          TabOrder = 0
          object BClearLog: TButton
            Left = 6
            Top = 4
            Width = 75
            Height = 25
            Align = alLeft
            Caption = 'Clear'
            TabOrder = 0
            OnClick = BClearLogClick
          end
          object PLogButtonSpacer: TPanel
            Left = 81
            Top = 4
            Width = 8
            Height = 25
            Align = alLeft
            BevelOuter = bvNone
            TabOrder = 1
          end
          object BReportAI: TButton
            Left = 89
            Top = 4
            Width = 110
            Height = 25
            Align = alLeft
            Caption = 'Report content'
            TabOrder = 2
            OnClick = BReportAIClick
          end
        end
        object MemoLog: TMemo
          Left = 0
          Top = 33
          Width = 312
          Height = 289
          Align = alClient
          ReadOnly = True
          ScrollBars = ssBoth
          TabOrder = 1
          WordWrap = False
        end
      end
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