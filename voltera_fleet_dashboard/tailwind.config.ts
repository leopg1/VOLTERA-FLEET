import type { Config } from 'tailwindcss'

export default {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        bg: '#07090F',
        surface: '#0D1117',
        surfaceHi: '#131A22',
        border: '#1F2937',
        cyan: { DEFAULT: '#00D4FF', deep: '#0091B8' },
        ok: '#00E676',
        warn: '#FFC400',
        danger: '#FF1744',
        textMuted: '#8892A4',
        textDim: '#4A5260',
      },
      fontFamily: {
        display: ['Orbitron', 'system-ui', 'sans-serif'],
        body: ['Rajdhani', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
} satisfies Config
