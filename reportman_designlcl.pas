{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit reportman_designlcl;

{$warn 5023 off : no warning about unused units}
interface

uses
  rpwebview2, rplclwebview, rpfrmmonacoeditorlcl, rprulerlcl, rpmdobinsintlcl, 
  rpmdflabelintlcl, rpmdfdrawintlcl, rpmdfbarcodeintlcl, rpmdfchartintlcl, 
  rpmdfsectionintlcl, rpmdfdesignlcl, rpmdesignerlcl, rpmregdesignlcl, 
  rpmdimageslcl, rpmdobjinsplcl, rpdbbrowserlcl, rpmdfstruclcl, rpmdfdinfolcl, 
  rpmdfmainlcl, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('rpmregdesignlcl', @rpmregdesignlcl.Register);
end;

initialization
  RegisterPackage('reportman_designlcl', @Register);
end.
