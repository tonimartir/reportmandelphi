{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit reportman_lcl;

{$warn 5023 off : no warning about unused units}
interface

uses
  rplclfonts, rpgraphutilslcl, rpmaskedit, rplcldriver, rprflclparams, 
  rppreviewmetalcl, rppreviewcontrol, rppagesetuplcl, rplclpreview, 
  rplclreport, rpreglcl, rpmdfembeddedfilelcl, rpmdprintconfiglcl,
  LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('rpreglcl', @rpreglcl.Register);
end;

initialization
  RegisterPackage('reportman_lcl', @Register);
end.
