namespace Blink.App.GaborExercise;

/// <summary>
/// 2-down-1-up adaptive staircase for measuring contrast thresholds.
/// Converges to the 70.7% correct threshold — a standard psychophysical measurement.
/// Step size halves at each reversal for finer resolution as the staircase homes in.
/// </summary>
public sealed class AdaptiveStaircase
{
    public record struct TrialResult(double Contrast, bool Correct);

    private enum Direction { Up, Down }

    private const double MinContrast = 0.01;
    private const double MaxContrast = 1.0;
    private const double MinStep = 0.005;

    public double CurrentContrast { get; private set; }
    public IReadOnlyList<TrialResult> TrialResults => _trialResults;
    public int ReversalCount => _reversals.Count;

    private double _stepSize;
    private int _consecutiveCorrect;
    private Direction? _lastDirection;
    private readonly List<double> _reversals = new();
    private readonly List<TrialResult> _trialResults = new();

    public AdaptiveStaircase(double startContrast = 0.5, double initialStep = 0.05)
    {
        CurrentContrast = startContrast;
        _stepSize = initialStep;
    }

    public void RecordResponse(bool correct)
    {
        _trialResults.Add(new TrialResult(CurrentContrast, correct));

        if (correct)
        {
            _consecutiveCorrect++;
            if (_consecutiveCorrect >= 2)
            {
                _consecutiveCorrect = 0;
                CurrentContrast = Math.Max(CurrentContrast - _stepSize, MinContrast);
                if (_lastDirection == Direction.Up)
                {
                    _reversals.Add(CurrentContrast);
                    _stepSize = Math.Max(_stepSize * 0.5, MinStep);
                }
                _lastDirection = Direction.Down;
            }
        }
        else
        {
            _consecutiveCorrect = 0;
            CurrentContrast = Math.Min(CurrentContrast + _stepSize, MaxContrast);
            if (_lastDirection == Direction.Down)
            {
                _reversals.Add(CurrentContrast);
                _stepSize = Math.Max(_stepSize * 0.5, MinStep);
            }
            _lastDirection = Direction.Up;
        }
    }

    /// <summary>Estimated contrast threshold from reversal values. Null if insufficient data.</summary>
    public double? Threshold()
    {
        if (_reversals.Count >= 6)
            return _reversals.TakeLast(6).Average();
        if (_reversals.Count >= 2)
            return _reversals.Average();
        return null;
    }

    public void Reset()
    {
        CurrentContrast = 0.5;
        _stepSize = 0.05;
        _consecutiveCorrect = 0;
        _lastDirection = null;
        _reversals.Clear();
        _trialResults.Clear();
    }
}
