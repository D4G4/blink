using System.ComponentModel;
using System.Net.Http;
using System.Runtime.CompilerServices;
using System.Text.Json;

namespace Blink.App;

/// <summary>
/// Checks GitHub releases for newer versions.
/// Port of macOS UpdateChecker.swift.
/// </summary>
public sealed class UpdateChecker : INotifyPropertyChanged
{
    public static UpdateChecker Instance { get; } = new();

    // -- CheckResult ----------------------------------------------------------

    public enum CheckResultKind { UpToDate, Available, Failed }

    public sealed record CheckResult(CheckResultKind Kind, string? AvailableVersion = null)
    {
        public static CheckResult UpToDate => new(CheckResultKind.UpToDate);
        public static CheckResult Available(string version) => new(CheckResultKind.Available, version);
        public static CheckResult Failed => new(CheckResultKind.Failed);
    }

    // -- Observable properties ------------------------------------------------

    private bool _updateAvailable;
    public bool UpdateAvailable
    {
        get => _updateAvailable;
        private set => Set(ref _updateAvailable, value);
    }

    private string? _latestVersion;
    public string? LatestVersion
    {
        get => _latestVersion;
        private set => Set(ref _latestVersion, value);
    }

    private string? _downloadUrl;
    public string? DownloadUrl
    {
        get => _downloadUrl;
        private set => Set(ref _downloadUrl, value);
    }

    private bool _isChecking;
    public bool IsChecking
    {
        get => _isChecking;
        private set => Set(ref _isChecking, value);
    }

    private CheckResult? _lastCheckResult;
    public CheckResult? LastCheckResult
    {
        get => _lastCheckResult;
        private set => Set(ref _lastCheckResult, value);
    }

    // -- Internals ------------------------------------------------------------

    private static readonly string CurrentVersion =
        typeof(UpdateChecker).Assembly.GetName().Version?.ToString(3) ?? "1.0.0";

    private const string ReleasesUrl =
        "https://api.github.com/repos/D4G4/blink/releases/latest";

    private static readonly HttpClient Http = new()
    {
        Timeout = TimeSpan.FromSeconds(10),
        DefaultRequestHeaders =
        {
            { "Accept", "application/vnd.github+json" },
            { "User-Agent", "Blink-Windows-UpdateChecker" }
        }
    };

    private System.Threading.Timer? _periodicTimer;

    // -- Public API -----------------------------------------------------------

    public void StartPeriodicChecks()
    {
        CheckForUpdate();
        _periodicTimer = new System.Threading.Timer(
            _ => CheckForUpdate(),
            null,
            TimeSpan.FromMilliseconds(86_400_000),
            TimeSpan.FromMilliseconds(86_400_000));
    }

    public async void CheckForUpdate()
    {
        IsChecking = true;
        LastCheckResult = null;

        try
        {
            var json = await Http.GetStringAsync(ReleasesUrl);
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            if (!root.TryGetProperty("tag_name", out var tagProp))
            {
                IsChecking = false;
                LastCheckResult = CheckResult.Failed;
                return;
            }

            var latest = tagProp.GetString()?.Replace("v", "") ?? "";
            var current = CurrentVersion;

            if (IsNewer(latest, current))
            {
                LatestVersion = latest;
                UpdateAvailable = true;
                LastCheckResult = CheckResult.Available(latest);

                // Look for .exe or .msi asset
                if (root.TryGetProperty("assets", out var assets))
                {
                    foreach (var asset in assets.EnumerateArray())
                    {
                        if (asset.TryGetProperty("name", out var nameProp))
                        {
                            var name = nameProp.GetString() ?? "";
                            if (name.EndsWith(".exe") || name.EndsWith(".msi"))
                            {
                                if (asset.TryGetProperty("browser_download_url", out var urlProp))
                                {
                                    DownloadUrl = urlProp.GetString();
                                    break;
                                }
                            }
                        }
                    }
                }

                // Fallback to release page
                if (DownloadUrl == null && root.TryGetProperty("html_url", out var htmlUrl))
                {
                    DownloadUrl = htmlUrl.GetString();
                }
            }
            else
            {
                LastCheckResult = CheckResult.UpToDate;
            }
        }
        catch
        {
            LastCheckResult = CheckResult.Failed;
        }

        IsChecking = false;
    }

    // -- Semver comparison ----------------------------------------------------

    internal static bool IsNewer(string a, string b)
    {
        var aParts = a.Split('.').Select(s => int.TryParse(s, out var n) ? n : 0).ToArray();
        var bParts = b.Split('.').Select(s => int.TryParse(s, out var n) ? n : 0).ToArray();

        var len = Math.Max(aParts.Length, bParts.Length);
        for (var i = 0; i < len; i++)
        {
            var av = i < aParts.Length ? aParts[i] : 0;
            var bv = i < bParts.Length ? bParts[i] : 0;
            if (av > bv) return true;
            if (av < bv) return false;
        }
        return false;
    }

    // -- INotifyPropertyChanged -----------------------------------------------

    public event PropertyChangedEventHandler? PropertyChanged;

    private void Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
