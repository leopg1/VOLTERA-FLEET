/**
 * Rute fixe pentru cele 5 vehicule din simulator.
 *
 * Geometriile sunt obtinute din OSRM (router.project-osrm.org) — fiecare ruta
 * urmareste DRUMURI REALE din Suceava cu rezolutie densa. Polilinia e bucla
 * (vehicul lapeaza in continuu).
 *
 * Pre-baked in `./routes-baked.ts`. Pentru a regenera (cand schimbi forma):
 * 1. Editeaza waypoint-urile-marker in /tmp/route_*.json comments / generator
 * 2. Re-run curl spre OSRM
 * 3. Regenereaza routes-baked.ts
 *
 * Format: [lon, lat] per punct (compatibil MapLibre/GeoJSON).
 */

import {
  ROUTE_CENTRU as BAKED_CENTRU,
  ROUTE_NORD_EST as BAKED_NORD_EST,
  ROUTE_GARA as BAKED_GARA,
  ROUTE_EST as BAKED_EST,
  ROUTE_VEST as BAKED_VEST,
  ROUTE_MUNICH as BAKED_MUNICH,
  ROUTE_LYON as BAKED_LYON,
} from './routes-baked'

export type Route = {
  id: string
  name: string
  waypoints: Array<[number, number]>
  /** Lungime totala a rutei in km (calculata din waypoints). */
  totalKm: number
}

/** Haversine pentru distanta intre 2 puncte [lon,lat] in km. */
function haversine(a: [number, number], b: [number, number]): number {
  const R = 6371
  const toRad = (d: number) => (d * Math.PI) / 180
  const dLat = toRad(b[1] - a[1])
  const dLon = toRad(b[0] - a[0])
  const lat1 = toRad(a[1])
  const lat2 = toRad(b[1])
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2
  return 2 * R * Math.asin(Math.sqrt(x))
}

function buildRoute(
  id: string,
  name: string,
  waypoints: Array<[number, number]>,
): Route {
  let total = 0
  for (let i = 1; i < waypoints.length; i++) {
    total += haversine(waypoints[i - 1], waypoints[i])
  }
  return { id, name, waypoints, totalKm: total }
}

export const ROUTES: Record<string, Route> = {
  centru: buildRoute('centru', 'Loop centru Suceava', BAKED_CENTRU),
  'nord-est': buildRoute('nord-est', 'Cartier nord-est', BAKED_NORD_EST),
  gara: buildRoute('gara', 'Drum spre gara', BAKED_GARA),
  'est-industrial': buildRoute(
    'est-industrial',
    'Periferie est',
    BAKED_EST,
  ),
  'vest-autostrada': buildRoute(
    'vest-autostrada',
    'Drum vest autostrada',
    BAKED_VEST,
  ),
  munich: buildRoute('munich', 'Munchen — centru', BAKED_MUNICH),
  lyon: buildRoute('lyon', 'Lyon — Presqu’ile', BAKED_LYON),
}

/**
 * Interpoleaza pozitia pe ruta la o distanta "kmAlong" din start (cumulative).
 * Returneaza [lon, lat, heading].
 */
export function interpolateRoute(
  route: Route,
  kmAlong: number,
): { lon: number; lat: number; heading: number } {
  const total = route.totalKm
  // Modulo: ruta e bucla, deci kmAlong > total = laps
  const k = ((kmAlong % total) + total) % total

  let acc = 0
  for (let i = 1; i < route.waypoints.length; i++) {
    const a = route.waypoints[i - 1]
    const b = route.waypoints[i]
    const segLen = haversine(a, b)
    if (acc + segLen >= k) {
      const t = (k - acc) / segLen
      const lon = a[0] + (b[0] - a[0]) * t
      const lat = a[1] + (b[1] - a[1]) * t
      const heading = bearing(a, b)
      return { lon, lat, heading }
    }
    acc += segLen
  }
  // Fallback (nu ar trebui sa ajunga aici dat fiind modulo)
  const last = route.waypoints[route.waypoints.length - 1]
  return { lon: last[0], lat: last[1], heading: 0 }
}

function bearing(a: [number, number], b: [number, number]): number {
  const toRad = (d: number) => (d * Math.PI) / 180
  const lat1 = toRad(a[1])
  const lat2 = toRad(b[1])
  const dLon = toRad(b[0] - a[0])
  const y = Math.sin(dLon) * Math.cos(lat2)
  const x =
    Math.cos(lat1) * Math.sin(lat2) -
    Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon)
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360
}
