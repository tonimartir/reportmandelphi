{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit reportman;

{$warn 5023 off : no warning about unused units}
interface

uses
  rptypes, rptranslator, rpmdconsts, rpmetafile, rpmdcharttypes, rpprintitem, 
  rpalias, rpeval, rpevalfunc, rplabelitem, rpdrawitem, rpbasereport, 
  rpreport, rplastsav, rpmdchart, rppdffile, rppdfreport, rpmreg, 
  LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('rpmreg', @rpmreg.Register);
end;

initialization
  RegisterPackage('reportman', @Register);
end.
