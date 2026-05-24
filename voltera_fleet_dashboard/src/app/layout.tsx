import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Voltera Fleet',
  description: 'OBD-II fleet monitoring · ICE USV demo',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ro">
      <body>{children}</body>
    </html>
  )
}
