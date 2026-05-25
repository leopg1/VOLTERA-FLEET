import type { StyleSpecification } from 'maplibre-gl'

/**
 * Voltera Map Style — dark si light, generate dintr-o paleta de culori.
 *
 * Filozofie: harta e scenografie tacuta. Drumurile formeaza o structura
 * abia perceptibila (ierarhie prin opacitate/luminozitate). Datele (markere
 * vehicule, alerte) sunt singurele elemente care poarta saturatie.
 *
 * Sursa de tiles: OpenFreeMap (vector tiles, schema OpenMapTiles v3).
 */

export type MapPalette = {
  /** Canvas — fundalul hartii */
  canvas: string
  /** Park / green spaces */
  park: string
  /** Apa */
  water: string
  /** Drumuri rezidențiale + service (tier 3) */
  roadTier3: string
  /** Drumuri secondary + tertiary (tier 2) */
  roadTier2: string
  /** Motorway/trunk/primary (tier 1) */
  roadTier1: string
  /** Outline subtil pentru tier1 la zoom mare */
  roadOutline: string
  /** Cladiri 3D — 4 stops dupa inaltime (de la mic la mare) */
  building: [string, string, string, string]
  /** Opacitate cladiri 3D */
  buildingOpacity: number
}

const DARK_PALETTE: MapPalette = {
  canvas: '#06080C',
  park: '#0A1218',
  water: '#0E1827',
  roadTier3: '#26344A',
  roadTier2: '#3A4A66',
  roadTier1: '#536683',
  roadOutline: '#0E1320',
  building: ['#1a2030', '#212a3d', '#2a364f', '#384664'],
  buildingOpacity: 0.88,
}

const LIGHT_PALETTE: MapPalette = {
  // "Voltera Sky" — light mode cu accent albastru, NU alb plat.
  // Inspiratie Apple Maps light / soft blue cartography.
  canvas: '#cfe0f5', // light sky blue — fundal aerian
  park: '#b8d8a8', // verde proaspat, vibrant
  water: '#7eb1d1', // albastru clar, saturat — apa adevarata
  roadTier3: '#a8c0d6', // soft blue-gray, vizibil
  roadTier2: '#7a90ad', // medium blue-gray
  roadTier1: '#4a5d7a', // deep slate-blue — vertebrala oraselor
  roadOutline: '#ffffff', // casing alb pe primary (separat clar de canvas)
  building: ['#bdcde0', '#9eb3cd', '#7c93b3', '#4f6589'], // gradient blue-gray cu adancime
  buildingOpacity: 0.94,
}

function buildStyle(palette: MapPalette, name: string): StyleSpecification {
  return {
    version: 8,
    name,
    metadata: { 'voltera:author': 'Voltera Fleet' },
    glyphs: 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf',
    sources: {
      openmaptiles: {
        type: 'vector',
        url: 'https://tiles.openfreemap.org/planet',
      },
    },
    layers: [
      {
        id: 'bg',
        type: 'background',
        paint: { 'background-color': palette.canvas },
      },
      {
        id: 'landuse-park',
        type: 'fill',
        source: 'openmaptiles',
        'source-layer': 'landuse',
        filter: ['in', 'class', 'park', 'cemetery', 'pitch', 'playground'],
        paint: {
          'fill-color': palette.park,
          'fill-antialias': true,
        },
      },
      {
        id: 'water',
        type: 'fill',
        source: 'openmaptiles',
        'source-layer': 'water',
        paint: {
          'fill-color': palette.water,
          'fill-antialias': true,
        },
      },
      {
        id: 'waterway',
        type: 'line',
        source: 'openmaptiles',
        'source-layer': 'waterway',
        paint: {
          'line-color': palette.water,
          'line-width': [
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            0.3,
            16,
            1.2,
          ],
        },
      },
      // ---- Roads: 3 tiers ----
      {
        id: 'roads-tier3',
        type: 'line',
        source: 'openmaptiles',
        'source-layer': 'transportation',
        filter: ['in', 'class', 'minor', 'service', 'track', 'path'],
        minzoom: 11,
        paint: {
          'line-color': palette.roadTier3,
          'line-width': [
            'interpolate',
            ['linear'],
            ['zoom'],
            11,
            0.6,
            13,
            1.6,
            15,
            2.6,
            18,
            4,
            20,
            6,
          ],
        },
        layout: { 'line-cap': 'round', 'line-join': 'round' },
      },
      {
        id: 'roads-tier2',
        type: 'line',
        source: 'openmaptiles',
        'source-layer': 'transportation',
        filter: ['in', 'class', 'secondary', 'tertiary'],
        paint: {
          'line-color': palette.roadTier2,
          'line-width': [
            'interpolate',
            ['linear'],
            ['zoom'],
            8,
            1,
            12,
            2.4,
            15,
            3.8,
            18,
            5.5,
            20,
            8,
          ],
        },
        layout: { 'line-cap': 'round', 'line-join': 'round' },
      },
      {
        id: 'roads-tier1-outline',
        type: 'line',
        source: 'openmaptiles',
        'source-layer': 'transportation',
        filter: ['in', 'class', 'motorway', 'trunk', 'primary'],
        minzoom: 12,
        paint: {
          'line-color': palette.roadOutline,
          'line-width': [
            'interpolate',
            ['linear'],
            ['zoom'],
            12,
            4,
            16,
            7,
            20,
            13,
          ],
        },
        layout: { 'line-cap': 'round', 'line-join': 'round' },
      },
      {
        id: 'roads-tier1',
        type: 'line',
        source: 'openmaptiles',
        'source-layer': 'transportation',
        filter: ['in', 'class', 'motorway', 'trunk', 'primary'],
        paint: {
          'line-color': palette.roadTier1,
          'line-width': [
            'interpolate',
            ['linear'],
            ['zoom'],
            5,
            1,
            10,
            2.6,
            14,
            4.2,
            16,
            5.5,
            18,
            7,
            20,
            10,
          ],
        },
        layout: { 'line-cap': 'round', 'line-join': 'round' },
      },
      // ---- 3D BUILDINGS ----
      {
        id: 'buildings-3d',
        type: 'fill-extrusion',
        source: 'openmaptiles',
        'source-layer': 'building',
        minzoom: 13,
        paint: {
          'fill-extrusion-color': [
            'interpolate',
            ['linear'],
            ['get', 'render_height'],
            0,
            palette.building[0],
            15,
            palette.building[1],
            40,
            palette.building[2],
            80,
            palette.building[3],
          ],
          'fill-extrusion-height': [
            'interpolate',
            ['linear'],
            ['zoom'],
            13,
            0,
            14.5,
            ['coalesce', ['get', 'render_height'], 8],
            16,
            ['coalesce', ['get', 'render_height'], 12],
          ],
          'fill-extrusion-base': [
            'interpolate',
            ['linear'],
            ['zoom'],
            13,
            0,
            14.5,
            ['coalesce', ['get', 'render_min_height'], 0],
          ],
          'fill-extrusion-opacity': palette.buildingOpacity,
        },
      },
      {
        id: 'boundary-country',
        type: 'line',
        source: 'openmaptiles',
        'source-layer': 'boundary',
        filter: ['==', 'admin_level', 2],
        maxzoom: 6,
        paint: {
          'line-color': palette.roadTier1,
          'line-width': 0.5,
          'line-dasharray': [3, 2],
        },
      },
    ],
  }
}

export const volteraDarkStyle: StyleSpecification = buildStyle(
  DARK_PALETTE,
  'Voltera Dark',
)

export const volteraLightStyle: StyleSpecification = buildStyle(
  LIGHT_PALETTE,
  'Voltera Light',
)

/** Backward-compat alias — codul existent foloseste asta. */
export const volteraMonochromeStyle = volteraDarkStyle

/** Helper pentru cod care alege dinamic in functie de tema. */
export function getMapStyle(theme: 'dark' | 'light'): StyleSpecification {
  return theme === 'light' ? volteraLightStyle : volteraDarkStyle
}
