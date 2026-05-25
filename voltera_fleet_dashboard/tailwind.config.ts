import type { Config } from 'tailwindcss'

export default {
  content: ['./src/**/*.{ts,tsx}'],
  darkMode: ['class', '[data-theme="dark"]'],
  theme: {
    extend: {
      colors: {
        // Toate culorile vin acum din CSS variables.
        // Fiecare are scheme dark/light definite in globals.css.
        bg: 'rgb(var(--c-bg) / <alpha-value>)',
        surface: 'rgb(var(--c-surface) / <alpha-value>)',
        surfaceHi: 'rgb(var(--c-surface-hi) / <alpha-value>)',
        border: 'rgb(var(--c-border) / <alpha-value>)',
        cyan: {
          DEFAULT: 'rgb(var(--c-cyan) / <alpha-value>)',
          deep: 'rgb(var(--c-cyan-deep) / <alpha-value>)',
        },
        ok: 'rgb(var(--c-ok) / <alpha-value>)',
        warn: 'rgb(var(--c-warn) / <alpha-value>)',
        danger: 'rgb(var(--c-danger) / <alpha-value>)',
        textStrong: 'rgb(var(--c-text-strong) / <alpha-value>)',
        textMuted: 'rgb(var(--c-text-muted) / <alpha-value>)',
        textDim: 'rgb(var(--c-text-dim) / <alpha-value>)',
      },
      fontFamily: {
        display: ['Orbitron', 'system-ui', 'sans-serif'],
        body: ['Rajdhani', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
} satisfies Config
