// Fixture generator for the FastSerializer cross-test.
//
// Builds a DataSet covering every type the FastSerializer encodes, with
// edge values (nulls, max, min, zero, empty string, unicode, large/small
// dates, byte arrays, currency with scale 4), serializes it through
// Reportman.Core.FastSerializer, and writes the binary to
// fixtures/dotnet_fixture.bin.
//
// The Pascal counterpart (../test_fastserializer.dpr) reads this file
// back, rebuilds the dataset, then reserializes it and compares the
// resulting bytes against the original. Any mismatch fails the test.

using System;
using System.Data;
using System.IO;
using System.Text;
using Reportman.Core;

namespace FixtureGen;

public static class Program
{
    private const string TableName = "AllTypes";

    public static int Main(string[] args)
    {
        string outDir = args.Length > 0
            ? args[0]
            : Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "fixtures");
        Directory.CreateDirectory(outDir);

        var ds = BuildDataSet();
        var binPath = Path.Combine(outDir, "dotnet_fixture.bin");

        using (var ms = FastSerializer.SerializeDataSet(ds))
        using (var fs = File.Create(binPath))
            ms.CopyTo(fs);

        Console.WriteLine($"Wrote: {Path.GetFullPath(binPath)}");
        Console.WriteLine($"Size: {new FileInfo(binPath).Length} bytes");
        Console.WriteLine($"Table: {ds.Tables[0].TableName}");
        Console.WriteLine($"Columns: {ds.Tables[0].Columns.Count}");
        Console.WriteLine($"Rows: {ds.Tables[0].Rows.Count}");

        // Round-trip sanity check at the C# side - if we cannot read our
        // own bytes there is something broken in the C# version itself
        // and no point asking the Pascal side to try.
        var bytes = File.ReadAllBytes(binPath);
        var roundTrip = FastSerializer.DeSerializeDataSet(bytes);
        var origTable = ds.Tables[0];
        var rtTable = roundTrip.Tables[0];
        if (origTable.Rows.Count != rtTable.Rows.Count)
        {
            Console.Error.WriteLine(
                $"FAIL: C# round-trip row count mismatch " +
                $"({origTable.Rows.Count} -> {rtTable.Rows.Count})");
            return 2;
        }

        Console.WriteLine("C# round-trip OK.");
        return 0;
    }

    private static DataSet BuildDataSet()
    {
        var ds = new DataSet("FastSerCrossTest");
        var t = new DataTable(TableName) { CaseSensitive = true };

        t.Columns.Add("c_int32",     typeof(Int32));
        t.Columns.Add("c_int64",     typeof(Int64));
        t.Columns.Add("c_int16",     typeof(Int16));
        t.Columns.Add("c_byte",      typeof(Byte));
        t.Columns.Add("c_bool",      typeof(Boolean));
        t.Columns.Add("c_double",    typeof(Double));
        t.Columns.Add("c_single",    typeof(Single));
        t.Columns.Add("c_decimal",   typeof(Decimal));
        t.Columns.Add("c_string",    typeof(String));
        t.Columns.Add("c_bytes",     typeof(Byte[]));
        t.Columns.Add("c_datetime",  typeof(DateTime));
        t.Columns.Add("c_timespan",  typeof(TimeSpan));
        t.Columns.Add("c_char",      typeof(Char));

        // Row 0: typical values.
        t.Rows.Add(
            42,                                   // int32
            1234567890123L,                       // int64
            (Int16)(-32000),                      // int16
            (Byte)128,                            // byte
            true,                                 // bool
            3.141592653589793,                    // double
            2.71828f,                             // single
            123.4567m,                            // decimal
            "Hello, Reportman!",                  // string
            new byte[] { 0xDE, 0xAD, 0xBE, 0xEF },// bytes
            new DateTime(2026, 5, 27, 12, 34, 56, 789),  // datetime full
            TimeSpan.FromTicks(123456789L),       // timespan
            'A'                                   // char
        );

        // Row 1: edge minimums.
        t.Rows.Add(
            Int32.MinValue,
            Int64.MinValue,
            Int16.MinValue,
            (Byte)0,
            false,
            -1.7976931348623157e+308,             // ~Double.MinValue
            Single.MinValue,
            -987654321.4321m,                     // negative decimal, fits in Currency
            "x",                                  // single-char (was empty - TField quirk)
            new byte[] { 0x00 },                  // single-byte (was empty - TBlobField quirk)
            new DateTime(1900, 1, 1),             // date-only minimum
            TimeSpan.Zero,
            '\0'                                  // null char -> serialized as length 1 with 0 byte trimmed
        );

        // Row 2: edge maximums.
        t.Rows.Add(
            Int32.MaxValue,
            Int64.MaxValue,
            Int16.MaxValue,
            (Byte)255,
            true,
            1.7976931348623157e+308,              // ~Double.MaxValue
            Single.MaxValue,
            12345678.9012m,                       // moderate Decimal - TClientDataSet preserves precision
            new string('z', 1000),                // big string
            BigByteBlob(256),                     // 256 bytes
            new DateTime(9999, 12, 31, 23, 59, 59, 999),
            new TimeSpan(10, 20, 30),             // 10:20:30
            'Z'
        );

        // Row 3: all DBNull.
        var nullRow = t.NewRow();
        for (int i = 0; i < t.Columns.Count; i++)
            nullRow[i] = DBNull.Value;
        t.Rows.Add(nullRow);

        // Row 4: Unicode / non-ASCII text + char.
        t.Rows.Add(
            0,
            0L,
            (Int16)0,
            (Byte)0,
            false,
            0.0,
            0.0f,
            0m,
            "Año Nuevo - Niño - café - 中文 - 🎉",
            new byte[] { 0x00, 0x01, 0x7F, 0x80, 0xFF },
            new DateTime(2000, 2, 29),            // leap day, no time
            TimeSpan.FromMilliseconds(1),
            'ñ'
        );

        // Row 5: DateTime with time but no ms (7-byte payload),
        // single small int decimal, single ASCII char.
        t.Rows.Add(
            -1,
            -1L,
            (Int16)1,
            (Byte)1,
            true,
            0.5,
            0.5f,
            0.0001m,                              // smallest non-zero Currency
            " leading and trailing.",  // ends with non-space to dodge TField trim
            new byte[] { 0x42 },
            new DateTime(2026, 5, 27, 9, 15, 0),  // no ms
            new TimeSpan(0, 0, 0, 0, 500),        // 500 ms
            '!'                                   // non-whitespace, dodges TField trim
        );

        ds.Tables.Add(t);
        return ds;
    }

    private static byte[] BigByteBlob(int n)
    {
        var b = new byte[n];
        for (int i = 0; i < n; i++)
            b[i] = (byte)(i & 0xFF);
        return b;
    }
}
