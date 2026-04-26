unit MainForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, rpcompobase, rppdfreport,
  FMX.Memo.Types, FMX.ScrollBox, FMX.Memo,System.IOUtils;

type
  TForm1 = class(TForm)
    Button1: TButton;
    PDFReport1: TPDFReport;
    Memo1: TMemo;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

procedure TForm1.Button1Click(Sender: TObject);
var
 memstream: TMemoryStream;
 memocontent: string;
 bytes:TBytes;
 FileName:string;
begin
 memocontent:=Memo1.Lines.Text;
 bytes:=TEncoding.UTF8.GetBytes(memocontent);
 memstream:=TMemoryStream.Create;
 try
  memstream.Write(bytes,length(bytes));
  memstream.Seek(0, TSeekOrigin.soBeginning);
  PDFReport1.LoadFromStream(memstream);
 finally
  memstream.Free;
 end;
  FileName :=
    TPath.Combine(
      TPath.GetSharedDownloadsPath,
      'output.pdf'
    );

 PDFReport1.PDFFilename := FileName;
 PDFReport1.Execute;
 ShowMessage('PDF generated at: '+Filename);
end;

end.
