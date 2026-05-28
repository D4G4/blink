// Blink App Store screenshots — shots 1, 2, 3
// All artboards are exactly 2880×1800 (16:10), App Store macOS spec.

const W = 2880;
const H = 1800;

// Shared marketing header — big tagline + subhead, App Store standard.
function MarketingHeader({ tagline, subhead, theme, color }) {
  const fg = color || theme.onBgText;
  const mute = color === '#FFFFFF' ? 'rgba(255,255,255,0.78)' :
  color ? hexAlpha(color, 0.7) : theme.onBgTextMute;
  return (
    <div style={{
      textAlign: 'center',
      fontFamily: FONT_STACK,
      paddingTop: 120,
      paddingLeft: 220,
      paddingRight: 220
    }}>
      <div style={{
        fontSize: 132,
        fontWeight: 700,
        letterSpacing: '-0.035em',
        lineHeight: 0.98,
        color: fg,
        textWrap: 'balance'
      }}>{tagline}</div>
      {subhead &&
      <div style={{
        marginTop: 40,
        fontSize: 54,
        fontWeight: 400,
        color: mute,
        letterSpacing: '-0.012em',
        lineHeight: 1.18,
        textWrap: 'balance',
        maxWidth: 2200,
        marginLeft: 'auto',
        marginRight: 'auto'
      }}>{subhead}</div>
      }
    </div>);

}

// ── Authentic break overlay ────────────────────────────────────────────────
// Centered cream card with title, countdown ring, and esc/extend keys
function BreakOverlayCard({ theme, count = 19, width = 1700, scale = 1 }) {
  const ring = theme.accent;
  const ringSoft = hexAlpha(theme.accent, 0.18);
  const dash = 2 * Math.PI * 200;
  const progress = 0.72;
  return (
    <div style={{
      width, transform: `scale(${scale})`, transformOrigin: 'center',
      background: theme.overlayBg,
      borderRadius: 60,
      padding: '120px 80px 110px',
      boxShadow: theme.isDark ?
      '0 80px 160px rgba(0,0,0,0.55), inset 0 0 0 1px rgba(255,255,255,0.04)' :
      '0 80px 160px rgba(0,0,0,0.18), inset 0 0 0 1px rgba(255,255,255,0.6)',
      backdropFilter: 'blur(40px)',
      fontFamily: FONT_STACK,
      display: 'flex', flexDirection: 'column', alignItems: 'center'
    }}>
      <div style={{
        fontSize: 78, fontWeight: 600, color: theme.overlayText, letterSpacing: '-0.025em'
      }}>Look at something far away</div>
      <div style={{ marginTop: 18, fontSize: 36, color: theme.overlayTextMute, letterSpacing: '0.01em' }}>
        20 feet, for 20 seconds
      </div>

      <div style={{ marginTop: 100, position: 'relative', width: 440, height: 440 }}>
        <svg width="440" height="440" viewBox="0 0 440 440">
          <circle cx="220" cy="220" r="200" stroke={ringSoft} strokeWidth="7" fill="none" />
          <circle cx="220" cy="220" r="200" stroke={ring} strokeWidth="7" fill="none"
          strokeLinecap="round" strokeDasharray={`${dash * progress} ${dash}`}
          transform="rotate(-90 220 220)" />
        </svg>
        <div style={{
          position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 200, fontWeight: 300, color: theme.overlayText, letterSpacing: '-0.04em'
        }}>{count}</div>
      </div>

      <div style={{ marginTop: 100, display: 'flex', gap: 36 }}>
        <KeyHint kbd="esc" caption="Skip break" theme={theme} />
        <KeyHint kbd="→" caption="Extend 20s" theme={theme} />
      </div>
    </div>);

}

function KeyHint({ kbd, caption, theme }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 22,
      padding: '20px 36px', borderRadius: 999,
      background: theme.isDark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)',
      color: theme.overlayText,
      fontSize: 32, fontWeight: 500
    }}>
      <span style={{
        background: theme.isDark ? 'rgba(255,255,255,0.10)' : 'rgba(255,255,255,0.85)',
        borderRadius: 12, padding: '6px 18px',
        fontSize: 28, fontFamily: MONO_STACK,
        minWidth: 50, textAlign: 'center', color: theme.overlayText,
        boxShadow: theme.isDark ?
        'inset 0 -2px 0 rgba(255,255,255,0.06)' :
        'inset 0 -2px 0 rgba(0,0,0,0.08), 0 1px 0 rgba(255,255,255,1)'
      }}>{kbd}</span>
      <span>{caption}</span>
    </div>);

}

// ── Reusable: menu bar dropdown (matches MenuBarView in the app) ───────────
// State labels per MenuBarView.swift:373, 404, 415
function BlinkDropdown({ themeKey, mode = 'light', state, width = 720 }) {
  const t = THEMES[themeKey];
  const accent = themeKey === 'mono' && mode === 'dark' ? '#FFFFFF' : t.accent;
  const dark = mode === 'dark';
  const surface = dark ? '#1c1c1e' : 'rgba(255,255,255,0.96)';
  const card = dark ? '#2a2a2c' : '#f4f4f5';
  const text = dark ? '#fff' : '#1c1c1e';
  const mute = dark ? 'rgba(255,255,255,0.55)' : '#5f6470';
  const {
    badgeDot, badgeLabel, stateLabel, durationLabel,
    remaining, total, breaks
  } = state;

  const progress = 1 - remaining / total;

  return (
    <div style={{
      width,
      background: surface,
      backdropFilter: 'blur(60px)',
      WebkitBackdropFilter: 'blur(60px)',
      borderRadius: 28,
      padding: 36,
      boxShadow: '0 40px 100px rgba(0,0,0,0.35), 0 0 0 1px rgba(255,255,255,0.5)',
      color: text, fontFamily: FONT_STACK
    }}>
      {/* Header: icon + name + status dot */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 18, marginBottom: 28 }}>
        <BlinkIcon size={72} themeKey={themeKey} mode={mode} />
        <div>
          <div style={{ fontSize: 30, fontWeight: 600, letterSpacing: '-0.01em' }}>Blink</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, color: mute, fontSize: 22, marginTop: 4 }}>
            <span style={{ width: 12, height: 12, borderRadius: '50%', background: badgeDot, display: 'inline-block' }} />
            {badgeLabel}
          </div>
        </div>
      </div>

      {/* Timer card */}
      <div style={{
        background: card, borderRadius: 20, padding: '30px 32px 26px'
      }}>
        <div style={{
          display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between'
        }}>
          <div style={{
            fontSize: 132, fontWeight: 200, letterSpacing: '-0.04em', lineHeight: 0.95,
            color: text, fontFeatureSettings: '"tnum"'
          }}>{formatTime(remaining)}</div>
          <div style={{ textAlign: 'right', paddingBottom: 16 }}>
            <div style={{ color: mute, fontSize: 20 }}>Next break in</div>
            <div style={{ color: text, fontSize: 26, fontWeight: 500, marginTop: 2, fontFeatureSettings: '"tnum"' }}>
              {Math.round(remaining / 60)} min
            </div>
          </div>
        </div>

        {/* Progress bar */}
        <div style={{
          marginTop: 22, height: 8, background: dark ? 'rgba(255,255,255,0.10)' : 'rgba(0,0,0,0.06)',
          borderRadius: 4, overflow: 'hidden'
        }}>
          <div style={{
            height: '100%', width: `${progress * 100}%`,
            background: accent, borderRadius: 4
          }} />
        </div>

        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 16, fontSize: 22, color: mute }}>
          <span>{stateLabel}</span>
          <span>{durationLabel}</span>
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 22, fontSize: 22, color: mute }}>
        <span>{breaks} breaks today</span>
        <span>Sensitivity · Deep work</span>
      </div>

      {/* Take break button */}
      <button style={{
        marginTop: 24, width: '100%', height: 76, borderRadius: 18, border: 'none',
        background: accent,
        color: themeKey === 'mono' && mode === 'light' ? '#fff' : '#fff',
        fontSize: 28, fontWeight: 600, fontFamily: FONT_STACK,
        boxShadow: `0 12px 28px ${hexAlpha(accent, 0.35)}`
      }}>Take break now</button>

      {/* Footer */}
      <div style={{
        display: 'flex', justifyContent: 'space-between', marginTop: 22, color: mute, fontSize: 20
      }}>
        <span>ⓘ  About</span>
        <span>⚙  Preferences</span>
        <span>Quit</span>
      </div>
    </div>);

}

function formatTime(secs) {
  const m = Math.floor(secs / 60);
  const s = secs % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}

// ── Reusable: stylized macOS menu bar with Blink icon highlighted ─────────
function MacMenuBar({ themeKey, mode = 'light', highlightBlink = true, time = '10:32' }) {
  const t = THEMES[themeKey];
  return (
    <div style={{
      position: 'absolute', top: 0, left: 0, right: 0, height: 56,
      background: 'rgba(255,255,255,0.22)',
      backdropFilter: 'blur(40px)', WebkitBackdropFilter: 'blur(40px)',
      display: 'flex', alignItems: 'center',
      padding: '0 28px', color: '#fff',
      fontSize: 22, fontFamily: FONT_STACK, gap: 28,
      borderBottom: '1px solid rgba(255,255,255,0.15)'
    }}>
      <span style={{ fontSize: 24 }}></span>
      <span style={{ fontWeight: 600 }}>Blink</span>
      <span style={{ opacity: 0.85 }}>File</span>
      <span style={{ opacity: 0.85 }}>Edit</span>
      <span style={{ opacity: 0.85 }}>View</span>
      <span style={{ opacity: 0.85 }}>Window</span>
      <span style={{ opacity: 0.85 }}>Help</span>
      <div style={{ flex: 1 }} />
      <span style={{ opacity: 0.9, fontSize: 20 }}>62%</span>
      <span style={{ opacity: 0.9 }}>◐</span>
      <div style={{
        padding: '4px 12px', borderRadius: 8,
        background: highlightBlink ? 'rgba(255,255,255,0.30)' : 'transparent',
        display: 'flex', alignItems: 'center', gap: 8
      }}>
        <div style={{ width: 28, height: 28 }}>
          <BlinkIcon size={28} themeKey={themeKey} mode={mode} />
        </div>
        <span style={{ fontSize: 20, fontWeight: 500, fontFeatureSettings: '"tnum"' }}>19:57</span>
      </div>
      <span style={{ opacity: 0.9 }}>Wed Jun 4  {time}</span>
    </div>);

}

// ─── Shot 1 ─── Hero / break overlay ─────────────────────────────────────────
// Peach theme — exact gradient from BlinkTheme.swift
// (#FFB89A → #F09060 at 135deg, no overlay washes, no faded white tint).
function Shot1Hero({ copy }) {
  const t = resolveTheme('peach', 'light');
  return (
    <div style={{
      width: W, height: H, position: 'relative', overflow: 'hidden',
      // Exact BlinkTheme.swift Peach light gradient — no muddying overlays.
      background: 'linear-gradient(135deg, #FFB89A 0%, #F09060 100%)',
      fontFamily: FONT_STACK
    }}>
      {/* (Intentionally no white-wash overlay — that was the “faded
          orange” Daksh flagged. The straight gradient reads richer.) */}
      <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}
           data-comment-anchor="4a810f8a2a-div-272-7" />

      {/* Eyebrow: mascot + brand line */}
      <div style={{
        position: 'absolute', top: 86, left: 0, right: 0,
        display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 22
      }}>
        <div style={{ width: 56, height: 56 }}>
          <BlinkIcon size={56} themeKey="peach" mode="light" />
        </div>
        <div style={{
          fontSize: 26, letterSpacing: '0.28em', textTransform: 'uppercase',
          color: 'rgba(255,255,255,0.85)', fontWeight: 700
        }}>Blink · for macOS</div>
      </div>

      {/* Headline + subhead in confident white (Peach onBgText: #FFFFFF) */}
      <div style={{
        position: 'absolute', top: 220, left: 0, right: 0, textAlign: 'center',
        paddingLeft: 240, paddingRight: 240
      }}>
        <div style={{
          fontSize: 150, fontWeight: 700, letterSpacing: '-0.04em',
          color: '#FFFFFF', lineHeight: 0.95, textWrap: 'balance'
        }}>{copy.t1}</div>
        <div style={{
          marginTop: 40, fontSize: 54, fontWeight: 400,
          color: 'rgba(255,255,255,0.78)', letterSpacing: '-0.012em',
          maxWidth: 2200, marginLeft: 'auto', marginRight: 'auto', textWrap: 'balance'
        }}>{copy.s1}</div>
      </div>

      {/* Break overlay card with realistic shadow tying it to the field */}
      <div style={{
        position: 'absolute', left: 0, right: 0, top: 720,
        display: 'flex', justifyContent: 'center'
      }}>
        <div style={{
          filter:
            'drop-shadow(0 70px 80px rgba(140,55,20,0.28)) drop-shadow(0 8px 20px rgba(140,55,20,0.18))'
        }}>
          <BreakOverlayCard theme={t} count={19} width={1900} />
        </div>
      </div>
    </div>);

}

// ─── Shot 2 ─── Menu bar in action ──────────────────────────────────────────
function Shot2MenuBar({ copy }) {
  return (
    <div style={{
      width: W, height: H, position: 'relative', overflow: 'hidden',
      background: 'linear-gradient(135deg, #FFB89A 0%, #F09060 100%)',
      fontFamily: FONT_STACK
    }}>
      {/* Eyebrow */}
      <div style={{
        position: 'absolute', top: 86, left: 0, right: 0,
        display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 22
      }}>
        <div style={{ width: 56, height: 56 }}>
          <BlinkIcon size={56} themeKey="peach" mode="light" />
        </div>
        <div style={{
          fontSize: 26, letterSpacing: '0.28em', textTransform: 'uppercase',
          color: 'rgba(255,255,255,0.85)', fontWeight: 700
        }}>Blink · for macOS</div>
      </div>

      {/* Headline */}
      <div style={{
        position: 'absolute', top: 220, left: 0, right: 0, textAlign: 'center',
        paddingLeft: 240, paddingRight: 240
      }}>
        <div style={{
          fontSize: 150, fontWeight: 700, letterSpacing: '-0.04em',
          color: '#FFFFFF', lineHeight: 0.95, textWrap: 'balance'
        }}>{copy.t2}</div>
        <div style={{
          marginTop: 40, fontSize: 54, fontWeight: 400,
          color: 'rgba(255,255,255,0.78)', letterSpacing: '-0.012em',
          maxWidth: 2200, marginLeft: 'auto', marginRight: 'auto', textWrap: 'balance'
        }}>{copy.s2}</div>
      </div>

      {/* Translucent desktop strip with a peach-tinted menu bar + Blink dropdown.
          No blue macOS wallpaper — keeps the field consistent with Shot 1. */}
      <div style={{
        position: 'absolute', left: 240, right: 240, top: 800,
        height: 900,
        borderRadius: '44px 44px 0 0', overflow: 'hidden',
        background: 'rgba(255,240,232,0.45)',
        backdropFilter: 'blur(40px)', WebkitBackdropFilter: 'blur(40px)',
        boxShadow: '0 70px 80px rgba(140,55,20,0.28), 0 8px 20px rgba(140,55,20,0.18), inset 0 0 0 1px rgba(255,255,255,0.5)'
      }}>
        <PeachMenuBar />
        <div style={{ position: 'absolute', top: 90, right: 120 }}>
          <BlinkDropdown themeKey="peach" mode="light" width={720} state={{
            badgeDot: '#9CA3AF',
            badgeLabel: 'Working',
            stateLabel: 'Timer running',
            durationLabel: '20 min',
            remaining: 19 * 60 + 57,
            total: 20 * 60,
            breaks: 3
          }} />
        </div>
      </div>
    </div>);

}

// Peach-tinted menu bar (replaces blue macOS wallpaper version)
function PeachMenuBar() {
  return (
    <div style={{
      position: 'absolute', top: 0, left: 0, right: 0, height: 56,
      background: 'rgba(61,32,18,0.55)',
      backdropFilter: 'blur(40px)', WebkitBackdropFilter: 'blur(40px)',
      display: 'flex', alignItems: 'center',
      padding: '0 28px', color: '#fff',
      fontSize: 22, fontFamily: FONT_STACK, gap: 28,
      borderBottom: '1px solid rgba(255,255,255,0.18)'
    }}>
      <span style={{ fontSize: 24 }}></span>
      <span style={{ fontWeight: 600 }}>Blink</span>
      <span style={{ opacity: 0.85 }}>File</span>
      <span style={{ opacity: 0.85 }}>Edit</span>
      <span style={{ opacity: 0.85 }}>View</span>
      <span style={{ opacity: 0.85 }}>Window</span>
      <span style={{ opacity: 0.85 }}>Help</span>
      <div style={{ flex: 1 }} />
      <span style={{ opacity: 0.9, fontSize: 20 }}>62%</span>
      <span style={{ opacity: 0.9 }}>◐</span>
      <div style={{
        padding: '4px 12px', borderRadius: 8,
        background: 'rgba(255,255,255,0.30)',
        display: 'flex', alignItems: 'center', gap: 8
      }}>
        <div style={{ width: 28, height: 28 }}>
          <BlinkIcon size={28} themeKey="peach" mode="light" />
        </div>
        <span style={{ fontSize: 20, fontWeight: 500, fontFeatureSettings: '"tnum"' }}>19:57</span>
      </div>
      <span style={{ opacity: 0.9 }}>Wed Jun 4  10:32</span>
    </div>);

}

// ─── Shot 3 ─── Flow detection (in-flow Working state, 40 min timer) ────────
// Per user spec: NO chart, show what the app actually shows. Menu bar
// dropdown in "Working / 40 min" state — the 20→30→40 progression IS the viz.
function Shot3Flow({ copy }) {
  return (
    <div style={{
      width: W, height: H, position: 'relative', overflow: 'hidden',
      background: 'linear-gradient(135deg, #FFB89A 0%, #F09060 100%)',
      fontFamily: FONT_STACK
    }}>
      {/* Eyebrow */}
      <div style={{
        position: 'absolute', top: 86, left: 0, right: 0,
        display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 22
      }}>
        <div style={{ width: 56, height: 56 }}>
          <BlinkIcon size={56} themeKey="peach" mode="light" />
        </div>
        <div style={{
          fontSize: 26, letterSpacing: '0.28em', textTransform: 'uppercase',
          color: 'rgba(255,255,255,0.85)', fontWeight: 700
        }}>Blink · for macOS</div>
      </div>

      {/* Headline */}
      <div style={{
        position: 'absolute', top: 220, left: 0, right: 0, textAlign: 'center',
        paddingLeft: 240, paddingRight: 240
      }}>
        <div style={{
          fontSize: 150, fontWeight: 700, letterSpacing: '-0.04em',
          color: '#FFFFFF', lineHeight: 0.95, textWrap: 'balance'
        }}>{copy.t3}</div>
        <div style={{
          marginTop: 40, fontSize: 54, fontWeight: 400,
          color: 'rgba(255,255,255,0.78)', letterSpacing: '-0.012em',
          maxWidth: 2200, marginLeft: 'auto', marginRight: 'auto', textWrap: 'balance'
        }}>{copy.s3}</div>
      </div>

      {/* Two-column body on the peach field: progression tiles + dropdown */}
      <div style={{
        position: 'absolute', left: 200, right: 200, top: 820, bottom: 140,
        display: 'grid', gridTemplateColumns: '1.1fr 1fr', gap: 80, alignItems: 'center'
      }}>
        <div style={{ color: '#fff', fontFamily: FONT_STACK }}>
          <div style={{
            fontSize: 26, letterSpacing: '0.22em', textTransform: 'uppercase',
            color: 'rgba(255,255,255,0.85)', fontWeight: 700
          }}>Next break, adapting</div>

          <div style={{ display: 'flex', alignItems: 'baseline', gap: 28, marginTop: 32, flexWrap: 'wrap' }}>
            <ProgressionTile mins={20} label="Normal" dim />
            <Arrow />
            <ProgressionTile mins={30} label="In flow" dim />
            <Arrow />
            <ProgressionTile mins={40} label="Deep work" active />
          </div>

          <div style={{
            marginTop: 40, color: 'rgba(255,255,255,0.85)', fontSize: 28,
            fontWeight: 400, letterSpacing: '-0.005em', maxWidth: 880, lineHeight: 1.35,
            textShadow: '0 2px 16px rgba(140,55,20,0.18)'
          }}>
            When Blink detects steady typing, no app-switching, and active
            focus — your next break waits.
          </div>
        </div>

        <div style={{
          display: 'flex', justifyContent: 'center',
          filter: 'drop-shadow(0 70px 80px rgba(140,55,20,0.28)) drop-shadow(0 8px 20px rgba(140,55,20,0.18))'
        }}>
          <BlinkDropdown themeKey="peach" mode="light" width={720} state={{
            badgeDot: '#9CA3AF',
            badgeLabel: 'Working',
            stateLabel: 'Timer running',
            durationLabel: '40 min',
            remaining: 38 * 60 + 42,
            total: 40 * 60,
            breaks: 3
          }} />
        </div>
      </div>
    </div>);

}

function Arrow() {
  return (
    <svg width="64" height="40" viewBox="0 0 64 40" style={{ flex: '0 0 auto' }}>
      <path d="M4 20 L56 20 M56 20 L42 8 M56 20 L42 32" stroke="rgba(255,255,255,0.7)" strokeWidth="3.5" fill="none" strokeLinecap="round" strokeLinejoin="round" />
    </svg>);

}

function ProgressionTile({ mins, label, active, dim }) {
  return (
    <div style={{
      background: active ? 'rgba(255,255,255,0.95)' : 'rgba(255,255,255,0.16)',
      backdropFilter: 'blur(20px)',
      border: active ? 'none' : '1.5px solid rgba(255,255,255,0.35)',
      borderRadius: 28, padding: '36px 48px',
      minWidth: 240, textAlign: 'center',
      color: active ? '#3D2012' : '#fff',
      boxShadow: active ? '0 20px 60px rgba(0,0,0,0.18)' : 'none'
    }}>
      <div style={{
        fontSize: 96, fontWeight: 300, letterSpacing: '-0.04em', lineHeight: 1,
        fontFeatureSettings: '"tnum"'
      }}>
        {mins}<span style={{ fontSize: 34, fontWeight: 400, marginLeft: 8, opacity: 0.7 }}>min</span>
      </div>
      <div style={{
        fontSize: 22, marginTop: 12, fontWeight: 600,
        textTransform: 'uppercase', letterSpacing: '0.15em',
        color: active ? '#E88565' : 'rgba(255,255,255,0.9)'
      }}>{label}</div>
    </div>);

}

Object.assign(window, { Shot1Hero, Shot2MenuBar, Shot3Flow, BreakOverlayCard, BlinkDropdown, MacMenuBar });