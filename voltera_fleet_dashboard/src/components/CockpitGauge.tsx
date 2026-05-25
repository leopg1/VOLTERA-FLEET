'use client'

/**
 * CockpitGauge — cadran arc Tesla-style cu ac animat smooth.
 * SVG viewBox 100x100, arc 270° deschis in jos (de la stanga jos la dreapta jos).
 * Acul (.needle) si arc-ul foreground (.fg) tranzitioneaza ease-out-quart 250ms.
 *
 * Props:
 *  value, max — valoarea curenta + maxim (mapeaza la angle -135° .. +135°)
 *  color      — culoarea acului si arcului foreground
 *  redlineFrom — opt: prag peste care arcul devine rosu (ex. RPM redline 5500/7000)
 */

type Props = {
  value: number
  max: number
  unit: string
  label: string
  color?: string
  redlineFrom?: number
}

// Full 270° arc: -135 .. +135. Length = 2π·30·(270/360) ≈ 141
const ARC_PATH = 'M 28.79 71.21 A 30 30 0 1 1 71.21 71.21'
const ARC_LENGTH = 141.37

export default function CockpitGauge({
  value,
  max,
  unit,
  label,
  color = '#00D4FF',
  redlineFrom,
}: Props) {
  const safe = Math.max(0, Math.min(value, max))
  const pct = safe / max
  const needleAngle = -135 + pct * 270
  const fgLen = pct * ARC_LENGTH

  // In zona redline, schimba culoarea
  const inRedline = redlineFrom != null && safe >= redlineFrom
  const fgColor = inRedline ? '#ef4444' : color

  // Redline zone overlay (sectiunea care indica zona periculoasa)
  let redlineDash: string | undefined
  let redlineOffset: number | undefined
  if (redlineFrom != null) {
    const redStart = (redlineFrom / max) * ARC_LENGTH
    const redLen = ARC_LENGTH - redStart
    redlineDash = `${redLen} ${ARC_LENGTH}`
    redlineOffset = -redStart
  }

  return (
    <div className="cockpit-gauge">
      <div className="cockpit-gauge__svg-wrap">
        <svg
          viewBox="0 0 100 90"
          className="cockpit-gauge__svg"
          aria-hidden="true"
        >
          {/* Background arc */}
          <path
            d={ARC_PATH}
            stroke="rgba(255,255,255,0.08)"
            strokeWidth="5.5"
            fill="none"
            strokeLinecap="round"
          />
          {/* Redline marker (red zone hint) */}
          {redlineFrom != null && (
            <path
              d={ARC_PATH}
              stroke="rgba(239, 68, 68, 0.45)"
              strokeWidth="5.5"
              fill="none"
              strokeLinecap="butt"
              strokeDasharray={redlineDash}
              strokeDashoffset={redlineOffset}
            />
          )}
          {/* Foreground arc — sterge cu strokeDasharray ca progress */}
          <path
            d={ARC_PATH}
            stroke={fgColor}
            strokeWidth="5.5"
            fill="none"
            strokeLinecap="round"
            strokeDasharray={`${fgLen} ${ARC_LENGTH}`}
            style={{
              transition:
                'stroke-dasharray 250ms cubic-bezier(0.25, 1, 0.5, 1), stroke 200ms ease-out',
              filter: `drop-shadow(0 0 4px ${fgColor}99)`,
            }}
          />
          {/* Tick marks (small dashes around the arc) */}
          {Array.from({ length: 11 }, (_, i) => {
            const a = -135 + (i / 10) * 270
            const rad = ((a - 90) * Math.PI) / 180
            const x1 = 50 + 35 * Math.cos(rad)
            const y1 = 50 + 35 * Math.sin(rad)
            const x2 = 50 + 38 * Math.cos(rad)
            const y2 = 50 + 38 * Math.sin(rad)
            const isMajor = i % 2 === 0
            return (
              <line
                key={i}
                x1={x1}
                y1={y1}
                x2={x2}
                y2={y2}
                stroke="rgba(255,255,255,0.35)"
                strokeWidth={isMajor ? 1 : 0.5}
                strokeLinecap="round"
              />
            )
          })}
          {/* Needle */}
          <g
            transform={`rotate(${needleAngle} 50 50)`}
            style={{
              transformOrigin: '50px 50px',
              transition: 'transform 250ms cubic-bezier(0.25, 1, 0.5, 1)',
            }}
          >
            <line
              x1="50"
              y1="50"
              x2="50"
              y2="20"
              stroke="white"
              strokeWidth="1.5"
              strokeLinecap="round"
            />
            <line
              x1="50"
              y1="50"
              x2="50"
              y2="56"
              stroke="rgba(255,255,255,0.55)"
              strokeWidth="2"
              strokeLinecap="round"
            />
          </g>
          {/* Center hub */}
          <circle cx="50" cy="50" r="4" fill={fgColor} />
          <circle cx="50" cy="50" r="2" fill="#06080C" />
        </svg>
        <div className="cockpit-gauge__center">
          <div
            className="cockpit-gauge__value"
            style={{ color: inRedline ? '#ef4444' : 'white' }}
          >
            {safe.toFixed(0)}
          </div>
          <div className="cockpit-gauge__unit">{unit}</div>
        </div>
      </div>
      <div className="cockpit-gauge__label">{label}</div>
    </div>
  )
}
