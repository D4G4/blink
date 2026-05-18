namespace Blink.App.Logging;

/// <summary>
/// Lightweight file logger. Writes one line per call to
/// <c>%LOCALAPPDATA%\Blink\logs\YYYY-MM-DD.log</c>. Auto-prunes files older
/// than 14 days on first use to keep the folder bounded.
///
/// Format: <c>HH:mm:ss.fff [level] message</c>
/// </summary>
public static class Log
{
    private static readonly object Gate = new();
    private static bool _prunedThisSession;

    public static string LogsDirectory { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Blink", "logs");

    private static string TodayPath =>
        Path.Combine(LogsDirectory, $"{DateTime.Now:yyyy-MM-dd}.log");

    public static void Info(string message) => Write("INFO", message);
    public static void Warn(string message) => Write("WARN", message);
    public static void Error(string message) => Write("ERR ", message);

    public static void Error(string message, Exception ex) =>
        Write("ERR ", $"{message}: {ex.GetType().FullName}: {ex.Message}\n{ex.StackTrace}");

    private static void Write(string level, string message)
    {
        try
        {
            lock (Gate)
            {
                Directory.CreateDirectory(LogsDirectory);
                if (!_prunedThisSession) { PruneOld(); _prunedThisSession = true; }
                File.AppendAllText(TodayPath, $"{DateTime.Now:HH:mm:ss.fff} [{level}] {message}\n");
            }
        }
        catch { /* logging must never throw into caller */ }
    }

    private static void PruneOld()
    {
        try
        {
            var cutoff = DateTime.Now.AddDays(-14);
            foreach (var f in Directory.EnumerateFiles(LogsDirectory, "*.log"))
            {
                try { if (File.GetLastWriteTime(f) < cutoff) File.Delete(f); } catch { }
            }
        }
        catch { }
    }
}
