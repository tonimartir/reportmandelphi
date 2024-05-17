program FiredacTest;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMain in 'FMain.pas' {Form1},
  ModData in 'ModData.pas' {DataModule1: TDataModule},
  FireDAC.Phys.ODBCMeta in '..\..\Firedac11Fix\FireDAC.Phys.ODBCMeta.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TDataModule1, DataModule1);
  Application.Run;
end.
