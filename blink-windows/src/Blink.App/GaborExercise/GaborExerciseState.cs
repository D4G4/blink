using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace Blink.App.GaborExercise;

public enum ExerciseType
{
    ContrastDetection,
    OrientationDiscrimination,
    FlankerMasking,
}

public static class ExerciseTypeExtensions
{
    public static string DisplayName(this ExerciseType t) => t switch
    {
        ExerciseType.ContrastDetection => "Contrast Detection",
        ExerciseType.OrientationDiscrimination => "Orientation",
        ExerciseType.FlankerMasking => "Flanker Masking",
        _ => t.ToString()
    };

    /// <summary>Segoe Fluent Icons glyph approximating the macOS SF Symbol.</summary>
    public static string IconGlyph(this ExerciseType t) => t switch
    {
        ExerciseType.ContrastDetection => "",        // PieSingle (close-ish to circle.lefthalf)
        ExerciseType.OrientationDiscrimination => "", // FullScreen (diagonal arrows)
        ExerciseType.FlankerMasking => "",            // ViewAll (grid)
        _ => ""
    };

    public static string Headline(this ExerciseType t) => t switch
    {
        ExerciseType.ContrastDetection => "Spot the Hidden Pattern",
        ExerciseType.OrientationDiscrimination => "Read the Tilt",
        ExerciseType.FlankerMasking => "Focus Through Distractions",
        _ => ""
    };

    public static string Explanation(this ExerciseType t) => t switch
    {
        ExerciseType.ContrastDetection =>
            "Two circles appear on a gray background — one contains a faint striped " +
            "pattern (a Gabor patch), the other is plain gray. Your job is to click " +
            "the circle that contains the pattern.\n\n" +
            "As you get better, the pattern becomes fainter, training your brain to " +
            "detect subtler contrasts. This is the most studied form of contrast " +
            "sensitivity training and the foundation of visual perceptual learning.",
        ExerciseType.OrientationDiscrimination =>
            "A single striped pattern appears in the center of the screen, tilted " +
            "slightly to the left or to the right. Click the direction it's tilting.\n\n" +
            "The pattern gets fainter as you improve, training your visual cortex to " +
            "extract orientation information from weaker signals. This strengthens the " +
            "same neural pathways used when reading small text or distinguishing fine details.",
        ExerciseType.FlankerMasking =>
            "Three striped patterns appear in a row. The two outer patterns (flankers) " +
            "are bold and vertical. The center pattern is faint and tilted slightly left " +
            "or right. Your task: identify which way the center pattern tilts, while " +
            "ignoring the flankers.\n\n" +
            "This is the hardest exercise. The flankers create lateral masking — they " +
            "interfere with your ability to see the center target. Training with flankers " +
            "improves your brain's ability to focus on relevant details while filtering " +
            "out visual noise. This is especially helpful for crowded scenes like reading dense text.",
        _ => ""
    };

    public static string HowToPlay(this ExerciseType t) => t switch
    {
        ExerciseType.ContrastDetection => "Click the circle that contains the pattern — left or right.",
        ExerciseType.OrientationDiscrimination => "Click \"Tilted Left\" or \"Tilted Right\" to match the pattern's tilt.",
        ExerciseType.FlankerMasking => "Ignore the outer patterns. Click the tilt direction of the center pattern.",
        _ => ""
    };
}

public enum ExercisePhase
{
    Disclaimer,
    Ready,
    Instructions,
    Presenting,
    FeedbackCorrect,
    FeedbackIncorrect,
    Complete,
}

/// <summary>
/// Drives a Gabor exercise session — trials, scoring, and the adaptive staircase.
/// Port of macOS GaborExerciseState.
/// </summary>
public sealed class GaborExerciseState : INotifyPropertyChanged
{
    private const string DisclaimerSettingKey = "gaborDisclaimerAccepted";

    private ExerciseType _exerciseType = ExerciseType.ContrastDetection;
    private ExercisePhase _phase;
    private int _currentTrial;
    private int _score;
    private int _targetPosition;            // 0 = left, 1 = right (contrast)
    private double _targetOrientation;      // radians
    private int _flankerDistanceLevel = 1;  // 0/1/2

    public AdaptiveStaircase Staircase { get; } = new();
    public int TotalTrials { get; }

    public ExerciseType ExerciseType { get => _exerciseType; set => Set(ref _exerciseType, value); }
    public ExercisePhase Phase { get => _phase; set => Set(ref _phase, value); }
    public int CurrentTrial { get => _currentTrial; private set => Set(ref _currentTrial, value); }
    public int Score { get => _score; private set => Set(ref _score, value); }
    public int TargetPosition { get => _targetPosition; private set => Set(ref _targetPosition, value); }
    public double TargetOrientation { get => _targetOrientation; private set => Set(ref _targetOrientation, value); }
    public int FlankerDistanceLevel { get => _flankerDistanceLevel; private set => Set(ref _flankerDistanceLevel, value); }

    private DateTime? _sessionStart;
    private System.Threading.Timer? _feedbackTimer;
    private readonly Random _rng = new();

    public GaborExerciseState(int totalTrials = 25)
    {
        TotalTrials = totalTrials;
        _phase = DisclaimerAccepted() ? ExercisePhase.Ready : ExercisePhase.Disclaimer;
    }

    public void AcceptDisclaimer()
    {
        SetDisclaimerAccepted();
        Phase = ExercisePhase.Ready;
    }

    public void ShowDisclaimer() => Phase = ExercisePhase.Disclaimer;
    public void ShowInstructions() => Phase = ExercisePhase.Instructions;

    public void StartExercise()
    {
        CurrentTrial = 0;
        Score = 0;
        Staircase.Reset();
        _sessionStart = DateTime.UtcNow;
        GenerateTrial();
    }

    public void GenerateTrial()
    {
        CurrentTrial++;
        switch (ExerciseType)
        {
            case ExerciseType.ContrastDetection:
                TargetPosition = _rng.Next(0, 2);
                break;
            case ExerciseType.OrientationDiscrimination:
                TargetOrientation = (_rng.Next(0, 2) == 0 ? 15 : -15) * Math.PI / 180.0;
                break;
            case ExerciseType.FlankerMasking:
                TargetOrientation = (_rng.Next(0, 2) == 0 ? 15 : -15) * Math.PI / 180.0;
                FlankerDistanceLevel = _rng.Next(0, 3);
                break;
        }
        Phase = ExercisePhase.Presenting;
    }

    /// <summary>
    /// Contrast detection: 0 = left, 1 = right.
    /// Orientation/Flanker: 0 = tilted left, 1 = tilted right.
    /// </summary>
    public void SubmitResponse(int response)
    {
        if (Phase != ExercisePhase.Presenting) return;

        bool correct = ExerciseType switch
        {
            ExerciseType.ContrastDetection => response == TargetPosition,
            // Positive orientation angle → stripes lean left visually
            _ => response == (TargetOrientation > 0 ? 0 : 1),
        };

        if (correct) Score++;
        Staircase.RecordResponse(correct);
        Phase = correct ? ExercisePhase.FeedbackCorrect : ExercisePhase.FeedbackIncorrect;

        _feedbackTimer?.Dispose();
        _feedbackTimer = new System.Threading.Timer(_ => AdvanceAfterFeedback(),
            null, 500, System.Threading.Timeout.Infinite);
    }

    public Action<Action>? PostToUi { get; set; }  // dispatcher hook set by view

    private void AdvanceAfterFeedback()
    {
        var advance = (Action)(() =>
        {
            if (CurrentTrial >= TotalTrials) CompleteSession();
            else GenerateTrial();
        });
        if (PostToUi != null) PostToUi(advance); else advance();
    }

    private void CompleteSession()
    {
        Phase = ExercisePhase.Complete;
        SaveSession();
    }

    public void SaveSession()
    {
        var duration = _sessionStart.HasValue ? (DateTime.UtcNow - _sessionStart.Value).TotalSeconds : 0;
        var record = new GaborSessionRecord(
            Date: DateTime.Now,
            ExerciseType: ExerciseType.DisplayName(),
            TrialCount: CurrentTrial,
            CorrectCount: Score,
            ContrastThreshold: Staircase.Threshold(),
            DurationSeconds: duration);
        GaborSessionStore.Instance.Save(record);
    }

    /// <summary>Save partial results and reset for a clean state.</summary>
    public void CancelSession()
    {
        _feedbackTimer?.Dispose();
        if (CurrentTrial > 0) SaveSession();
    }

    public int AccuracyPercent =>
        CurrentTrial == 0 ? 0 : (int)Math.Round((double)Score / CurrentTrial * 100);

    public string ThresholdDisplay =>
        Staircase.Threshold() is double t ? $"{t * 100:F1}%" : "—";

    // --- Disclaimer persistence (simple flat file alongside settings.json) ---
    private static string SettingsDir =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Blink");

    private static string DisclaimerFile => Path.Combine(SettingsDir, "gabor_disclaimer.flag");

    private static bool DisclaimerAccepted() => File.Exists(DisclaimerFile);

    private static void SetDisclaimerAccepted()
    {
        try { Directory.CreateDirectory(SettingsDir); File.WriteAllText(DisclaimerFile, "1"); } catch { }
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    private void Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
