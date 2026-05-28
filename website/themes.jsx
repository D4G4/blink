// Blink themes — exact hex values from blink-macos/Blink/Theme/BlinkTheme.swift
// Gradient direction in SwiftUI LinearGradient(topLeading → bottomTrailing)
// = CSS linear-gradient(135deg, …)

const THEMES = {
  peach: {
    name: 'Peach',
    accent: '#E88565',
    light: {
      bg: ['#FFB89A', '#F09060'],
      overlayBg: 'rgba(255,240,232,0.95)', // #FFF0E8 @ 95%
      overlayText: '#3D2012',
      onBgText: '#FFFFFF',
    },
    dark: {
      bg: ['#2A1408', '#180A04'],
      overlayBg: 'rgba(26,14,8,0.92)',
      overlayText: '#FFDDCC',
      onBgText: '#FFFFFF',
    },
  },
  midnight: {
    name: 'Midnight',
    accent: '#6B7DB5',
    light: {
      bg: ['#2B2D52', '#1A1B3A'],
      overlayBg: 'rgba(232,234,244,0.95)',
      overlayText: '#1A1B3A',
      onBgText: '#FFFFFF',
    },
    dark: {
      bg: ['#14152C', '#0A0B1A'],
      overlayBg: 'rgba(12,12,26,0.95)',
      overlayText: '#B8C0E0',
      onBgText: '#FFFFFF',
    },
  },
  sage: {
    name: 'Sage',
    accent: '#6EA87E',
    light: {
      bg: ['#B8D4BC', '#7BAF8A'],
      overlayBg: 'rgba(234,245,236,0.95)',
      overlayText: '#1A3520',
      onBgText: '#FFFFFF',
    },
    dark: {
      bg: ['#1A2D20', '#0E1A12'],
      overlayBg: 'rgba(10,26,14,0.92)',
      overlayText: '#C8EED0',
      onBgText: '#FFFFFF',
    },
  },
  sand: {
    name: 'Sand',
    accent: '#9A9478',
    light: {
      bg: ['#D8D0B8', '#B5AC8E'],
      overlayBg: 'rgba(242,240,232,0.95)',
      overlayText: '#2E2A1E',
      onBgText: '#FFFFFF',
    },
    dark: {
      bg: ['#2A251A', '#18160E'],
      overlayBg: 'rgba(20,18,12,0.92)',
      overlayText: '#E8E0CC',
      onBgText: '#FFFFFF',
    },
  },
  mono: {
    name: 'Mono',
    // invertInDarkMode: true — accent flips to white in dark mode
    accent: '#222222',
    accentDark: '#FFFFFF',
    light: {
      bg: ['#F5F5F5', '#E8E8E8'],
      overlayBg: 'rgba(250,250,250,0.98)',
      overlayText: '#1A1A1A',
      onBgText: '#1A1A1A',  // NOT white — dark text on light bg
    },
    dark: {
      bg: ['#1A1A1A', '#111111'],
      overlayBg: 'rgba(10,10,10,0.95)',
      overlayText: '#F0F0F0',
      onBgText: '#FFFFFF',
    },
  },
};

// Helper: resolve a theme for a given mode (returns a flat object)
function resolveTheme(key, mode = 'light') {
  const t = THEMES[key];
  const m = t[mode];
  const accent = (key === 'mono' && mode === 'dark') ? t.accentDark : t.accent;
  return {
    key,
    name: t.name,
    mode,
    isDark: mode === 'dark',
    accent,
    bg: m.bg,                                  // [from, to]
    bgGradient: `linear-gradient(135deg, ${m.bg[0]} 0%, ${m.bg[1]} 100%)`,
    overlayBg: m.overlayBg,
    overlayText: m.overlayText,
    overlayTextMute: hexAlpha(m.overlayText, 0.6),
    onBgText: m.onBgText,
    onBgTextMute: m.onBgText === '#FFFFFF'
      ? 'rgba(255,255,255,0.75)'
      : 'rgba(26,26,26,0.62)',
  };
}

function hexAlpha(hex, a) {
  const h = hex.replace('#', '');
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  return `rgba(${r},${g},${b},${a})`;
}

// SF Pro stack — Apple-native
const FONT_STACK = `-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Helvetica Neue", system-ui, sans-serif`;
const MONO_STACK = `ui-monospace, "SF Mono", "JetBrains Mono", Menlo, monospace`;

// Mascot — chunky rounded square with theme-accent gradient and a "B"
// counter-letter with a "20" badge tucked in the lower-right (reads as a
// face peeking out from the onboarding screenshot).
function BlinkIcon({ size = 260, themeKey = 'peach', mode = 'light' }) {
  // Real app icon (the shipped 1024px PNG per theme), not a redrawn vector.
  const shadow = `drop-shadow(0 ${Math.round(size * 0.1)}px ${Math.round(size * 0.2)}px rgba(0,0,0,0.16))`;
  return (
    <img
      src={`blink-icon-${themeKey}.png`}
      width={size}
      height={size}
      alt=""
      style={{ display: 'block', filter: shadow }}
    />
  );
}

// Stylized macOS wallpaper (light, used as compositing backdrop in shots
// 2 and 3). Recognizable, not pixel-true to any released wallpaper.
function MacWallpaper({ children }) {
  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: 'linear-gradient(180deg, #c8e1fa 0%, #98c2ec 30%, #5e8fcf 55%, #335ea0 80%, #1f3d75 100%)',
      overflow: 'hidden',
    }}>
      <svg viewBox="0 0 1600 1000" preserveAspectRatio="none" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
        <defs>
          <linearGradient id="ww1" x1="0" y1="0" x2="1" y2="0.5">
            <stop offset="0" stopColor="#dceaf8" stopOpacity="0.85" />
            <stop offset="0.6" stopColor="#a9cef6" stopOpacity="0.3" />
            <stop offset="1" stopColor="#7eb1ec" stopOpacity="0" />
          </linearGradient>
        </defs>
        <path d="M0 600 Q 400 480 800 580 T 1600 540 L 1600 1000 L 0 1000 Z" fill="url(#ww1)" />
        <path d="M0 700 Q 500 600 1000 690 T 1600 660 L 1600 1000 L 0 1000 Z" fill="#5896d8" opacity="0.9" />
        <path d="M0 800 Q 350 730 800 780 T 1600 760 L 1600 1000 L 0 1000 Z" fill="#3675c2" opacity="0.95" />
        <path d="M0 890 Q 500 850 1000 875 T 1600 870 L 1600 1000 L 0 1000 Z" fill="#1f4f99" />
        <path d="M0 180 Q 600 110 1100 220 T 1600 200" stroke="rgba(255,255,255,0.4)" strokeWidth="3" fill="none" />
      </svg>
      {children}
    </div>
  );
}

Object.assign(window, { THEMES, FONT_STACK, MONO_STACK, BlinkIcon, MacWallpaper, resolveTheme, hexAlpha });
