unit rpmdfembeddedfile;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,rpmdConsts, TypInfo, rptypes;

type
  TFRpEmbeddedFile = class(TForm)
    labelDescription: TLabel;
    textDescription: TEdit;
    labelFilename: TLabel;
    textFilename: TEdit;
    labelRelationShip: TLabel;
    bok: TButton;
    BCancel: TButton;
    ComboRelationShip: TComboBox;
    labelMimeType: TLabel;
    ComboMimeType: TComboBox;
    labelCreationDate: TLabel;
    labelModificationDate: TLabel;
    textCreationDate: TEdit;
    textModificationDate: TEdit;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

function AskEmbeddedFileData(embeddedFile: TEmbeddedFile): boolean;

implementation

{$R *.dfm}

procedure TFRpEmbeddedFile.FormCreate(Sender: TObject);
var
  EnumValue: TPDFAFRelationShip;
  EnumName: string;
  mimes: TStringList;
  mime: string;
begin
 Caption:=SRpEmbeddedFile;
 labelDescription.Caption:=SRpDescription;
 labelMimeType.Caption:=SRpMimetype;
 labelRelationShip.Caption:=SRpRelationShip;
 labelFilename.Caption:=SRpFilename;
 labelCreationDate.Caption:=SRpCreationDateISO;
 labelModificationDate.Caption:=SRpModificationDateISO;
 bok.Caption:=SRpOk;
 BCancel.Caption:=SRpCancel;
 ComboRelationShip.Items.Clear;
 for EnumValue := Low(TPDFAFRelationShip) to High(TPDFAFRelationShip) do
 begin
  // Obtener el nombre del enum como string
  EnumName := GetEnumName(TypeInfo(TPDFAFRelationShip), Ord(EnumValue));
  ComboRelationShip.Items.Add(EnumName);
 end;
 ComboRelationShip.ItemIndex:=0;
 mimes:=TStringList.Create;
 try
  GetCommonMimeTypes(mimes);
  ComboMimeType.Items.Assign(mimes);
 finally
  mimes.Free;
 end;
end;


function AskEmbeddedFileData(embeddedFile: TEmbeddedFile): boolean;
var
 dia: TFRpEmbeddedFile;
begin
 Result:=false;
 dia:=TFRpEmbeddedFile.Create(nil);
 try
  dia.textDescription.Text:=embeddedFile.Description;
  dia.ComboMimeType.Text := embeddedFile.MimeType;
  dia.textFilename.Text := embeddedFile.FileName;
  dia.ComboRelationShip.ItemIndex := Integer(embeddedFile.AFRelationShip);
  dia.textCreationDate.Text := embeddedFile.CreationDate;
  dia.textModificationDate.Text := embeddedFile.ModificationDate;
  if (dia.ShowModal = mrOk) then
  begin
    embeddedFile.Description := dia.textDescription.Text;
    embeddedFile.MimeType:=dia.ComboMimeType.Text;
    embeddedFile.FileName:=dia.textFilename.Text;
    embeddedFile.AFRelationShip:=TPDFAFRelationShip(dia.ComboRelationShip.ItemIndex);
    embeddedFile.CreationDate := dia.textCreationDate.Text;
    embeddedFile.ModificationDate := dia.textModificationDate.Text;

    Result:=true;
  end;
 finally
   dia.Free;
 end;
end;


end.
