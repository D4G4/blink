using System.Text.Json;
using Blink.Core.Compliance;

namespace Blink.App.Persistence;

/// <summary>
/// Saves break history as daily JSON files in %LOCALAPPDATA%\Blink\.
/// </summary>
public sealed class PersistenceManager
{
    private readonly string _baseDir;

    public PersistenceManager()
    {
        _baseDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Blink");
        Directory.CreateDirectory(_baseDir);
    }

    public void SaveBreakRecord(BreakRecord record)
    {
        var records = LoadTodayRecords();
        records.Add(record);

        var path = PathForDate(DateTime.Today);
        var json = JsonSerializer.Serialize(records, JsonOptions);
        File.WriteAllText(path, json);
    }

    public List<BreakRecord> LoadTodayRecords() => LoadRecords(DateTime.Today);

    public List<BreakRecord> LoadRecords(DateTime date)
    {
        var path = PathForDate(date);
        if (!File.Exists(path)) return [];

        try
        {
            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<List<BreakRecord>>(json, JsonOptions) ?? [];
        }
        catch
        {
            return [];
        }
    }

    public void PruneOldRecords(int olderThanDays = 30)
    {
        var cutoff = DateTime.Today.AddDays(-olderThanDays);
        foreach (var file in Directory.GetFiles(_baseDir, "*.json"))
        {
            var name = Path.GetFileNameWithoutExtension(file);
            if (DateTime.TryParse(name, out var date) && date < cutoff)
                File.Delete(file);
        }
    }

    private string PathForDate(DateTime date) =>
        Path.Combine(_baseDir, $"{date:yyyy-MM-dd}.json");

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = false,
        Converters = { new System.Text.Json.Serialization.JsonStringEnumConverter() }
    };
}
