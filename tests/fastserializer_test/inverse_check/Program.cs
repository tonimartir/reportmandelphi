// Inverse cross-test: reads the .bin file written by the Pascal side
// (test_fastserializer.dpr) and verifies that C# can decode it back into
// a DataSet with the same content as the original .NET-side fixture.
//
// This proves the codec works in BOTH directions:
//   Pascal -> bytes -> C# round-trip.
//
// Run after test_fastserializer.dpr has produced pascal_fixture.bin.

using System;
using System.Data;
using System.IO;
using Reportman.Core;

namespace InverseCheck;

public static class Program
{
    public static int Main(string[] args)
    {
        string fixturesDir = args.Length > 0
            ? args[0]
            : Path.Combine(AppContext.BaseDirectory,
                           "..", "..", "..", "..", "fixtures");

        string pascalBin = Path.Combine(fixturesDir, "pascal_fixture.bin");
        string dotnetBin = Path.Combine(fixturesDir, "dotnet_fixture.bin");

        if (!File.Exists(pascalBin))
        {
            Console.Error.WriteLine($"FAIL: missing {pascalBin}");
            Console.Error.WriteLine(
                "Run test_fastserializer.dpr first to generate it.");
            return 1;
        }
        if (!File.Exists(dotnetBin))
        {
            Console.Error.WriteLine($"FAIL: missing {dotnetBin}");
            return 1;
        }

        Console.WriteLine("=== Inverse cross-test: C# reads pascal_fixture.bin ===");
        Console.WriteLine();
        Console.WriteLine($"Reading: {pascalBin}");

        var pascalBytes = File.ReadAllBytes(pascalBin);
        Console.WriteLine($"  size: {pascalBytes.Length} bytes");

        if (!FastSerializer.IsFastSerialized(pascalBytes))
        {
            Console.Error.WriteLine("FAIL: pascal file does not have FastSerializer signature");
            return 2;
        }
        Console.WriteLine("  signature OK");

        var pascalDs = FastSerializer.DeSerializeDataSet(pascalBytes);
        if (pascalDs.Tables.Count != 1)
        {
            Console.Error.WriteLine(
                $"FAIL: expected 1 table, got {pascalDs.Tables.Count}");
            return 3;
        }

        var pascalTable = pascalDs.Tables[0];
        Console.WriteLine(
            $"  table='{pascalTable.TableName}' " +
            $"cols={pascalTable.Columns.Count} " +
            $"rows={pascalTable.Rows.Count}");

        // Re-build the reference dataset using the same routine that
        // generated dotnet_fixture.bin. If FixtureGen's BuildDataSet
        // changes, regenerate both fixtures from scratch.
        var refDs = BuildReferenceDataSet();
        var refTable = refDs.Tables[0];

        Console.WriteLine();
        Console.WriteLine("Comparing reference dataset (built in C#) vs " +
                          "dataset round-tripped through Pascal:");
        Console.WriteLine();

        int mismatches = 0;

        if (pascalTable.TableName != refTable.TableName)
        {
            Console.WriteLine($"  [MISMATCH] table name: " +
                              $"ref='{refTable.TableName}' " +
                              $"vs pascal='{pascalTable.TableName}'");
            mismatches++;
        }

        if (pascalTable.Columns.Count != refTable.Columns.Count)
        {
            Console.WriteLine($"  [MISMATCH] column count: " +
                              $"ref={refTable.Columns.Count} " +
                              $"vs pascal={pascalTable.Columns.Count}");
            mismatches++;
        }
        else
        {
            for (int i = 0; i < refTable.Columns.Count; i++)
            {
                if (refTable.Columns[i].ColumnName != pascalTable.Columns[i].ColumnName)
                {
                    Console.WriteLine(
                        $"  [MISMATCH] col[{i}] name: " +
                        $"ref='{refTable.Columns[i].ColumnName}' " +
                        $"vs pascal='{pascalTable.Columns[i].ColumnName}'");
                    mismatches++;
                }
            }
        }

        if (pascalTable.Rows.Count != refTable.Rows.Count)
        {
            Console.WriteLine($"  [MISMATCH] row count: " +
                              $"ref={refTable.Rows.Count} " +
                              $"vs pascal={pascalTable.Rows.Count}");
            mismatches++;
        }
        else
        {
            for (int r = 0; r < refTable.Rows.Count; r++)
            {
                for (int c = 0; c < refTable.Columns.Count; c++)
                {
                    object refVal = refTable.Rows[r][c];
                    object pascalVal = pascalTable.Rows[r][c];

                    if (!ValuesEqual(refVal, pascalVal))
                    {
                        Console.WriteLine(
                            $"  [MISMATCH] row {r} col '{refTable.Columns[c].ColumnName}': " +
                            $"ref={Format(refVal)} vs pascal={Format(pascalVal)}");
                        mismatches++;
                    }
                }
            }
        }

        Console.WriteLine();
        if (mismatches == 0)
        {
            Console.WriteLine("=== PASSED ===");
            Console.WriteLine($"All {refTable.Rows.Count} rows x " +
                              $"{refTable.Columns.Count} columns match.");
            return 0;
        }
        else
        {
            Console.WriteLine($"=== FAILED ({mismatches} mismatches) ===");
            return 10;
        }
    }

    static bool ValuesEqual(object a, object b)
    {
        // Both null or both DBNull -> equal.
        bool aNull = a == null || a == DBNull.Value;
        bool bNull = b == null || b == DBNull.Value;
        if (aNull && bNull) return true;
        if (aNull != bNull) return false;

        // Byte arrays need elementwise compare.
        if (a is byte[] ab && b is byte[] bb)
        {
            if (ab.Length != bb.Length) return false;
            for (int i = 0; i < ab.Length; i++)
                if (ab[i] != bb[i]) return false;
            return true;
        }

        // Floating-point: allow tiny FP rounding.
        if (a is double ad && b is double bd)
        {
            if (double.IsNaN(ad) && double.IsNaN(bd)) return true;
            if (double.IsInfinity(ad) || double.IsInfinity(bd))
                return ad == bd;
            double diff = Math.Abs(ad - bd);
            return diff <= Math.Max(Math.Abs(ad), Math.Abs(bd)) * 1e-12 ||
                   diff < 1e-300;
        }
        if (a is float af && b is float bf)
        {
            if (float.IsNaN(af) && float.IsNaN(bf)) return true;
            return af == bf;
        }

        return a.Equals(b);
    }

    static string Format(object v)
    {
        if (v == null || v == DBNull.Value) return "NULL";
        if (v is byte[] ba) return $"<{ba.Length}B>";
        if (v is string s) return $"\"{s}\"";
        if (v is DateTime dt) return dt.ToString("yyyy-MM-dd HH:mm:ss.fff");
        if (v is TimeSpan ts) return $"{ts.Ticks}ticks";
        return v.ToString() ?? "null";
    }

    // MUST mirror FixtureGen/Program.cs#BuildDataSet exactly.
    static DataSet BuildReferenceDataSet()
    {
        var ds = new DataSet("FastSerCrossTest");
        var t = new DataTable("AllTypes") { CaseSensitive = true };

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

        t.Rows.Add(
            42, 1234567890123L, (Int16)(-32000), (Byte)128, true,
            3.141592653589793, 2.71828f, 123.4567m, "Hello, Reportman!",
            new byte[] { 0xDE, 0xAD, 0xBE, 0xEF },
            new DateTime(2026, 5, 27, 12, 34, 56, 789),
            TimeSpan.FromTicks(123456789L), 'A');

        t.Rows.Add(
            Int32.MinValue, Int64.MinValue, Int16.MinValue, (Byte)0, false,
            -1.7976931348623157e+308, Single.MinValue, -987654321.4321m,
            "x", new byte[] { 0x00 },
            new DateTime(1900, 1, 1), TimeSpan.Zero, '\0');

        t.Rows.Add(
            Int32.MaxValue, Int64.MaxValue, Int16.MaxValue, (Byte)255, true,
            1.7976931348623157e+308, Single.MaxValue, 12345678.9012m,
            new string('z', 1000), BigByteBlob(256),
            new DateTime(9999, 12, 31, 23, 59, 59, 999),
            new TimeSpan(10, 20, 30), 'Z');

        var nullRow = t.NewRow();
        for (int i = 0; i < t.Columns.Count; i++) nullRow[i] = DBNull.Value;
        t.Rows.Add(nullRow);

        t.Rows.Add(
            0, 0L, (Int16)0, (Byte)0, false, 0.0, 0.0f, 0m,
            "Año Nuevo - Niño - café - 中文 - 🎉",
            new byte[] { 0x00, 0x01, 0x7F, 0x80, 0xFF },
            new DateTime(2000, 2, 29),
            TimeSpan.FromMilliseconds(1), 'ñ');

        t.Rows.Add(
            -1, -1L, (Int16)1, (Byte)1, true, 0.5, 0.5f, 0.0001m,
            " leading and trailing.", new byte[] { 0x42 },
            new DateTime(2026, 5, 27, 9, 15, 0),
            new TimeSpan(0, 0, 0, 0, 500), '!');

        ds.Tables.Add(t);
        return ds;
    }

    static byte[] BigByteBlob(int n)
    {
        var b = new byte[n];
        for (int i = 0; i < n; i++) b[i] = (byte)(i & 0xFF);
        return b;
    }
}
