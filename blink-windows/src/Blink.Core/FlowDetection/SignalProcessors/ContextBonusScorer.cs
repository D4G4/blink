namespace Blink.Core.FlowDetection.SignalProcessors;

public sealed class ContextBonusScorer
{
    private enum AppCategory { Creative, Neutral, Consumption }

    private static readonly Dictionary<string, AppCategory> ProcessCategories = new(StringComparer.OrdinalIgnoreCase)
    {
        // Creative — IDEs, editors, terminals
        ["devenv"] = AppCategory.Creative,           // Visual Studio
        ["Code"] = AppCategory.Creative,             // VS Code
        ["Cursor"] = AppCategory.Creative,
        ["rider64"] = AppCategory.Creative,          // JetBrains Rider
        ["idea64"] = AppCategory.Creative,           // IntelliJ
        ["pycharm64"] = AppCategory.Creative,
        ["goland64"] = AppCategory.Creative,
        ["webstorm64"] = AppCategory.Creative,
        ["WindowsTerminal"] = AppCategory.Creative,
        ["powershell"] = AppCategory.Creative,
        ["cmd"] = AppCategory.Creative,
        ["notepad++"] = AppCategory.Creative,
        ["sublime_text"] = AppCategory.Creative,
        ["figma"] = AppCategory.Creative,
        ["Photoshop"] = AppCategory.Creative,
        ["Illustrator"] = AppCategory.Creative,

        // Consumption — chat, email, social
        ["slack"] = AppCategory.Consumption,
        ["Teams"] = AppCategory.Consumption,
        ["ms-teams"] = AppCategory.Consumption,
        ["OUTLOOK"] = AppCategory.Consumption,
        ["Telegram"] = AppCategory.Consumption,
        ["Discord"] = AppCategory.Consumption,
        ["WhatsApp"] = AppCategory.Consumption,
    };

    public double Score(string? frontmostProcessName)
    {
        if (string.IsNullOrEmpty(frontmostProcessName)) return 0.5;

        if (ProcessCategories.TryGetValue(frontmostProcessName, out var category))
        {
            return category switch
            {
                AppCategory.Creative => 1.0,
                AppCategory.Neutral => 0.5,
                AppCategory.Consumption => 0.2,
                _ => 0.5
            };
        }

        // Heuristic: JetBrains apps
        if (frontmostProcessName.Contains("jetbrains", StringComparison.OrdinalIgnoreCase))
            return 1.0;

        // Browsers are neutral
        if (frontmostProcessName.Contains("chrome", StringComparison.OrdinalIgnoreCase) ||
            frontmostProcessName.Contains("firefox", StringComparison.OrdinalIgnoreCase) ||
            frontmostProcessName.Contains("msedge", StringComparison.OrdinalIgnoreCase) ||
            frontmostProcessName.Contains("brave", StringComparison.OrdinalIgnoreCase))
            return 0.5;

        return 0.5; // unknown = neutral
    }
}
