// Blink App Store screenshot — shot 7: Eye Exercise (Gabor patches)
// Built from the visible Eye-Exercise selection screen in the supplied
// product screenshot. Only uses UI elements that are observable there:
//   - Title: "Eye Exercise"
//   - Subtitle: "Train your visual cortex with Gabor patch exercises"
//   - 3 selection cards:
//       Contrast Detection  · "Spot the Hidden Pattern"
//       Orientation         · "Read the Tilt"
//       Flanker Masking     · "Focus Through Distractions"
//   - Green "Continue" button
// The Gabor patch hero visual is a literal sinusoidal grating in a
// Gaussian envelope — a mathematical primitive, not invented UI.
// "Beta" badge added to mirror the menu-bar treatment per the request.

function Shot7Exercise({ copy }) {
  // Sage theme dark mode — matches the dark Eye Exercise screen in the
  // product screenshots (which is near-black w/ green accents).
  const accent = '#3DCC83'; // matches the bright green Continue button in the screenshot
  return (
    <div style={{
      width: 2880, height: 1800, position: 'relative', overflow: 'hidden',
      background: '#0A0F0B', fontFamily: FONT_STACK, color: '#fff',
    }}>
      {/* faint accent glow */}
      <div style={{
        position: 'absolute', inset: 0,
        background: `radial-gradient(ellipse at 30% 20%, ${hexAlpha(accent, 0.18)}, transparent 55%)`,
      }} />

      {/* Marketing header */}
      <div style={{
        textAlign: 'center', paddingTop: 120, paddingLeft: 200, paddingRight: 200,
      }}>
        <div style={{
          fontSize: 132, fontWeight: 700, letterSpacing: '-0.035em',
          color: '#fff', lineHeight: 0.98, textWrap: 'balance',
        }}>{copy.t7}
          {/* inline beta pill */}
          <span style={{
            display: 'inline-block', marginLeft: 28, transform: 'translateY(-22px)',
            fontSize: 32, fontWeight: 700, letterSpacing: '0.12em',
            padding: '10px 22px', borderRadius: 999,
            background: hexAlpha(accent, 0.18), color: accent,
            border: `1.5px solid ${hexAlpha(accent, 0.5)}`,
            verticalAlign: 'middle',
          }}>BETA</span>
        </div>
        <div style={{
          marginTop: 36, fontSize: 50, fontWeight: 400,
          color: 'rgba(255,255,255,0.65)', letterSpacing: '-0.012em',
          maxWidth: 2200, marginLeft: 'auto', marginRight: 'auto', textWrap: 'balance', lineHeight: 1.2,
        }}>{copy.s7}</div>
      </div>

      {/* Body: left = giant Gabor patch hero; right = real selection UI */}
      <div style={{
        position: 'absolute', left: 180, right: 180, top: 740, bottom: 140,
        display: 'grid', gridTemplateColumns: '1fr 1.05fr', gap: 80, alignItems: 'center',
      }}>
        {/* Gabor patch on a soft circular surface */}
        <div style={{
          position: 'relative', aspectRatio: '1 / 1', maxHeight: 820,
          margin: '0 auto', width: '100%',
        }}>
          <div style={{
            position: 'absolute', inset: 0, borderRadius: '50%',
            background: 'radial-gradient(circle at 50% 50%, #1a221c, #0a0f0b 70%)',
            boxShadow: `0 30px 100px ${hexAlpha(accent, 0.22)}, inset 0 0 0 1px rgba(255,255,255,0.05)`,
          }} />
          <div style={{ position: 'absolute', inset: '8%' }}>
            <GaborPatch size="100%" />
          </div>
          {/* small caption */}
          <div style={{
            position: 'absolute', bottom: 24, left: 0, right: 0,
            textAlign: 'center', fontSize: 22, color: 'rgba(255,255,255,0.5)',
            letterSpacing: '0.16em', textTransform: 'uppercase', fontWeight: 500,
          }}>Gabor patch \u00b7 contrast detection</div>
        </div>

        {/* Selection UI \u2014 mirrors the screen in the product screenshot */}
        <div style={{
          background: '#15181A',
          border: '1px solid rgba(255,255,255,0.06)',
          borderRadius: 32, padding: '60px 56px',
          boxShadow: '0 40px 100px rgba(0,0,0,0.5)',
        }}>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: 52, fontWeight: 700, letterSpacing: '-0.02em' }}>Eye Exercise</div>
            <div style={{
              marginTop: 12, fontSize: 22, color: 'rgba(255,255,255,0.6)',
            }}>Train your visual cortex with Gabor patch exercises</div>
          </div>

          {/* 3 exercise cards */}
          <div style={{
            display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 20, marginTop: 44,
          }}>
            <ExerciseCard
              title="Contrast Detection"
              sub="Spot the Hidden Pattern"
              icon={<MiniGabor />}
              active={true}
              accent={accent}
            />
            <ExerciseCard
              title="Orientation"
              sub="Read the Tilt"
              icon={<TiltIcon />}
              active={false}
              accent={accent}
            />
            <ExerciseCard
              title="Flanker Masking"
              sub="Focus Through Distractions"
              icon={<GridIcon />}
              active={false}
              accent={accent}
            />
          </div>

          {/* Continue button */}
          <div style={{ display: 'flex', justifyContent: 'center', marginTop: 44 }}>
            <button style={{
              padding: '20px 80px', borderRadius: 12, border: 'none',
              background: accent, color: '#0A0F0B',
              fontSize: 26, fontWeight: 600, fontFamily: FONT_STACK,
              boxShadow: `0 12px 30px ${hexAlpha(accent, 0.4)}`,
            }}>Continue</button>
          </div>

          <div style={{
            marginTop: 24, textAlign: 'center', fontSize: 18,
            color: 'rgba(255,255,255,0.4)',
          }}>
            2 minute session \u00b7 Optional during breaks
          </div>
        </div>
      </div>
    </div>
  );
}

function ExerciseCard({ title, sub, icon, active, accent }) {
  return (
    <div style={{
      borderRadius: 16, padding: '24px 18px',
      background: active ? hexAlpha(accent, 0.10) : 'rgba(255,255,255,0.04)',
      border: active ? `2px solid ${accent}` : '2px solid rgba(255,255,255,0.06)',
      display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', gap: 14,
    }}>
      <div style={{
        width: 60, height: 60, borderRadius: 14,
        background: active ? hexAlpha(accent, 0.18) : 'rgba(255,255,255,0.06)',
        color: active ? accent : 'rgba(255,255,255,0.8)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>{icon}</div>
      <div>
        <div style={{ fontSize: 20, fontWeight: 600, color: '#fff', letterSpacing: '-0.005em' }}>{title}</div>
        <div style={{ fontSize: 15, color: 'rgba(255,255,255,0.55)', marginTop: 4 }}>{sub}</div>
      </div>
    </div>
  );
}

// A real Gabor patch: sinusoidal grating × Gaussian envelope.
// Rendered procedurally as SVG so it's resolution-independent.
function GaborPatch({ size = '100%', orientation = 25, frequency = 14 }) {
  // We sample horizontal bars at varying opacity to approximate a grating;
  // the Gaussian envelope is a radial mask.
  const id = React.useId();
  const bars = [];
  const N = 80;
  for (let i = 0; i < N; i++) {
    const phase = (i / N) * Math.PI * 2 * frequency / 6;
    const v = (Math.sin(phase) + 1) / 2; // 0..1
    bars.push(v);
  }
  return (
    <svg width={size} height={size} viewBox="0 0 400 400" style={{ display: 'block' }}>
      <defs>
        <radialGradient id={`env-${id}`} cx="50%" cy="50%" r="50%">
          <stop offset="0" stopColor="#fff" stopOpacity="1" />
          <stop offset="0.5" stopColor="#fff" stopOpacity="0.85" />
          <stop offset="0.85" stopColor="#fff" stopOpacity="0.15" />
          <stop offset="1" stopColor="#fff" stopOpacity="0" />
        </radialGradient>
        <mask id={`mask-${id}`}>
          <rect width="400" height="400" fill={`url(#env-${id})`} />
        </mask>
        <linearGradient id={`grating-${id}`} x1="0" y1="0" x2="0" y2="1" gradientTransform={`rotate(${orientation} 0.5 0.5)`}>
          {Array.from({ length: 30 }).map((_, i) => {
            const t = i / 29;
            const v = (Math.sin(t * Math.PI * 2 * 6) + 1) / 2;
            return <stop key={i} offset={t} stopColor={`rgb(${Math.round(v * 255)},${Math.round(v * 255)},${Math.round(v * 255)})`} />;
          })}
        </linearGradient>
      </defs>
      <rect width="400" height="400" fill="#0a0f0b" />
      <rect width="400" height="400" fill={`url(#grating-${id})`} mask={`url(#mask-${id})`} />
    </svg>
  );
}

function MiniGabor() {
  return (
    <svg width="32" height="32" viewBox="0 0 32 32">
      <defs>
        <radialGradient id="mg-env" cx="50%" cy="50%" r="50%">
          <stop offset="0" stopColor="#fff" stopOpacity="1" />
          <stop offset="0.7" stopColor="#fff" stopOpacity="0.4" />
          <stop offset="1" stopColor="#fff" stopOpacity="0" />
        </radialGradient>
        <mask id="mg-m"><rect width="32" height="32" fill="url(#mg-env)" /></mask>
        <linearGradient id="mg-g" gradientTransform="rotate(25 0.5 0.5)">
          <stop offset="0"   stopColor="#000" />
          <stop offset="0.2" stopColor="#fff" />
          <stop offset="0.4" stopColor="#000" />
          <stop offset="0.6" stopColor="#fff" />
          <stop offset="0.8" stopColor="#000" />
          <stop offset="1"   stopColor="#fff" />
        </linearGradient>
      </defs>
      <circle cx="16" cy="16" r="14" fill="#0a0f0b" />
      <rect width="32" height="32" fill="url(#mg-g)" mask="url(#mg-m)" />
    </svg>
  );
}

function TiltIcon() {
  return (
    <svg width="32" height="32" viewBox="0 0 32 32" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
      <path d="M6 26 L26 6" />
      <path d="M6 26 L14 24" />
      <path d="M6 26 L8 18" />
    </svg>
  );
}

function GridIcon() {
  return (
    <svg width="32" height="32" viewBox="0 0 32 32" fill="currentColor">
      {[6, 16, 26].map(y => [6, 16, 26].map(x => (
        <circle key={`${x}-${y}`} cx={x} cy={y} r={x === 16 && y === 16 ? 2.5 : 2} opacity={x === 16 && y === 16 ? 1 : 0.45} />
      )))}
    </svg>
  );
}

Object.assign(window, { Shot7Exercise });
