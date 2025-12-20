object Form1: TForm1
  Left = 0
  Top = 0
  Margins.Left = 4
  Margins.Top = 4
  Margins.Right = 4
  Margins.Bottom = 4
  Caption = 'Reportman VCL Demo'
  ClientHeight = 461
  ClientWidth = 756
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -15
  Font.Name = 'Segoe UI'
  Font.Style = []
  PixelsPerInch = 120
  DesignSize = (
    756
    461)
  TextHeight = 20
  object Label1: TLabel
    Left = 30
    Top = 20
    Width = 565
    Height = 20
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 
      'PDFReport Component is Cross Platform, generates a PDF File from' +
      ' a report template'
  end
  object Label2: TLabel
    Left = 30
    Top = 89
    Width = 482
    Height = 20
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 
      'VCLReport Component shows a preview or prints report using VCL l' +
      'ibrary'
  end
  object Label3: TLabel
    Left = 30
    Top = 169
    Width = 406
    Height = 20
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'RpDesignerVCL Component shows the report template editor'
  end
  object Label4: TLabel
    Left = 30
    Top = 249
    Width = 165
    Height = 20
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'This is the sample report,'
  end
  object BGeneratePDF: TButton
    Left = 30
    Top = 48
    Width = 161
    Height = 33
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Generate PDF'
    TabOrder = 0
    OnClick = BGeneratePDFClick
  end
  object BPreview: TButton
    Left = 30
    Top = 117
    Width = 161
    Height = 33
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Preview'
    TabOrder = 1
    OnClick = BPreviewClick
  end
  object BPrint: TButton
    Left = 209
    Top = 117
    Width = 161
    Height = 33
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Print'
    TabOrder = 2
    OnClick = BPreviewClick
  end
  object BDesign: TButton
    Left = 30
    Top = 197
    Width = 161
    Height = 33
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Caption = 'Design'
    TabOrder = 3
    OnClick = BDesignClick
  end
  object Memo1: TMemo
    Left = 30
    Top = 277
    Width = 717
    Height = 175
    Margins.Left = 4
    Margins.Top = 4
    Margins.Right = 4
    Margins.Bottom = 4
    Anchors = [akLeft, akTop, akRight, akBottom]
    Lines.Strings = (
      'object TRpReport'
      '  PageHeight = 8120'
      '  PageWidth = 5742'
      '  PageBackColor = 2147483647'
      '  SubReports = <'
      '    item'
      '      SubReport = TRpSubReport0'
      '    end>'
      '  DataInfo = <'
      '    item'
      '      Alias = '#39'FISH'#39
      '      DatabaseAlias = '#39'CONF'#39
      '      SQL = '#39'SELECT * FROM BIOLIFE ORDER BY CATEGORY'#39
      '      MyBaseFilename = '#39'biolife.cds'#39
      '      MyBaseIndexFields = '#39'Category'#39
      '    end>'
      '  DatabaseInfo = <'
      '    item'
      '      Alias = '#39'CONF'#39
      '      LoadParams = False'
      '      LoadDriverParams = False'
      '      LoginPrompt = False'
      '      Driver = rpdatamybase'
      '      ReportTable = '#39'REPMAN_REPORTS'#39
      '      ReportSearchField = '#39'REPORT_NAME'#39
      '      ReportField = '#39'REPORT'#39
      '      ReportGroupsTable = '#39'REPMAN_GROUPS'#39
      '      ADOConnectionString = '#39#39
      '    end>'
      '  Params = <'
      '    item'
      '      Name = '#39'TITLE1'#39
      '      Value = '#39'Fishes, species'#39
      '      Description = '#39'Title 1'#39
      '      Hint = '#39#39
      '      Search = '#39#39
      '      ErrorMessage = '#39#39
      '      Validation = '#39#39
      '    end'
      '    item'
      '      Name = '#39'TITLE2'#39
      '      Value = '#39'Descriptions and images'#39
      '      Description = '#39'Title 2'#39
      '      Hint = '#39#39
      '      Search = '#39#39
      '      ErrorMessage = '#39#39
      '      Validation = '#39#39
      '    end>'
      '  StreamFormat = rpStreamText'
      '  ReportAction = []'
      '  Type1Font = poHelvetica'
      '  LinesPerInch = 800'
      '  WFontName = '#39'Arial'#39
      '  LFontName = '#39'Helvetica'#39
      '  object TRpSubReport0: TRpSubReport'
      '    Sections = <'
      '      item'
      '        Section = TRpSection1'
      '      end'
      '      item'
      '        Section = TRpSection2'
      '      end'
      '      item'
      '        Section = TRpSection3'
      '      end'
      '      item'
      '        Section = TRpSection7'
      '      end'
      '      item'
      '        Section = TRpSection0'
      '      end'
      '      item'
      '        Section = TRpSection4'
      '      end'
      '      item'
      '        Section = TRpSection5'
      '      end'
      '      item'
      '        Section = TRpSection6'
      '      end>'
      '    Alias = '#39'FISH'#39
      '  end'
      '  object TRpSection0: TRpSection'
      '    Width = 10205'
      '    Height = 1365'
      '    SubReport = TRpSubReport0'
      '    ChangeBool = False'
      '    PageRepeat = False'
      '    SkipPage = False'
      '    AlignBottom = False'
      '    SectionType = rpsecdetail'
      '    Components = <'
      '      item'
      '        Component = TRpExpression4'
      '      end'
      '      item'
      '        Component = TRpImage0'
      '      end'
      '      item'
      '        Component = TRpShape2'
      '      end>'
      '    AutoExpand = True'
      '    AutoContract = True'
      '    ExternalTable = '#39'REPMAN_REPORTS'#39
      '    ExternalField = '#39'REPORT'#39
      '    ExternalSearchField = '#39'REPORT_NAME'#39
      '    StreamFormat = rpStreamText'
      '    PrintCondition = '#39' '#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    ChangeExpression = '#39#39
      '    BeginPageExpression = '#39#39
      '    ChangeExpression = '#39#39
      '    SkipExpreV = '#39#39
      '    SkipExpreH = '#39#39
      '    SkipToPageExpre = '#39#39
      '    BackExpression = '#39#39
      '    Stream = {0000000000000000}'
      '  end'
      '  object TRpSection1: TRpSection'
      '    Width = 10900'
      '    Height = 454'
      '    SubReport = TRpSubReport0'
      '    ChangeBool = False'
      '    PageRepeat = False'
      '    SkipPage = False'
      '    AlignBottom = False'
      '    SectionType = rpsecpheader'
      '    Components = <'
      '      item'
      '        Component = TRpLabel0'
      '      end'
      '      item'
      '        Component = TRpExpression2'
      '      end'
      '      item'
      '        Component = TRpExpression6'
      '      end>'
      '    ExternalTable = '#39'REPMAN_REPORTS'#39
      '    ExternalField = '#39'REPORT'#39
      '    ExternalSearchField = '#39'REPORT_NAME'#39
      '    StreamFormat = rpStreamText'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    ChangeExpression = '#39#39
      '    BeginPageExpression = '#39#39
      '    ChangeExpression = '#39#39
      '    SkipExpreV = '#39#39
      '    SkipExpreH = '#39#39
      '    SkipToPageExpre = '#39#39
      '    BackExpression = '#39#39
      '    Stream = {0000000000000000}'
      '  end'
      '  object TRpLabel0: TRpLabel'
      '    Width = 1440'
      '    Height = 275'
      '    PosX = 5865'
      '    PosY = 0'
      '    Type1Font = poHelvetica'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    WFontName = '#39'Arial'#39
      '    LFontName = '#39'Helvetica'#39
      '    WideText = '#39'Page'#39'#10'#39'Page'#39'#10'#39'P'#39'#225'#39'gina'#39
      '  end'
      '  object TRpExpression2: TRpExpression'
      '    Width = 1440'
      '    Height = 275'
      '    PosX = 7470'
      '    PosY = 0'
      '    Type1Font = poHelvetica'
      '    AutoExpand = False'
      '    AutoContract = False'
      '    ExportPosition = 0'
      '    ExportSize = 1'
      '    ExportDoNewLine = False'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    WFontName = '#39'Arial'#39
      '    LFontName = '#39'Helvetica'#39
      '    Expression = '#39'Page'#39
      '    DisplayFormat = '#39#39
      '    ExportDisplayFormat = '#39#39
      '    AgIniValue = '#39'0'#39
      '    ExportExpression = '#39#39
      '  end'
      '  object TRpSection3: TRpSection'
      '    Width = 10900'
      '    Height = 1215'
      '    SubReport = TRpSubReport0'
      '    GroupName = '#39'F'#39
      '    ChangeBool = False'
      '    PageRepeat = True'
      '    SkipPage = False'
      '    AlignBottom = False'
      '    SectionType = rpsecgheader'
      '    Components = <'
      '      item'
      '        Component = TRpShape0'
      '      end'
      '      item'
      '        Component = TRpLabel2'
      '      end'
      '      item'
      '        Component = TRpExpression3'
      '      end'
      '      item'
      '        Component = TRpExpression7'
      '      end>'
      '    ExternalTable = '#39'REPMAN_REPORTS'#39
      '    ExternalField = '#39'REPORT'#39
      '    ExternalSearchField = '#39'REPORT_NAME'#39
      '    StreamFormat = rpStreamText'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    ChangeExpression = '#39'FISH.CATEGORY'#39
      '    BeginPageExpression = '#39'FREE_SPACE_CMS<6.5'#39
      '    ChangeExpression = '#39'FISH.CATEGORY'#39
      '    SkipExpreV = '#39#39
      '    SkipExpreH = '#39#39
      '    SkipToPageExpre = '#39#39
      '    BackExpression = '#39#39
      '    Stream = {0000000000000000}'
      '  end'
      '  object TRpSection4: TRpSection'
      '    Width = 10900'
      '    Height = 574'
      '    SubReport = TRpSubReport0'
      '    GroupName = '#39'F'#39
      '    ChangeBool = False'
      '    PageRepeat = False'
      '    SkipPage = False'
      '    AlignBottom = False'
      '    SectionType = rpsecgfooter'
      '    Components = <'
      '      item'
      '        Component = TRpExpression5'
      '      end>'
      '    ExternalTable = '#39'REPMAN_REPORTS'#39
      '    ExternalField = '#39'REPORT'#39
      '    ExternalSearchField = '#39'REPORT_NAME'#39
      '    StreamFormat = rpStreamText'
      '    PrintCondition = '#39'false'#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    ChangeExpression = '#39'FISH.CATEGORY'#39
      '    BeginPageExpression = '#39#39
      '    ChangeExpression = '#39'FISH.CATEGORY'#39
      '    SkipExpreV = '#39#39
      '    SkipExpreH = '#39#39
      '    SkipToPageExpre = '#39#39
      '    BackExpression = '#39#39
      '    Stream = {0000000000000000}'
      '  end'
      '  object TRpLabel2: TRpLabel'
      '    Width = 1843'
      '    Height = 576'
      '    PosX = 120'
      '    PosY = 225'
      '    Type1Font = poCourier'
      '    FontSize = 16'
      '    FontStyle = 6'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    WFontName = '#39'Arial'#39
      '    LFontName = '#39'adobe-courier'#39
      '    WideText = '#39'Category'#39'#10'#39'Category'#39'#10'#39'Categor'#39'#237'#39'a'#39
      '  end'
      '  object TRpExpression3: TRpExpression'
      '    Width = 3557'
      '    Height = 576'
      '    PosX = 2070'
      '    PosY = 225'
      '    Type1Font = poCourier'
      '    FontSize = 16'
      '    FontStyle = 3'
      '    AutoExpand = False'
      '    AutoContract = False'
      '    ExportPosition = 0'
      '    ExportSize = 1'
      '    ExportDoNewLine = False'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    WFontName = '#39'Arial'#39
      '    LFontName = '#39'adobe-courier'#39
      '    Expression = '#39'FISH.Category'#39
      '    DisplayFormat = '#39#39
      '    ExportDisplayFormat = '#39#39
      '    AgIniValue = '#39'0'#39
      '    ExportExpression = '#39#39
      '  end'
      '  object TRpExpression4: TRpExpression'
      '    Width = 7245'
      '    Height = 690'
      '    PosX = 120'
      '    PosY = 0'
      '    Type1Font = poHelvetica'
      '    FontSize = 13'
      '    Alignment = 1024'
      '    WordWrap = True'
      '    MultiPage = True'
      '    AutoExpand = False'
      '    AutoContract = False'
      '    ExportPosition = 0'
      '    ExportSize = 1'
      '    ExportDoNewLine = False'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    WFontName = '#39'Arial'#39
      '    LFontName = '#39'Helvetica'#39
      '    Expression = '#39'FISH.Notes'#39
      '    DisplayFormat = '#39#39
      '    ExportDisplayFormat = '#39#39
      '    AgIniValue = '#39'0'#39
      '    ExportExpression = '#39#39
      '  end'
      '  object TRpShape0: TRpShape'
      '    Width = 6437'
      '    Height = 691'
      '    PosX = 0'
      '    PosY = 0'
      '    Shape = rpsRoundRect'
      '    PenWidth = 0'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '  end'
      '  object TRpSection2: TRpSection'
      '    Width = 10900'
      '    Height = 0'
      '    SubReport = TRpSubReport0'
      '    GroupName = '#39'SUMARY'#39
      '    ChangeBool = False'
      '    PageRepeat = False'
      '    SkipPage = False'
      '    AlignBottom = False'
      '    SectionType = rpsecgheader'
      '    Components = <>'
      '    ExternalTable = '#39'REPMAN_REPORTS'#39
      '    ExternalField = '#39'REPORT'#39
      '    ExternalSearchField = '#39'REPORT_NAME'#39
      '    StreamFormat = rpStreamText'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    ChangeExpression = '#39#39
      '    BeginPageExpression = '#39#39
      '    ChangeExpression = '#39#39
      '    SkipExpreV = '#39#39
      '    SkipExpreH = '#39#39
      '    SkipToPageExpre = '#39#39
      '    BackExpression = '#39#39
      '    Stream = {0000000000000000}'
      '  end'
      '  object TRpSection5: TRpSection'
      '    Width = 10900'
      '    Height = 4590'
      '    SubReport = TRpSubReport0'
      '    GroupName = '#39'SUMARY'#39
      '    ChangeBool = False'
      '    PageRepeat = False'
      '    SkipPage = False'
      '    AlignBottom = False'
      '    SectionType = rpsecgfooter'
      '    Components = <'
      '      item'
      '        Component = TRpChart0'
      '      end'
      '      item'
      '        Component = TRpLabel4'
      '      end>'
      '    ExternalTable = '#39'REPMAN_REPORTS'#39
      '    ExternalField = '#39'REPORT'#39
      '    ExternalSearchField = '#39'REPORT_NAME'#39
      '    StreamFormat = rpStreamText'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    ChangeExpression = '#39#39
      '    BeginPageExpression = '#39#39
      '    ChangeExpression = '#39#39
      '    SkipExpreV = '#39#39
      '    SkipExpreH = '#39#39
      '    SkipToPageExpre = '#39#39
      '    BackExpression = '#39#39
      '    Stream = {0000000000000000}'
      '  end'
      '  object TRpChart0: TRpChart'
      '    Width = 10815'
      '    Height = 3915'
      '    PosX = 0'
      '    PosY = 570'
      '    Type1Font = poHelvetica'
      '    FontSize = 6'
      '    Series = <'
      '      item'
      '        Color = -1'
      '      end>'
      '    ChartType = rpchartpie'
      '    Driver = rpchartdriverdefault'
      '    View3dWalls = False'
      '    Resolution = 200'
      '    ShowLegend = True'
      '    HorzFontSize = 10'
      '    VertFontSize = 10'
      '    HorzFontRotation = 0'
      '    VertFontRotation = 0'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    WFontName = '#39'Arial'#39
      '    LFontName = '#39'Helvetica'#39
      '    GetValueCondition = '#39#39
      '    ValueExpression = '#39'[FISH.Length (cm)]'#39
      '    ChangeSerieExpression = '#39'True'#39
      '    CaptionExpression = '#39'Fish.Common_Name'#39
      '    SerieCaption = '#39#39
      '    ClearExpression = '#39#39
      '    ColorExpression = '#39#39
      '    SerieColorExpression = '#39#39
      '  end'
      '  object TRpLabel4: TRpLabel'
      '    Width = 4605'
      '    Height = 450'
      '    PosX = 0'
      '    PosY = 120'
      '    Type1Font = poHelvetica'
      '    FontSize = 15'
      '    FontStyle = 7'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    WFontName = '#39'Arial'#39
      '    LFontName = '#39'Helvetica'#39
      '    WideText = '
      
        '      '#39'Length in cms Chart'#39'#10'#39'Length in cms Chart'#39'#10'#39'Gr'#39'#225'#39'f' +
        'ico de longitud en c'#39' +'
      '      '#39'ms'#39
      '  end'
      '  object TRpExpression5: TRpExpression'
      '    Width = 1830'
      '    Height = 450'
      '    PosX = 1155'
      '    PosY = 120'
      '    Type1Font = poHelvetica'
      '    Aggregate = rpAgGroup'
      '    GroupName = '#39'F'#39
      '    AutoExpand = False'
      '    AutoContract = False'
      '    ExportPosition = 0'
      '    ExportSize = 1'
      '    ExportDoNewLine = False'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    WFontName = '#39'Arial'#39
      '    LFontName = '#39'Helvetica'#39
      '    Expression = '#39'1'#39
      '    DisplayFormat = '#39#39
      '    ExportDisplayFormat = '#39#39
      '    AgIniValue = '#39'0'#39
      '    ExportExpression = '#39#39
      '  end'
      '  object TRpSection6: TRpSection'
      '    Width = 10772'
      '    Height = 1134'
      '    SubReport = TRpSubReport0'
      '    ChangeBool = False'
      '    PageRepeat = False'
      '    SkipPage = False'
      '    AlignBottom = False'
      '    SectionType = rpsecpfooter'
      '    Components = <'
      '      item'
      '        Component = TRpShape1'
      '      end'
      '      item'
      '        Component = TRpLabel5'
      '      end>'
      '    ExternalTable = '#39'REPMAN_REPORTS'#39
      '    ExternalField = '#39'REPORT'#39
      '    ExternalSearchField = '#39'REPORT_NAME'#39
      '    StreamFormat = rpStreamText'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    ChangeExpression = '#39#39
      '    BeginPageExpression = '#39#39
      '    ChangeExpression = '#39#39
      '    SkipExpreV = '#39#39
      '    SkipExpreH = '#39#39
      '    SkipToPageExpre = '#39#39
      '    BackExpression = '#39#39
      '    Stream = {0000000000000000}'
      '  end'
      '  object TRpSection7: TRpSection'
      '    Width = 10772'
      '    Height = 150'
      '    SubReport = TRpSubReport0'
      '    ChangeBool = False'
      '    PageRepeat = False'
      '    SkipPage = False'
      '    AlignBottom = False'
      '    SectionType = rpsecdetail'
      '    Components = <'
      '      item'
      '        Component = TRpExpression0'
      '      end'
      '      item'
      '        Component = TRpLabel1'
      '      end'
      '      item'
      '        Component = TRpLabel3'
      '      end'
      '      item'
      '        Component = TRpExpression1'
      '      end'
      '      item'
      '        Component = TRpShape3'
      '      end>'
      '    AutoExpand = True'
      '    AutoContract = True'
      '    ExternalTable = '#39'REPMAN_REPORTS'#39
      '    ExternalField = '#39'REPORT'#39
      '    ExternalSearchField = '#39'REPORT_NAME'#39
      '    StreamFormat = rpStreamText'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    ChangeExpression = '#39#39
      '    BeginPageExpression = '#39#39
      '    ChangeExpression = '#39#39
      '    SkipExpreV = '#39#39
      '    SkipExpreH = '#39#39
      '    SkipToPageExpre = '#39#39
      '    BackExpression = '#39#39
      '    Stream = {0000000000000000}'
      '  end'
      '  object TRpExpression0: TRpExpression'
      '    Width = 3915'
      '    Height = 345'
      '    PosX = 1725'
      '    PosY = 0'
      '    Type1Font = poHelvetica'
      '    FontStyle = 1'
      '    AutoExpand = False'
      '    AutoContract = False'
      '    ExportPosition = 0'
      '    ExportSize = 1'
      '    ExportDoNewLine = False'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    WFontName = '#39'Arial'#39
      '    LFontName = '#39'Helvetica'#39
      '    Expression = '#39'FISH.Common_Name'#39
      '    DisplayFormat = '#39#39
      '    ExportDisplayFormat = '#39#39
      '    AgIniValue = '#39'0'#39
      '    ExportExpression = '#39#39
      '  end'
      '  object TRpLabel1: TRpLabel'
      '    Width = 1500'
      '    Height = 345'
      '    PosX = 120'
      '    PosY = 0'
      '    Type1Font = poHelvetica'
      '    FontStyle = 4'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    WFontName = '#39'Arial'#39
      '    LFontName = '#39'Helvetica'#39
      '    WideText = '#39'Name'#39'#10'#39'Name'#39'#10'#39'Nombre'#39
      '  end'
      '  object TRpLabel3: TRpLabel'
      '    Width = 1830'
      '    Height = 345'
      '    PosX = 5865'
      '    PosY = 0'
      '    Type1Font = poHelvetica'
      '    FontStyle = 4'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    WFontName = '#39'Arial'#39
      '    LFontName = '#39'Helvetica'#39
      '    WideText = '#39'Length'#39'#10'#39'Length'#39'#10'#39'Longitud'#39
      '  end'
      '  object TRpExpression1: TRpExpression'
      '    Width = 2419'
      '    Height = 346'
      '    PosX = 7710'
      '    PosY = 0'
      '    Type1Font = poHelvetica'
      '    FontStyle = 1'
      '    AutoExpand = False'
      '    AutoContract = False'
      '    ExportPosition = 0'
      '    ExportSize = 1'
      '    ExportDoNewLine = False'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    WFontName = '#39'Arial'#39
      '    LFontName = '#39'Helvetica'#39
      '    Expression = '#39'[FISH.Length (cm)]'#39
      '    DisplayFormat = '#39#39
      '    ExportDisplayFormat = '#39#39
      '    AgIniValue = '#39'0'#39
      '    ExportExpression = '#39#39
      '  end'
      '  object TRpLabel5: TRpLabel'
      '    Width = 10695'
      '    Height = 915'
      '    PosX = 0'
      '    PosY = 120'
      '    Type1Font = poHelvetica'
      '    FontSize = 30'
      '    Alignment = 4'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    WFontName = '#39'Arial'#39
      '    LFontName = '#39'Helvetica'#39
      '    WideText = '#39'Sample report for Report Manager '#39
      '  end'
      '  object TRpImage0: TRpImage'
      '    Width = 2070'
      '    Height = 690'
      '    PosX = 8055'
      '    PosY = 0'
      '    DrawStyle = rpDrawFull'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    Expression = '#39'FISH.Graphic'#39
      '    Stream = {0000000000000000}'
      '  end'
      '  object TRpShape1: TRpShape'
      '    Width = 10695'
      '    Height = 1155'
      '    PosX = 0'
      '    PosY = 0'
      '    PenWidth = 0'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '  end'
      '  object TRpExpression6: TRpExpression'
      '    Width = 3210'
      '    Height = 465'
      '    PosX = 120'
      '    PosY = 0'
      '    Type1Font = poHelvetica'
      '    FontSize = 14'
      '    AutoExpand = False'
      '    AutoContract = False'
      '    ExportPosition = 0'
      '    ExportSize = 1'
      '    ExportDoNewLine = False'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    WFontName = '#39'Arial'#39
      '    LFontName = '#39'Helvetica'#39
      '    Expression = '#39'Title1'#39
      '    DisplayFormat = '#39#39
      '    ExportDisplayFormat = '#39#39
      '    AgIniValue = '#39'0'#39
      '    ExportExpression = '#39#39
      '  end'
      '  object TRpExpression7: TRpExpression'
      '    Width = 3210'
      '    Height = 465'
      '    PosX = 6675'
      '    PosY = 120'
      '    Type1Font = poHelvetica'
      '    FontSize = 12'
      '    AutoExpand = False'
      '    AutoContract = False'
      '    ExportPosition = 0'
      '    ExportSize = 1'
      '    ExportDoNewLine = False'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '    WFontName = '#39'Arial'#39
      '    LFontName = '#39'Helvetica'#39
      '    Expression = '#39'Title2'#39
      '    DisplayFormat = '#39#39
      '    ExportDisplayFormat = '#39#39
      '    AgIniValue = '#39'0'#39
      '    ExportExpression = '#39#39
      '  end'
      '  object TRpShape2: TRpShape'
      '    Width = 28'
      '    Height = 465'
      '    PosX = 0'
      '    PosY = 0'
      '    Align = rpaltopbottom'
      '    BrushColor = 0'
      '    Shape = rpsVertLine'
      '    PenWidth = 57'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '  end'
      '  object TRpShape3: TRpShape'
      '    Width = 28'
      '    Height = 57'
      '    PosX = 0'
      '    PosY = 0'
      '    Align = rpaltopbottom'
      '    BrushColor = 0'
      '    Shape = rpsVertLine'
      '    PenWidth = 57'
      '    PrintCondition = '#39#39
      '    DoBeforePrint = '#39#39
      '    DoAfterPrint = '#39#39
      '  end'
      'end')
    ScrollBars = ssBoth
    TabOrder = 4
    WordWrap = False
  end
  object VCLReport1: TVCLReport
    AsyncExecution = False
    PDFConformance = SetPDFDefault
    Title = 'Sin t'#237'tulo'
    Left = 400
    Top = 190
  end
  object PDFReport1: TPDFReport
    AsyncExecution = False
    PDFConformance = SetPDFDefault
    Title = 'Sin t'#237'tulo'
    ShowPrintDialog = False
    Left = 500
    Top = 190
  end
  object RpDesignerVCL1: TRpDesignerVCL
    OnSave = RpDesignerVCL1Save
    Left = 290
    Top = 190
  end
  object SaveDialog1: TSaveDialog
    DefaultExt = 'PDF'
    FileName = '*.pdf'
    Filter = 'PDF Files|*.pdf'
    Title = 'Select pdf file name'
    Left = 610
    Top = 190
  end
end
