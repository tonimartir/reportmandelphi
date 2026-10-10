object FRpMonacoEditorVCL: TFRpMonacoEditorVCL
  Left = 0
  Top = 0
  Width = 750
  Height = 500
  Margins.Left = 4
  Margins.Top = 4
  Margins.Right = 4
  Margins.Bottom = 4
  TabOrder = 0
  PixelsPerInch = 120
  object PTop: TPanel
    Left = 0
    Top = 0
    Width = 750
    Height = 63
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object GridTopHeader: TGridPanel
      Left = 0
      Top = 0
      Width = 750
      Height = 63
      Align = alClient
      BevelOuter = bvNone
      ColumnCollection = <
        item
          Value = 100.000000000000000000
        end
        item
          SizeStyle = ssAbsolute
          Value = 50.000000000000000000
        end
        item
          SizeStyle = ssAbsolute
          Value = 68.000000000000000000
        end
        item
          SizeStyle = ssAbsolute
          Value = 480.000000000000000000
        end>
      ControlCollection = <
        item
          Column = 0
          Control = ComboSchema
          Row = 0
        end
        item
          Column = 1
          Control = PSchemaConfigHost
          Row = 0
        end
        item
          Column = 2
          Control = PAIButtonHost
          Row = 0
        end
        item
          Column = 3
          Control = PAISelectionHost
          Row = 0
        end>
      ParentBackground = False
      RowCollection = <
        item
          Value = 100.000000000000000000
        end>
      TabOrder = 0
      object ComboSchema: TComboBox
        AlignWithMargins = True
        Left = 8
        Top = 11
        Width = 142
        Height = 28
        Margins.Left = 8
        Margins.Top = 11
        Margins.Right = 8
        Margins.Bottom = 11
        Align = alClient
        Style = csDropDownList
        TabOrder = 0
      end
      object PSchemaConfigHost: TPanel
        AlignWithMargins = True
        Left = 158
        Top = 13
        Width = 37
        Height = 37
        Margins.Left = 0
        Margins.Top = 13
        Margins.Right = 8
        Margins.Bottom = 13
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 2
        ExplicitLeft = 166
      end
      object PAIButtonHost: TPanel
        AlignWithMargins = True
        Left = 204
        Top = 8
        Width = 52
        Height = 34
        Margins.Left = 8
        Margins.Top = 8
        Margins.Right = 8
        Margins.Bottom = 8
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 3
        ExplicitLeft = 212
      end
      object PAISelectionHost: TPanel
        AlignWithMargins = True
        Left = 272
        Top = 0
        Width = 480
        Height = 63
        Margins.Left = 8
        Margins.Top = 0
        Margins.Right = 0
        Margins.Bottom = 0
        Align = alClient
        BevelOuter = bvNone
        Padding.Right = 8
        TabOrder = 4
        ExplicitLeft = 280
        ExplicitWidth = 470
      end
    end
  end
  object PControl: TPageControl
    Left = 0
    Top = 50
    Width = 750
    Height = 450
    ActivePage = TabSQL
    Align = alClient
    TabOrder = 1
    object TabSQL: TTabSheet
      Caption = 'Editor SQL'
      object Edge: TEdgeBrowser
        Left = 0
        Top = 0
        Width = 742
        Height = 422
        Align = alClient
        TabOrder = 0
        OnCreateWebViewCompleted = EdgeCreateWebViewCompleted
      end
    end
    object TabAudit: TTabSheet
      Caption = 'Audit'
      ImageIndex = 1
      object PAuditTop: TPanel
        Left = 0
        Top = 0
        Width = 742
        Height = 33
        Align = alTop
        BevelOuter = bvNone
        Padding.Left = 6
        Padding.Top = 4
        Padding.Right = 6
        Padding.Bottom = 4
        TabOrder = 0
        object BAuditSQL: TButton
          Left = 6
          Top = 4
          Width = 90
          Height = 25
          Align = alLeft
          Caption = 'Audit SQL'
          TabOrder = 0
          OnClick = BAuditSQLClick
        end
      end
      object MemoAudit: TMemo
        Left = 0
        Top = 33
        Width = 742
        Height = 389
        Align = alClient
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 1
        WordWrap = True
      end
    end
  end
  object SchemaConfigImageCollection: TImageCollection
    Images = <
      item
        Name = 'configicon32'
        SourceImages = <
          item
            Image.Data = {
              89504E470D0A1A0A0000000D4948445200000020000000200806000000737A7A
              F4000000017352474200AECE1CE90000000467414D410000B18F0BFC61050000
              00097048597300000EC300000EC301C76FA8640000001974455874536F667477
              617265005061696E742E4E455420352E312E313213014774000000B865584966
              49492A000800000005001A010500010000004A0000001B010500010000005200
              000028010300010000000200000031010200110000005A000000698704000100
              00006C00000000000000600000000100000060000000010000005061696E742E
              4E455420352E312E31320000030000900700040000003032333001A003000100
              00000100000005A0040001000000960000000000000002000100020004000000
              5239380002000700040000003031303000000000D9A79A95C9B70B5F000002AB
              494441545847CD964D6B135114869F3B99A4B6DA1A04A58A886B45E942705777
              526DF10FB828FE806990AAEDC2BDE9A262C8CABA7621B89288D8407569DDFA03
              EAAA6EAA4CFDA81F69725DCC4C3273E7DCC9A444F08190F6CC3D1FF73DF7DC8C
              E200142ABE6E7792B6CB676173B1AC92D6FE38A6A11F4E6537951C60F3A369C9
              C7C015E3F97AC485DB33AD84B9DA28067FD40753215B01CFD778BEBEF06057C7
              CDE387E2FFC9A885C017CF4FF89AD80B081D95820FDB9AB1C55EA05BD3C9DD13
              AEEBE2F95A6B98180D5D328A90E50A1D96E782448F5EBBFC6AF5964676936E1B
              80A5B9563778567B520633F9B0B01521B660D8C9012A57E5986201712987456D
              5D8E996E01411BDC02DCB996AEBAD556ACBE724D33642867939FAC0210022694
              3183853E272734F3D3FB8947D54631BD3E446C81C4E38D70D7F5B21283D5CB4A
              29F8F455A1A5A1B38C622F90B140DAFD5849B1B77A349D3C4E1EF5E8291804B3
              38453C7B57646B4790DD86E76B5B2C8C3391AB055B3BA6A53F6B1B25D32492AB
              8083F0654F6C798A7F56405E721530228F7D264BB3F6331047012CBFF8A6ABCD
              76E2817988B266398EB3E0EB8EB6F8C709633900D51BE38A7A599D39A6999C90
              1D944A8FAA4447C3ECC5E42B5314EB70098E1F51898DC83BB28C6514C87514FB
              35E33E88BD3F98F267A9271A6D0500ACBC2CCA371D30751A66A6D23E83FD1664
              248FD3EEC0DA1B9773930E57CEFF311FA7B0152116D02FF941F8F11BEACD742B
              C4315C314FEC10A837E5986905085450E17B1DC0E7EF8A276F83CB403A6411F1
              C989AB68931F9B0227C64103B5759776874472AD838FC9F3F70500DCE08B6A23
              38AC59C9B12A009CBAEFEBEDDD98210AE0F9BAE0C0DDEBC2A819EBBA0F2DC9C9
              2AC08AE76BC7817BFD0AC8C9408B21FB36BC7949F174BECF0B8BC1408BBB0845
              8C16E1E7C3C176FF5FF017C431150D1B1251A40000000049454E44AE426082}
          end>
      end>
    Left = 56
    Top = 392
  end
  object SchemaConfigImages: TVirtualImageList
    Images = <
      item
        CollectionIndex = 0
        CollectionName = 'configicon32'
        Name = 'configicon32'
      end>
    ImageCollection = SchemaConfigImageCollection
    Width = 32
    Height = 32
    Left = 112
    Top = 392
  end
end
