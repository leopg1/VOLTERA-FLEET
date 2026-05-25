/**
 * Puncte de reper Suceava — coordonate REALE (extrase din OSM via Overpass API).
 * Doar landmark-uri pe care le-am verificat — fara aproximari.
 */

export type POI = {
  name: string
  short: string
  lat: number
  lon: number
  category: 'landmark' | 'shopping' | 'transit' | 'university' | 'service'
}

export const SUCEAVA_POIS: POI[] = [
  {
    name: 'Universitatea Ștefan cel Mare',
    short: 'USV',
    lat: 47.64116,
    lon: 26.24514,
    category: 'university',
  },
  {
    name: 'Kaufland Suceava',
    short: 'Kaufland',
    lat: 47.64287,
    lon: 26.24291,
    category: 'shopping',
  },
]
