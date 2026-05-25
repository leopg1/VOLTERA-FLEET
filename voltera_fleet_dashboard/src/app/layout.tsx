import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Voltera Fleet',
  description: 'OBD-II fleet monitoring · ICE USV demo',
}

// Inline script — ruleaza inainte de hydration, aplica tema din localStorage
// ca sa nu existe flash dark → light la primul paint
const themeInitScript = `
(function() {
  try {
    var t = localStorage.getItem('voltera:theme');
    document.documentElement.setAttribute('data-theme', t === 'light' ? 'light' : 'dark');
  } catch (e) {
    document.documentElement.setAttribute('data-theme', 'dark');
  }
})();
`

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ro" data-theme="dark">
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeInitScript }} />
      </head>
      <body>{children}</body>
    </html>
  )
}
