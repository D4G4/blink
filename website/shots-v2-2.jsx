// Blink App Store screenshots v2 — shots 4, 5, 6, 7
// (Continuation of shots-v2.jsx — same editorial / optometric system.)

const V2W2 = 2880, V2H2 = 1800;

// ════════════════════════════════════════════════════════════════════════════
// Shot 4 · Themes as paint chips
// ════════════════════════════════════════════════════════════════════════════
function V2Shot4({ copy }) {
  const tiles = [
    { key: 'peach',    mode: 'light', name: 'Peach',    hex: '#E88565' },
    { key: 'sage',     mode: 'light', name: 'Sage',     hex: '#6EA87E' },
    { key: 'sand',     mode: 'light', name: 'Sand',     hex: '#9A9478' },
    { key: 'midnight', mode: 'dark',  name: 'Midnight', hex: '#6B7DB5' },
    { key: 'mono',     mode: 'dark',  name: 'Mono',     hex: '#FFFFFF' },
  ];
  return (
    <div style={{
      width: V2W2, height: V2H2, position: 'relative', overflow: 'hidden',
      background: V2.paper, fontFamily: HEAD,
    }}>
      <PlateChrome index={4} accent={V2.peach} bottomLeft="Five themes · light + dark" bottomRight="Specimen card · actual hex values" />

      {/* Header */}
      <div style={{ position: 'absolute', top: 200, left: 0, right: 0, padding: '0 220px', textAlign: 'center' }}>
        <div style={{
          fontSize: 168, fontWeight: 800, letterSpacing: '-0.045em', lineHeight: 0.93, color: V2.ink, textWrap: 'balance',
        }}>Five themes. Pick the one that disappears.</div>
      </div>

      {/* Paint-chip strips, hung from a top rule */}
      <div style={{
        position: 'absolute', left: 200, right: 200, top: 760, height: 880,
        display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 24,
      }}>
        {tiles.map((t, i) => <PaintChip key={t.key} themeKey={t.key} mode={t.mode} name={t.name} hex={t.hex} idx={i} />)}
      </div>
    </div>
  );
}

function PaintChip({ themeKey, mode, name, hex, idx }) {
  const t = resolveTheme(themeKey, mode);
  const isLight = mode === 'light';
  const ink = isLight ? '#1A1410' : '#F4EADB';
  const inkMute = isLight ? 'rgba(26,20,16,0.6)' : 'rgba(244,234,219,0.65)';
  return (
    <div style={{
      position: 'relative', height: '100%',
      background: t.bgGradient,
      boxShadow: '0 30px 60px rgba(60,30,15,0.16)',
      display: 'flex', flexDirection: 'column',
      color: ink, fontFamily: HEAD,
      overflow: 'hidden',
    }}>
      {/* Punched hole at top — like a real paint chip */}
      <div style={{
        position: 'absolute', top: 28, left: '50%', transform: 'translateX(-50%)',
        width: 28, height: 28, borderRadius: '50%',
        background: V2.paper, boxShadow: 'inset 0 2px 6px rgba(0,0,0,0.3)',
      }} />

      {/* Metadata */}
      <div style={{
        marginTop: 96, padding: '0 28px',
        fontFamily: MONO_STACK, fontSize: 16, letterSpacing: '0.18em', textTransform: 'uppercase',
        color: inkMute, display: 'flex', justifyContent: 'space-between',
      }}>
        <span>Theme № {String((idx ?? 0) + 1).padStart(2,'0')}</span>
        <span>{mode === 'dark' ? 'Dark' : 'Light'}</span>
      </div>

      {/* Big theme name */}
      <div style={{
        padding: '24px 28px 0',
        fontSize: 84, fontWeight: 800, letterSpacing: '-0.035em', lineHeight: 0.95,
        color: ink,
      }}>{name}</div>

      {/* Hex */}
      <div style={{
        padding: '12px 28px 0',
        fontFamily: MONO_STACK, fontSize: 22, letterSpacing: '0.1em',
        color: inkMute,
      }}>{hex}</div>

      <div style={{ flex: 1 }} />

      {/* Mini break overlay specimen */}
      <div style={{
        margin: '0 24px 28px', padding: '20px 16px 22px', borderRadius: 18,
        background: t.overlayBg, display: 'flex', flexDirection: 'column', alignItems: 'center',
        backdropFilter: 'blur(20px)',
        boxShadow: isLight ? '0 8px 24px rgba(0,0,0,0.08)' : '0 8px 24px rgba(0,0,0,0.4)',
      }}>
        <div style={{
          fontSize: 16, fontWeight: 600, color: t.overlayText, letterSpacing: '-0.005em',
          textAlign: 'center',
        }}>Look at something far away</div>
        <div style={{ marginTop: 12, position: 'relative', width: 130, height: 130 }}>
          <svg width="130" height="130" viewBox="0 0 130 130">
            <circle cx="65" cy="65" r="56" stroke={hexAlpha(t.accent, 0.18)} strokeWidth="3" fill="none" />
            <circle cx="65" cy="65" r="56" stroke={t.accent} strokeWidth="3" fill="none"
              strokeLinecap="round" strokeDasharray={`${2 * Math.PI * 56 * 0.65} ${2 * Math.PI * 56}`}
              transform="rotate(-90 65 65)" />
          </svg>
          <div style={{
            position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 60, fontWeight: 300, color: t.overlayText, letterSpacing: '-0.03em',
          }}>19</div>
        </div>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// Shot 5 · Settings — exploded diagram of Flow tab
// ════════════════════════════════════════════════════════════════════════════
function V2Shot5({ copy }) {
  const accent = V2.sage;
  return (
    <div style={{
      width: V2W2, height: V2H2, position: 'relative', overflow: 'hidden',
      background: V2.paper, fontFamily: HEAD,
    }}>
      <PlateChrome index={5} accent={accent} bottomLeft="Settings → Flow" bottomRight="Three presets · 40–90% fine-tune" />

      {/* Header */}
      <div style={{ position: 'absolute', top: 200, left: 200, right: 200 }}>
        <div style={{
          fontFamily: MONO_STACK, fontSize: 24, letterSpacing: '0.32em', textTransform: 'uppercase',
          color: V2.inkMute, fontWeight: 500, marginBottom: 32, textAlign: 'center',
        }}>Schematic · Flow preferences</div>
        <div style={{
          fontSize: 144, fontWeight: 800, letterSpacing: '-0.045em', lineHeight: 0.93, color: V2.ink,
          textAlign: 'center', textWrap: 'balance',
        }}>Learns your rhythm.</div>
      </div>

      {/* Annotated settings card — center stage, with hairline call-outs around it */}
      <div style={{
        position: 'absolute', left: '50%', transform: 'translateX(-50%)', top: 740,
        width: 1700, padding: 64, background: '#FFFAF0', borderRadius: 28,
        boxShadow: `0 60px 100px rgba(120,70,40,0.18), inset 0 0 0 1px ${V2.hair}`,
      }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 36 }}>
          <div style={{ fontSize: 42, fontWeight: 700, color: V2.ink, letterSpacing: '-0.02em' }}>Flow</div>
          <div style={{
            fontFamily: MONO_STACK, fontSize: 18, letterSpacing: '0.18em', textTransform: 'uppercase',
            color: V2.inkMute,
          }}>Schematic № 5</div>
        </div>

        {/* Preset row */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 22, marginBottom: 36 }}>
          <SchemaPreset title="Eye health" subtitle="Frequent breaks · 50%" active={false} accent={accent} />
          <SchemaPreset title="Balanced" subtitle="Default · 70%" active={false} accent={accent} />
          <SchemaPreset title="Deep work" subtitle="Fewer breaks · 85%" active={true} accent={accent} />
        </div>

        {/* Slider */}
        <div style={{
          fontFamily: MONO_STACK, fontSize: 18, letterSpacing: '0.18em', textTransform: 'uppercase',
          color: V2.inkMute, marginBottom: 14, display: 'flex', justifyContent: 'space-between',
        }}>
          <span>Fine-tune</span>
          <span style={{ color: accent }}>85%</span>
        </div>
        <div style={{ position: 'relative', height: 8, background: 'rgba(0,0,0,0.07)', borderRadius: 4 }}>
          <div style={{ position: 'absolute', left: 0, top: 0, height: '100%', width: '85%', borderRadius: 4, background: accent }} />
          <div style={{
            position: 'absolute', left: 'calc(85% - 16px)', top: -10, width: 32, height: 32,
            background: '#fff', borderRadius: '50%',
            boxShadow: '0 4px 10px rgba(0,0,0,0.18), inset 0 0 0 1px rgba(0,0,0,0.06)',
          }} />
        </div>
        <div style={{
          display: 'flex', justifyContent: 'space-between', marginTop: 14,
          fontFamily: MONO_STACK, fontSize: 16, color: V2.inkSoft,
        }}>
          <span>40%</span><span>60%</span><span>90%</span>
        </div>
      </div>

    </div>
  );
}

function SchemaPreset({ title, subtitle, active, accent }) {
  return (
    <div style={{
      padding: '28px 24px', position: 'relative',
      background: active ? hexAlpha(accent, 0.12) : 'rgba(255,255,255,0.6)',
      border: active ? `2px solid ${accent}` : `1px solid ${V2.hair}`,
      borderRadius: 14,
    }}>
      <div style={{
        position: 'absolute', top: 14, right: 14, width: 18, height: 18, borderRadius: '50%',
        background: active ? accent : 'transparent', border: active ? 'none' : `1.5px solid ${V2.hair}`,
      }} />
      <div style={{ fontSize: 30, fontWeight: 700, color: V2.ink, letterSpacing: '-0.01em' }}>{title}</div>
      <div style={{
        marginTop: 8, fontFamily: MONO_STACK, fontSize: 16, letterSpacing: '0.14em', textTransform: 'uppercase',
        color: V2.inkMute, fontWeight: 500,
      }}>{subtitle}</div>
    </div>
  );
}

function CalloutLabel({ x, y, target, title, body, align = 'left' }) {
  // Draw a hairline from (x,y) to target, with a label box at (x,y).
  const dx = target.x - x, dy = target.y - y;
  return (
    <>
      <svg style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}
        viewBox={`0 0 ${V2W2} ${V2H2}`} preserveAspectRatio="none">
        <line x1={x} y1={y} x2={target.x} y2={target.y} stroke={V2.ink} strokeWidth="1.2" strokeDasharray="4 8" opacity="0.5" />
        <circle cx={target.x} cy={target.y} r="6" fill={V2.ink} />
      </svg>
      <div style={{
        position: 'absolute', left: align === 'left' ? x - 260 : null, right: align === 'right' ? V2W2 - x - 260 : null,
        top: y - 28, width: 520, textAlign: align,
        fontFamily: HEAD,
      }}>
        <div style={{
          fontFamily: MONO_STACK, fontSize: 24, letterSpacing: '0.22em', textTransform: 'uppercase',
          color: V2.peach, fontWeight: 700, marginBottom: 12,
        }}>{title}</div>
        <div style={{ fontSize: 32, color: V2.ink, lineHeight: 1.32 }}>{body}</div>
      </div>
    </>
  );
}

// ════════════════════════════════════════════════════════════════════════════
// Shot 6 · Privacy — a blank ledger
// ════════════════════════════════════════════════════════════════════════════
function V2Shot6({ copy }) {
  return (
    <div style={{
      width: V2W2, height: V2H2, position: 'relative', overflow: 'hidden',
      background: V2.paper, fontFamily: HEAD,
    }}>
      <PlateChrome index={6} accent={V2.midnight} bottomLeft="Data inventory · official record" bottomRight="100% on-device · nothing transmitted" />

      {/* Left: massive headline */}
      <div style={{ position: 'absolute', left: 200, top: 280, width: 1180 }}>
        <div style={{
          fontSize: 200, fontWeight: 800, letterSpacing: '-0.05em', lineHeight: 0.92, color: V2.ink, textWrap: 'balance',
        }}>Private by design.</div>
        <div style={{
          marginTop: 36, fontSize: 38, color: V2.inkMute, lineHeight: 1.3, maxWidth: 1000, textWrap: 'pretty',
        }}>
          Blink runs entirely on your Mac. No telemetry, no accounts, no servers. Nothing leaves your machine —
          because nothing needs to.
        </div>

        {/* Three small affirmations */}
        <div style={{ marginTop: 56, display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 32 }}>
          {[
            ['100%', 'On-device'],
            ['0',    'Network calls'],
            ['0',    'Accounts required'],
          ].map(([n, l], i) => (
            <div key={i} style={{ display: 'flex', flexDirection: 'column', gap: 8, paddingTop: 18, borderTop: `1px solid ${V2.hair}` }}>
              <div style={{ position: 'relative', display: 'inline-block' }}>
                <div style={{ fontSize: 96, fontWeight: 800, letterSpacing: '-0.04em', lineHeight: 1, color: V2.ink, fontFeatureSettings: '"tnum"' }}>{n}</div>
                {/* Hand-drawn ring around the cute zero values */}
                {n === '0' && (
                  <svg width="130" height="110" viewBox="0 0 130 110" style={{
                    position: 'absolute', top: -6, left: -39, pointerEvents: 'none',
                  }}>
                    <path d="M 68 14 C 34 13, 16 35, 19 58 C 22 86, 50 98, 82 94 C 113 90, 120 58, 112 37 C 105 18, 86 13, 62 15"
                      fill="none" stroke={V2.peach} strokeWidth="4.5" strokeLinecap="round" opacity="0.9" />
                  </svg>
                )}
              </div>
              <div style={{
                fontFamily: MONO_STACK, fontSize: 18, letterSpacing: '0.2em', textTransform: 'uppercase',
                color: V2.inkMute, fontWeight: 500,
              }}>{l}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Right: a literal blank ledger — receipt-style */}
      <div style={{
        position: 'absolute', right: 200, top: 220, width: 880, padding: 56,
        background: V2.paperHi, borderRadius: 24,
        boxShadow: `0 40px 80px rgba(120,70,40,0.18), inset 0 0 0 1px ${V2.hair}`,
        fontFamily: MONO_STACK, fontSize: 20, color: V2.ink,
        height: 1380,
        display: 'flex', flexDirection: 'column',
      }}>
        {/* Tiny mascot at the top of the receipt */}
        <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 16 }}>
          <BlinkIcon size={68} themeKey="peach" mode="light" />
        </div>
        <div style={{ textAlign: 'center', letterSpacing: '0.28em', fontWeight: 700, marginBottom: 8 }}>BLINK · DATA INVENTORY</div>
        <div style={{ textAlign: 'center', color: V2.inkMute, fontSize: 16, letterSpacing: '0.18em' }}>EXPORTED 2026-05-27 · YOUR MAC</div>
        <Dashed />

        <Row label="Account" value="—" />
        <Row label="Email" value="—" />
        <Row label="Device ID" value="—" />
        <Row label="Crash reports sent" value="0" />
        <Row label="Analytics events" value="0" />
        <Row label="Network calls (lifetime)" value="0" />
        <Row label="Cloud sync" value="DISABLED" />
        <Row label="Accessibility usage" value="Local only" />
        <Row label="Typing rhythm content" value="NEVER READ" />
        <Row label="3rd-party SDKs" value="0" />

        <Dashed />

        <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 700, fontSize: 22, marginTop: 4 }}>
          <span>TOTAL ITEMS</span>
          <span>0</span>
        </div>

        <div style={{ flex: 1 }} />

        <Dashed />
        <div style={{
          textAlign: 'center', fontSize: 14, letterSpacing: '0.22em', color: V2.inkMute, marginTop: 12,
        }}>END OF RECORD · THIS RECEIPT IS LOCAL</div>
      </div>
    </div>
  );
}

function Row({ label, value }) {
  return (
    <div style={{
      display: 'flex', justifyContent: 'space-between', padding: '12px 0',
      borderBottom: `1px dashed ${V2.hairSoft}`,
    }}>
      <span style={{ color: V2.ink }}>{label}</span>
      <span style={{ color: V2.inkMute, fontWeight: 600 }}>{value}</span>
    </div>
  );
}

function Dashed() {
  return (
    <div style={{
      borderTop: `2px dashed ${V2.hair}`, margin: '18px 0',
    }} />
  );
}

// ════════════════════════════════════════════════════════════════════════════
// Shot 7 · Eye Exercise — Gabor patch as a celestial object
// ════════════════════════════════════════════════════════════════════════════
function V2Shot7({ copy }) {
  const accent = '#3DCC83';
  return (
    <div style={{
      width: V2W2, height: V2H2, position: 'relative', overflow: 'hidden',
      background: V2.night, fontFamily: HEAD, color: '#F4EADB',
    }}>
      <PlateChrome index={7} accent={accent} dark bottomLeft="Eye exercise · beta · Gabor patch" bottomRight="Optional during breaks · 2 min" />

      {/* Header */}
      <div style={{ position: 'absolute', top: 200, left: 200, right: 200, textAlign: 'center' }}>
        <div style={{
          fontSize: 144, fontWeight: 800, letterSpacing: '-0.045em', lineHeight: 0.93, color: '#F4EADB', textWrap: 'balance',
        }}>Train your eyes,
          <span style={{ color: accent }}> not just your breaks.</span>
        </div>
      </div>

      {/* The patch, centred, with concentric scientific rings around it */}
      <div style={{
        position: 'absolute', left: '50%', top: 1180, transform: 'translate(-50%, -50%)',
        width: 1100, height: 1100,
      }}>
        {/* Concentric guide rings */}
        <svg width="1100" height="1100" viewBox="0 0 1100 1100" style={{ position: 'absolute', inset: 0 }}>
          {[520, 460, 400, 340].map((r, i) => (
            <circle key={i} cx="550" cy="550" r={r} fill="none"
              stroke="rgba(244,234,219,0.15)" strokeWidth="1" strokeDasharray={i % 2 ? '2 6' : 'none'} />
          ))}
          {/* tick marks at cardinal points */}
          {[0, 90, 180, 270].map(deg => (
            <g key={deg} transform={`rotate(${deg} 550 550)`}>
              <line x1="550" y1="20" x2="550" y2="40" stroke="rgba(244,234,219,0.4)" strokeWidth="1.5" />
            </g>
          ))}
        </svg>

        {/* Actual Gabor patch in center */}
        <div style={{
          position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)',
          width: 600, height: 600, borderRadius: '50%', overflow: 'hidden',
          boxShadow: `0 0 120px ${hexAlpha(accent, 0.3)}`,
        }}>
          <GaborPatch size="100%" orientation={25} />
        </div>

        {/* Orbit annotations */}
        <Annotation deg={-10} r={540} text="CONTRAST DETECTION" accent={accent} />
        <Annotation deg={100} r={540} text="ORIENTATION" />
        <Annotation deg={210} r={540} text="FLANKER MASKING" />
      </div>

      {/* Bottom bar — the actual selector */}
      <div style={{
        position: 'absolute', left: 200, right: 200, bottom: 140, display: 'flex', gap: 16,
        justifyContent: 'center', alignItems: 'center',
      }}>
        <div style={{
          fontFamily: MONO_STACK, fontSize: 20, letterSpacing: '0.2em', textTransform: 'uppercase',
          color: 'rgba(244,234,219,0.55)', marginRight: 28,
        }}>Choose an exercise &nbsp;→</div>
        <ExBox label="Contrast Detection" sub="Spot the hidden pattern" active accent={accent} />
        <ExBox label="Orientation"        sub="Read the tilt" />
        <ExBox label="Flanker Masking"    sub="Focus through distractions" />
      </div>
    </div>
  );
}

function Annotation({ deg, r, text, accent }) {
  const rad = (deg * Math.PI) / 180;
  const x = 550 + r * Math.cos(rad);
  const y = 550 + r * Math.sin(rad);
  return (
    <div style={{
      position: 'absolute', left: x, top: y, transform: 'translate(-50%, -50%)',
      fontFamily: MONO_STACK, fontSize: 18, letterSpacing: '0.28em',
      color: accent || 'rgba(244,234,219,0.6)', fontWeight: 600,
      background: V2.night, padding: '6px 12px', whiteSpace: 'nowrap',
    }}>{text}</div>
  );
}

function ExBox({ label, sub, active, accent }) {
  return (
    <div style={{
      padding: '22px 30px',
      border: active ? `1.5px solid ${accent}` : '1px solid rgba(244,234,219,0.18)',
      background: active ? hexAlpha(accent, 0.10) : 'rgba(244,234,219,0.04)',
      borderRadius: 14, minWidth: 320,
    }}>
      <div style={{
        fontSize: 26, fontWeight: 700, color: active ? accent : '#F4EADB', letterSpacing: '-0.005em',
      }}>{label}</div>
      <div style={{
        marginTop: 6, fontFamily: MONO_STACK, fontSize: 16, letterSpacing: '0.16em', textTransform: 'uppercase',
        color: 'rgba(244,234,219,0.5)',
      }}>{sub}</div>
    </div>
  );
}

Object.assign(window, { V2Shot4, V2Shot5, V2Shot6, V2Shot7 });
