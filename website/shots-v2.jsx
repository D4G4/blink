// Blink App Store screenshots — v2: editorial / optometric direction.
// Less "marketing tagline on a gradient over an app screenshot" and more
// "Swiss optometry poster meets museum catalogue plate". 2880×1800 each.

const V2W = 2880,V2H = 1800;

const V2 = {
  // Brand peach paper — matches THEMES.peach.light.overlayBg (#FFF0E8),
  // nudged slightly punchier so it reads as brand on a flat surface.
  paper: '#FFE9D6',
  paperHi: '#FFF5E9',
  ink: '#2A1408', // brand peach dark — from THEMES.peach.dark.bg[0]
  inkMute: 'rgba(42,20,8,0.58)',
  inkSoft: 'rgba(42,20,8,0.34)',
  hair: 'rgba(180,90,50,0.26)', // deeper peach hairline
  hairSoft: 'rgba(180,90,50,0.12)',
  peach: '#E88565',
  peachDeep: '#C5694C',
  sage: '#6EA87E',
  sand: '#9A9478',
  midnight: '#2B2D52',
  monoSwatch: '#222222',
  night: '#0E0B08'
};

// Headlines: SF Pro Rounded for friendliness, falling back to Display.
const HEAD = `ui-rounded, "SF Pro Rounded", "Nunito", -apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", "Helvetica", system-ui, sans-serif`;

// ── Plate chrome ───────────────────────────────────────────────────────────
// Every shot is presented like a numbered plate from a printed catalogue.
function PlateChrome({ index, total = 7, accent = V2.peach, dark = false, bottomLeft, bottomRight, themeKey = 'peach', themeMode = 'light' }) {
  const ink = dark ? '#F4EADB' : V2.ink;
  const mute = dark ? 'rgba(244,234,219,0.55)' : V2.inkMute;
  const hair = dark ? 'rgba(244,234,219,0.18)' : V2.hair;
  const pad = 64;
  const t = (s) => ({
    fontFamily: MONO_STACK, fontSize: 22, letterSpacing: '0.18em', textTransform: 'uppercase',
    color: mute, fontWeight: 500
  });
  // Screenshot / press-kit chrome (plate number, field-guide header, corner
  // annotations) removed: on the website each shot is a full-bleed section,
  // not a framed catalogue plate.
  return null;
}

// Display headline w/ optometric small-caps caption above + caption below.
function PlateHead({ caption, head, sub, color, sub2 }) {
  return (
    <div style={{ textAlign: 'center', fontFamily: HEAD }}>
      <div style={{
        fontFamily: MONO_STACK, fontSize: 24, letterSpacing: '0.32em', textTransform: 'uppercase',
        color: color === '#fff' ? 'rgba(255,255,255,0.65)' : V2.inkMute, fontWeight: 500, marginBottom: 32
      }}>{caption}</div>
      <div style={{
        fontSize: 168, fontWeight: 800, letterSpacing: '-0.045em', lineHeight: 0.93,
        color: color || V2.ink, textWrap: 'balance'
      }}>{head}</div>
      {sub && <div style={{
        marginTop: 28, fontSize: 40, fontWeight: 400, lineHeight: 1.25,
        color: color === '#fff' ? 'rgba(255,255,255,0.68)' : V2.inkMute,
        maxWidth: 1700, marginLeft: 'auto', marginRight: 'auto', textWrap: 'balance',
        letterSpacing: '-0.005em'
      }}>{sub}</div>}
      {sub2}
    </div>);

}

// A "specimen" frame — what a museum catalog would put a thing inside.
function Specimen({ children, style = {}, accent = V2.peach, label, no, dark = false }) {
  const ink = dark ? '#F4EADB' : V2.ink;
  const mute = dark ? 'rgba(244,234,219,0.55)' : V2.inkMute;
  const hair = dark ? 'rgba(244,234,219,0.22)' : V2.hair;
  return (
    <div style={{
      position: 'relative', padding: '32px 32px 56px',
      border: `1px solid ${hair}`,
      background: dark ? 'rgba(255,255,255,0.02)' : 'rgba(255,255,255,0.35)',
      ...style
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 28 }}>
        <span style={{
          fontFamily: MONO_STACK, fontSize: 18, letterSpacing: '0.2em', textTransform: 'uppercase',
          color: mute, fontWeight: 500
        }}>{label}</span>
        {no != null &&
        <span style={{
          fontFamily: MONO_STACK, fontSize: 18, letterSpacing: '0.2em',
          color: accent, fontWeight: 600
        }}>№ {no}</span>
        }
      </div>
      {children}
    </div>);

}

// ════════════════════════════════════════════════════════════════════════════
// Shot 1 · "20 · 20 · 20" — the rule, as the artwork
// ════════════════════════════════════════════════════════════════════════════
function V2Shot1({ copy }) {
  return (
    <div style={{
      width: V2W, height: V2H, position: 'relative', overflow: 'hidden',
      background: V2.paper, fontFamily: HEAD
    }}>
      <PlateChrome index={1} accent={V2.peach} bottomLeft="The 20 · 20 · 20 rule" bottomRight="American Optometric Association, 2008" />

      {/* Eyebrow caption */}
      <div style={{
        position: 'absolute', top: 220, left: 0, right: 0, textAlign: 'center',
        fontFamily: MONO_STACK, fontSize: 28, letterSpacing: '0.38em', textTransform: 'uppercase',
        color: V2.inkMute, fontWeight: 500
      }}>The rule, observed</div>

      {/* THE numbers */}
      <div style={{
        position: 'absolute', top: 320, left: 0, right: 0,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        gap: 40, color: V2.ink, fontWeight: 800, letterSpacing: '-0.06em',
        fontFamily: HEAD, fontFeatureSettings: '"tnum"'
      }}>
        <BigNum n="20" unit="minutes" />
        <Dot />
        <BigNumWithInset peach={V2.peach} />
        <Dot />
        <BigNum n="20" unit="seconds" />
      </div>

      {/* Headline below */}
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 280, textAlign: 'center'
      }}>
        <div style={{
          fontSize: 96, fontWeight: 700, letterSpacing: '-0.035em', lineHeight: 1,
          color: V2.ink, textWrap: 'balance'
        }}>Eye breaks that respect your flow.</div>
        <div style={{
          marginTop: 26, fontSize: 34, color: V2.inkMute, fontWeight: 400,
          letterSpacing: '-0.005em', maxWidth: 1500, marginLeft: 'auto', marginRight: 'auto'
        }}>Blink remembers the rule, watches the clock, and waits for the right moment.</div>
      </div>
    </div>);

}

function BigNum({ n, unit }) {
  return (
    <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{ fontSize: 540, lineHeight: 0.85, fontFamily: HEAD, color: V2.ink }}>{n}</div>
      <div style={{
        marginTop: 8, fontFamily: MONO_STACK, fontSize: 22, letterSpacing: '0.3em', textTransform: 'uppercase',
        color: V2.inkMute, fontWeight: 500
      }}>{unit}</div>
    </div>);

}

function Dot() {
  return <div style={{ width: 28, height: 28, borderRadius: '50%', background: V2.ink, marginBottom: 60 }} />;
}

// The center "20" — peeled open, with the real countdown overlay tucked into its "0".
function BigNumWithInset({ peach }) {
  return (
    <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      {/* Cute wink stroke arched above the live 0 */}
      <svg width="140" height="60" viewBox="0 0 140 60" style={{
        position: 'absolute', top: -28, left: '50%', marginLeft: 18, transform: 'translateX(-40%)'
      }}>
        <path d="M 12 44 Q 70 4 128 44" stroke={peach} strokeWidth="10" fill="none" strokeLinecap="round" />
      </svg>
      <div style={{
        fontSize: 540, lineHeight: 0.85, fontFamily: HEAD, color: V2.ink,
        position: 'relative', display: 'flex', alignItems: 'baseline'
      }}>
        <span>2</span>
        {/* The "0" — replaced with a ring + the countdown */}
        <div style={{
          position: 'relative', width: 400, height: 400,
          marginLeft: 18, marginRight: 18, marginBottom: 6
        }}>
          {/* viewBox sized so the 48px stroke (outer radius 194) clears the
              box edge — otherwise the ring clips flat at top/bottom/left/right. */}
          <svg width="400" height="400" viewBox="0 0 400 400" style={{ position: 'absolute', inset: 0 }}>
            <circle cx="200" cy="200" r="170" stroke={V2.ink} strokeWidth="48" fill="none" />
            <circle cx="200" cy="200" r="170" stroke={peach} strokeWidth="48" fill="none"
            strokeLinecap="round" strokeDasharray={`${2 * Math.PI * 170 * 0.72} ${2 * Math.PI * 170}`}
            transform="rotate(-90 200 200)" opacity="0.95" />
          </svg>
          <div style={{
            position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 220, fontWeight: 300, color: V2.ink, letterSpacing: '-0.04em'
          }}>19</div>
        </div>
      </div>
      <div style={{
        marginTop: 8, fontFamily: MONO_STACK, fontSize: 22, letterSpacing: '0.3em', textTransform: 'uppercase',
        color: peach, fontWeight: 600
      }}>Feet · live break</div>
    </div>);

}

// ════════════════════════════════════════════════════════════════════════════
// Shot 2 · Menu bar — annotated callout
// Menu bar strip sits high; dropdown sits below at full size; a single
// hairline curve connects them. No loupe, no overlap, no crossing lines.
// ════════════════════════════════════════════════════════════════════════════
function V2Shot2({ copy }) {
  return (
    <div style={{
      width: V2W, height: V2H, position: 'relative', overflow: 'hidden',
      background: V2.paper, fontFamily: HEAD
    }} data-comment-anchor="b3d9a034ee-div-234-5">
      <PlateChrome index={2} accent={V2.peach} bottomLeft="Menu bar item · top-right corner" bottomRight="Click once, see your timer" />

      {/* Headline (top-left, asymmetric — pairs with the call-out on the right) */}
      <div style={{ position: 'absolute', top: 220, left: 200, width: 1280 }}>
        <div style={{
          fontFamily: MONO_STACK, fontSize: 24, letterSpacing: '0.32em', textTransform: 'uppercase',
          color: V2.inkMute, fontWeight: 500, marginBottom: 32
        }}>Mode of operation</div>
        <div style={{
          fontSize: 168, fontWeight: 800, letterSpacing: '-0.045em', lineHeight: 0.92, color: V2.ink, textWrap: 'balance'
        }}>Lives in your menu bar.</div>
        <div style={{
          marginTop: 32, fontSize: 36, fontWeight: 400, color: V2.inkMute, textWrap: 'balance',
          maxWidth: 1100, lineHeight: 1.35
        }}>One tap to pause, snooze, or skip. No dock icon, no window. Nothing to close — because there's nothing to open.</div>
      </div>

      {/* Menu bar strip — narrow, hangs across the top-right, hairline borders */}
      <div style={{
        position: 'absolute', left: 1620, right: 200, top: 260,
        border: `1px solid ${V2.hair}`,
        background: V2.paperHi
      }}>
        <div style={{
          height: 60, padding: '0 18px', display: 'flex', alignItems: 'center', gap: 22,
          color: V2.ink, fontSize: 20, fontFamily: HEAD
        }}>
          <span style={{ fontSize: 20, opacity: 0.65 }}></span>
          <span style={{ fontWeight: 600, fontSize: 18 }}>Finder</span>
          <span style={{ opacity: 0.5, fontSize: 18 }}>File</span>
          <span style={{ opacity: 0.5, fontSize: 18 }}>Edit</span>
          <div style={{ flex: 1 }} />
          <span style={{ opacity: 0.5, fontSize: 16, fontFamily: MONO_STACK }}>62%</span>
          <span style={{ opacity: 0.5, fontSize: 16 }}>◐</span>
          {/* Highlighted Blink item — this is the call-out target */}
          <div id="menu-blink-target" style={{
            position: 'relative', display: 'flex', alignItems: 'center', gap: 6,
            padding: '5px 10px', background: hexAlpha(V2.peach, 0.16), borderRadius: 6,
            outline: `1.5px solid ${V2.peach}`
          }}>
            <div style={{ width: 22, height: 22 }}><BlinkIcon size={22} themeKey="peach" mode="light" /></div>
            <span style={{ fontFamily: MONO_STACK, fontSize: 18, fontWeight: 500, color: V2.ink }}>19:57</span>
          </div>
          <span style={{ opacity: 0.5, fontFamily: MONO_STACK, fontSize: 16, whiteSpace: 'nowrap' }}>Wed&nbsp;&nbsp;10:32</span>
        </div>
      </div>

      {/* The dropdown — sits clean, full size, on the right side */}
      <div style={{
        position: 'absolute', right: 200, top: 480,
        filter: 'drop-shadow(0 50px 80px rgba(80,40,15,0.22)) drop-shadow(0 4px 16px rgba(80,40,15,0.10))'
      }}>
        <BlinkDropdown themeKey="peach" mode="light" width={780} state={{
          badgeDot: '#9CA3AF', badgeLabel: 'Working',
          stateLabel: 'Timer running', durationLabel: '20 min',
          remaining: 19 * 60 + 57, total: 20 * 60, breaks: 3
        }} />
      </div>

      {/* Hairline curve from Blink menu-bar item down to the dropdown's top edge.
           Single clean stroke, no crossings. */}
      <svg
        style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}
        viewBox={`0 0 ${V2W} ${V2H}`}
        preserveAspectRatio="none">
        
        {/* Start: just under the highlighted Blink menu-bar item (measured at
             ≈ x 2492, y 307). End: top-left edge of the dropdown (≈ x 1900, y 478). */}
        <path
          d="M 2492 310 C 2492 398, 2360 468, 2290 474"
          stroke={V2.ink} strokeWidth="1.5" fill="none" strokeDasharray="6 8" opacity="0.55" />

        <circle cx="2492" cy="310" r="6" fill={V2.peach} />
        <circle cx="2290" cy="474" r="6" fill={V2.ink} />
      </svg>

    </div>);

}

// ════════════════════════════════════════════════════════════════════════════
// Shot 3 · Flow detection as an eye chart (20 → 30 → 40)
// ════════════════════════════════════════════════════════════════════════════
function V2Shot3({ copy }) {
  return (
    <div style={{
      width: V2W, height: V2H, position: 'relative', overflow: 'hidden',
      background: V2.paper, fontFamily: HEAD
    }}>
      <PlateChrome index={3} accent={V2.peach} bottomLeft="Adaptive interval · 20 → 40 min" bottomRight="Detects steady typing, no app-switching" />

      {/* Top: headline + subhead, centered */}
      <div style={{
        position: 'absolute', top: 200, left: 200, right: 200, textAlign: 'center'
      }}>
        <div style={{
          fontSize: 132, fontWeight: 800, letterSpacing: '-0.04em', lineHeight: 0.95, color: V2.ink,
          textWrap: 'balance'
        }}>Knows when you're in the zone.</div>
        <div style={{
          marginTop: 24, fontSize: 34, fontWeight: 400, color: V2.inkMute,
          lineHeight: 1.3, maxWidth: 1600, marginLeft: 'auto', marginRight: 'auto', textWrap: 'balance'
        }}>Your next break shifts from 20 → 40 minutes as flow deepens. Blink waits — never mid-thought.</div>
      </div>

      {/* Body: eye chart on the left, dropdown on the right.
           Vertically centered in the lower 60% of the canvas. */}
      <div style={{
        position: 'absolute', left: 200, right: 200, top: 780, bottom: 200,
        display: 'grid', gridTemplateColumns: '1.55fr 1fr', gap: 80, alignItems: 'center'
      }}>
        {/* Eye chart */}
        <div>
          <EyeChartRow n="20" label="Idle / browsing" mins={20} size={300} active={false} />
          <Hair />
          <EyeChartRow n="30" label="Focused work" mins={30} size={220} active={false} />
          <Hair />
          <EyeChartRow n="40" label="Deep work · current" mins={40} size={160} active={true} />
        </div>

        {/* Dropdown */}
        <div style={{
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 24
        }}>
          <div style={{
            fontFamily: MONO_STACK, fontSize: 20, letterSpacing: '0.2em', textTransform: 'uppercase',
            color: V2.inkMute, fontWeight: 500
          }}>Currently — deep work · 40 min</div>
          <div style={{
            filter: 'drop-shadow(0 40px 60px rgba(80,40,15,0.16))'
          }}>
            <BlinkDropdown themeKey="peach" mode="light" width={680} state={{
              badgeDot: '#9CA3AF', badgeLabel: 'Working',
              stateLabel: 'Timer running', durationLabel: '40 min',
              remaining: 38 * 60 + 42, total: 40 * 60, breaks: 3
            }} />
          </div>
        </div>
      </div>
    </div>);

}

function EyeChartRow({ n, label, mins, size, active }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 56, padding: '14px 0'
    }}>
      <div style={{ position: 'relative', minWidth: 320, textAlign: 'center' }}>
        <div style={{
          fontSize: size, lineHeight: 0.85, fontWeight: 800, letterSpacing: '-0.05em',
          color: active ? V2.peach : V2.ink, opacity: active ? 1 : 0.65,
          fontFamily: HEAD, fontFeatureSettings: '"tnum"'
        }}>{n}</div>
        {/* Cute Blink mascot stamps next to the currently-active row */}
        {active &&
        <div style={{
          position: 'absolute', right: -42, top: -10, transform: 'rotate(8deg)',
          filter: 'drop-shadow(0 6px 12px rgba(140,55,20,0.25))'
        }}>
            <BlinkIcon size={108} themeKey="peach" mode="light" />
          </div>
        }
      </div>
      <div>
        <div style={{
          fontFamily: MONO_STACK, fontSize: 22, letterSpacing: '0.18em', textTransform: 'uppercase',
          color: active ? V2.peach : V2.inkMute, fontWeight: active ? 700 : 500
        }}>{label}</div>
        <div style={{
          marginTop: 8, fontSize: 28, color: V2.ink, opacity: active ? 1 : 0.6
        }}>{mins} minutes between breaks</div>
      </div>
    </div>);

}

function Hair() {return <div style={{ height: 1, background: V2.hair, margin: '4px 0' }} />;}

Object.assign(window, { V2Shot1, V2Shot2, V2Shot3, V2, PlateChrome, PlateHead, Specimen, HEAD });