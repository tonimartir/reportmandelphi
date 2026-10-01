unit salesdata;

{ Report Manager examples for Lazarus: the data that sales.rep prints.

  sales.rep has one dataset, SALES, with no database connection: the
  application gives it a TDataSet before running the report,

    Report.DataInfo.ItemByName('SALES').Dataset := MyDataset;

  Any TDataSet works (SQLdb, Zeos, TBufDataset...). Here it is an in-memory
  TBufDataset, so the examples need no database. A report can also open its
  own connections and SQL queries: see the Data configuration dialog of the
  designer. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, BufDataset;

// The fields CUSTOMER, ITEM, QUANTITY and AMOUNT, sorted by customer (the
// report groups the lines by customer)
function CreateSalesData(AOwner: TComponent): TBufDataset;

// sales.rep, in the folder above the example (examples/lazarus)
function SalesReportFile: string;

implementation

procedure AddSale(AData: TBufDataset; const ACustomer, AItem: string;
  AQuantity: Integer; APrice: Double);
begin
  AData.Append;
  AData.FieldByName('CUSTOMER').AsString := ACustomer;
  AData.FieldByName('ITEM').AsString := AItem;
  AData.FieldByName('QUANTITY').AsInteger := AQuantity;
  AData.FieldByName('AMOUNT').AsFloat := AQuantity * APrice;
  AData.Post;
end;

function CreateSalesData(AOwner: TComponent): TBufDataset;
begin
  Result := TBufDataset.Create(AOwner);
  Result.FieldDefs.Add('CUSTOMER', ftString, 40);
  Result.FieldDefs.Add('ITEM', ftString, 40);
  Result.FieldDefs.Add('QUANTITY', ftInteger);
  Result.FieldDefs.Add('AMOUNT', ftFloat);
  Result.CreateDataset;
  AddSale(Result, 'Acme Corporation', 'Laptop', 2, 899.00);
  AddSale(Result, 'Acme Corporation', 'Monitor 27"', 3, 249.50);
  AddSale(Result, 'Acme Corporation', 'Keyboard', 5, 39.90);
  AddSale(Result, 'Globex Ltd', 'Laser printer', 1, 329.00);
  AddSale(Result, 'Globex Ltd', 'Paper A4, box', 10, 24.95);
  AddSale(Result, 'Initech', 'Desk chair', 4, 189.00);
  AddSale(Result, 'Initech', 'Laptop', 1, 899.00);
  AddSale(Result, 'Initech', 'Mouse', 6, 19.90);
  AddSale(Result, 'Umbrella Inc', 'Monitor 27"', 2, 249.50);
  Result.First;
end;

function SalesReportFile: string;
var
  LDir: string;
begin
  // Each example writes its executable to its own folder
  LDir := ExtractFilePath(ExpandFileName(ParamStr(0)));
  {$IFDEF DARWIN}
  // Started as an application bundle (open preview.app): the executable is
  // in preview.app/Contents/MacOS, the bundle is in the folder of the project
  if Pos('.app/Contents/MacOS/', LDir) > 0 then
    LDir := IncludeTrailingPathDelimiter(ExpandFileName(LDir + '../../..'));
  {$ENDIF}
  Result := ExpandFileName(LDir + '..' + PathDelim + 'sales.rep');
  if not FileExists(Result) then
    Result := LDir + 'sales.rep';
end;

end.
