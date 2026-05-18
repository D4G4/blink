using System.Text.Json;

namespace Blink.App.GaborExercise;

public record GaborSessionRecord(
    DateTime Date,
    string ExerciseType,
    int TrialCount,
    int CorrectCount,
    double? ContrastThreshold,
    double DurationSeconds);

/// <summary>
/// Persists Gabor exercise session records as JSON in
/// <c>%LOCALAPPDATA%\Blink\GaborSessions\</c>, one file per day.
/// </summary>
public sealed class GaborSessionStore
{
    public static GaborSessionStore Instance { get; } = new();

    private readonly string _directory;

    private GaborSessionStore()
    {
        _directory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Blink", "GaborSessions");
        Directory.CreateDirectory(_directory);
    }

    public void Save(GaborSessionRecord record)
    {
        var fileName = record.Date.ToString("yyyy-MM-dd") + ".json";
        var path = Path.Combine(_directory, fileName);
        var records = LoadRecords(path);
        records.Add(record);

        try
        {
            File.WriteAllText(path, JsonSerializer.Serialize(records, JsonOptions));
        }
        catch { /* best-effort persistence */ }
    }

    public List<GaborSessionRecord> LoadAll()
    {
        if (!Directory.Exists(_directory)) return new List<GaborSessionRecord>();
        return Directory.EnumerateFiles(_directory, "*.json")
            .OrderBy(p => Path.GetFileName(p))
            .SelectMany(LoadRecords)
            .ToList();
    }

    public List<GaborSessionRecord> LoadRecent(int days = 30)
    {
        var cutoff = DateTime.Now.AddDays(-days);
        return LoadAll().Where(r => r.Date >= cutoff).ToList();
    }

    public int SessionsThisWeek()
    {
        var weekStart = DateTime.Today.AddDays(-(int)DateTime.Today.DayOfWeek);
        return LoadAll().Count(r => r.Date >= weekStart);
    }

    public double? BestThreshold(string exerciseType) =>
        LoadAll()
            .Where(r => r.ExerciseType == exerciseType && r.ContrastThreshold.HasValue)
            .Select(r => r.ContrastThreshold!.Value)
            .DefaultIfEmpty()
            .Min() is var v && v > 0 ? v : null;

    private static List<GaborSessionRecord> LoadRecords(string path)
    {
        try
        {
            if (!File.Exists(path)) return new();
            var text = File.ReadAllText(path);
            return JsonSerializer.Deserialize<List<GaborSessionRecord>>(text, JsonOptions) ?? new();
        }
        catch { return new(); }
    }

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };
}
