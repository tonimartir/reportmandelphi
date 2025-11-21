program FiredacTest;

uses
  System.StartUpCopy,FMX.ScrollBox,
  FMain in 'FMain.pas' {Form1},
  ModData in 'ModData.pas' {DataModule1: TDataModule},
  FMX.Forms;

{$R *.res}

begin
  //  Include in uses in Delphi 11 to fix ODBCMetadata
  // FireDAC.Phys.ODBCMeta in '..\..\Firedac11Fix\FireDAC.Phys.ODBCMeta.pas';
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TDataModule1, DataModule1);
  Application.Run;
end.
