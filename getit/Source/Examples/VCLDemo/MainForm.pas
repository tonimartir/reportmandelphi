unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, rpmdesignervcl,
  rppdfreport, rpcompobase, rpvclreport,rpreport;

type
  TForm1 = class(TForm)
    VCLReport1: TVCLReport;
    PDFReport1: TPDFReport;
    RpDesignerVCL1: TRpDesignerVCL;
    Label1: TLabel;
    BGeneratePDF: TButton;
    BPreview: TButton;
    Label2: TLabel;
    BPrint: TButton;
    Label3: TLabel;
    BDesign: TButton;
    Label4: TLabel;
    Memo1: TMemo;
    SaveDialog1: TSaveDialog;
    procedure BPreviewClick(Sender: TObject);
    procedure BDesignClick(Sender: TObject);
    procedure RpDesignerVCL1Save(var Stream: TStream; report: TRpReport;
      var handled: Boolean);
    procedure BGeneratePDFClick(Sender: TObject);
  private
    function CreateStream:TMemoryStream;
    procedure LoadVCLReport;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.BDesignClick(Sender: TObject);
var
 stream: TMemoryStream;
begin
 stream:=CreateStream;
 try
  RpDesignerVCL1.LoadFromStream(stream);
  RPDesignerVCL1.Execute;
 finally
   stream.free;
 end;
end;

procedure TForm1.BGeneratePDFClick(Sender: TObject);
var
 stream: TMemoryStream;
 PDFFilename:string;
begin
 if not SaveDialog1.Execute(self.Handle) then
 begin
  exit;
 end;

 PDFReport1.PDFFilename:=SaveDialog1.FileName;
 stream:=CreateStream;
 try
  PDFReport1.LoadFromStream(stream);
 finally
   stream.free;
 end;
 PDFReport1.Execute;
end;

procedure TForm1.BPreviewClick(Sender: TObject);
begin
 LoadVCLReport;
 VCLReport1.Preview:=Sender=BPreview;
 VCLReport1.Execute;
end;

procedure TForm1.LoadVCLReport;
var
 stream: TMemoryStream;
begin
 stream:=CreateStream;
 try
  VCLReport1.LoadFromStream(stream);
 finally
   stream.free;
 end;
end;

procedure TForm1.RpDesignerVCL1Save(var Stream: TStream; report: TRpReport;
  var handled: Boolean);
var
 bytes:TBytes;
 readed:integer;
 mstream:TMemoryStream;
begin
 mstream:=TMemoryStream.Create;
 try
  report.SaveToStream(mstream);
  mstream.Seek(0,TSeekOrigin.soBeginning);
  SetLength(bytes,mstream.Size);
  readed:=mstream.Read(bytes,mstream.Size);
  Memo1.Lines.Text:=TEncoding.UTF8.GetString(bytes,0,readed);
 finally
  mstream.Free;
 end;
 handled:=true;
end;

function TForm1.CreateStream:TMemoryStream;
var bytes: TBytes;
begin
 bytes:=TEncoding.UTF8.GetBytes(Memo1.Lines.Text);
 Result:=TMemoryStream.Create();
 Result.Write(bytes,Length(bytes));
 Result.Seek(0,TSeekOrigin.soBeginning);
end;

end.
