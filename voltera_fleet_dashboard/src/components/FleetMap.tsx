'use client'

import { useEffect, useRef, useState } from 'react'
import maplibregl, { Map } from 'maplibre-gl'
import { supabase, type FleetStatusRow } from '@/lib/supabase'
import { ROUTES } from '@/lib/mock/routes'
import { getGhostPositions, REAL_DEVICE_VEHICLE_ID } from '@/lib/mock/simulator'
import { SUCEAVA_POIS, type POI } from '@/lib/suceava-pois'
import { getMapStyle } from '@/lib/map-style'
import { themeFlag, getInitialTheme, type Theme } from '@/lib/ui-state'

/** Culori care depind de tema pentru rendering MapLibre (paint properties). */
type UiPalette = {
  textColor: string
  textHalo: string
  poiStroke: string
  arrowIcon: string
  arrowHalo: string
  ghostFill: string
  ghostStroke: string
}

const UI_PALETTE: Record<Theme, UiPalette> = {
  dark: {
    textColor: '#e2e8f0',
    textHalo: '#06080C',
    poiStroke: '#06080C',
    arrowIcon: '#ffffff',
    arrowHalo: '#06080C',
    ghostFill: '#94a3b8',
    ghostStroke: '#06080C',
  },
  light: {
    textColor: '#0f172a',
    textHalo: '#ffffff',
    poiStroke: '#ffffff',
    arrowIcon: '#0f172a',
    arrowHalo: '#ffffff',
    ghostFill: '#475569',
    ghostStroke: '#ffffff',
  },
}

const POI_COLORS: Record<POI['category'], string> = {
  university: '#22d3ee',
  shopping: '#fb923c',
  transit: '#facc15',
  landmark: '#e2e8f0',
  service: '#94a3b8',
}

const DEMO_MODE = process.env.NEXT_PUBLIC_DEMO_MODE === 'true'

type Props = {
  vehicles: FleetStatusRow[]
  onSelect: (vehicleId: string) => void
  selectedId: string | null
  onLivePosition?: (vehicleId: string, lat: number, lon: number) => void
  onMapReady?: (map: Map) => void
}

/**
 * FleetMap — toate elementele randate ca MapLibre layers (GPU, lat/lon exact).
 *
 * Layers (de jos in sus):
 *   - routes-line: traseele celor 3 vehicule, fiecare in culoarea vehiculului
 *   - vehicles-glow: halou cyan pe selectat
 *   - vehicles-shadow: cerc colorat dupa status sub sageata (footprint)
 *   - vehicles-arrow: SDF arrow alb, rotit dupa heading
 */

type HeadingState = {
  lastLat: number
  lastLon: number
  heading: number
}

const MIN_MOVE_DEG = 1.5e-4 // ~15m anti-jitter pentru heading

const STATUS_COLORS: Record<FleetStatusRow['status'], string> = {
  driving: '#22c55e',
  idle: '#facc15',
  alert: '#ef4444',
  offline: '#4b5563',
}

// Maparea route_id → culoarea vehiculului (sincronizata cu simulator.ts)
const ROUTE_COLORS: Record<string, string> = {
  centru: '#22d3ee', // Honda Civic — Ion (Suceava)
  'nord-est': '#a78bfa', // BMW — Maria (Suceava)
  gara: '#fb923c', // VW Golf — Stefan (Suceava)
  'est-industrial': '#f8fafc', // Device OBD-II (EU) — Suceava periferie est
  munich: '#ef4444', // Mercedes Actros — Hans (Munchen)
  lyon: '#16a34a', // Renault T — Pierre (Lyon)
}

function bearingDeg(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number {
  const toRad = (d: number) => (d * Math.PI) / 180
  const dLon = toRad(lon2 - lon1)
  const lat1R = toRad(lat1)
  const lat2R = toRad(lat2)
  const y = Math.sin(dLon) * Math.cos(lat2R)
  const x =
    Math.cos(lat1R) * Math.sin(lat2R) -
    Math.sin(lat1R) * Math.cos(lat2R) * Math.cos(dLon)
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360
}

/** Simple chevron arrow, pointing UP at heading=0. SDF-tintable. */
const ARROW_SVG = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 32" width="48" height="64"><path d="M12 2 L22 28 L12 22 L2 28 Z" fill="white"/></svg>`

function loadArrowImage(): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.onload = () => resolve(img)
    img.onerror = (e) => reject(e)
    img.src = 'data:image/svg+xml;base64,' + btoa(ARROW_SVG)
  })
}

type VehicleProps = {
  vehicle_id: string
  status: FleetStatusRow['status']
  status_color: string
  heading: number
  selected: boolean
  /** "truck" pentru camioane (Mercedes Actros, Renault T) — randate mai mari */
  v_type: 'car' | 'truck'
  /** True doar pentru device-ul real (tableta) — primeste halo verde special */
  is_real_device: boolean
}

const TRUCK_MAKES = new Set(['Mercedes-Benz', 'Renault'])

export default function FleetMap({
  vehicles,
  onSelect,
  selectedId,
  onLivePosition,
  onMapReady,
}: Props) {
  const containerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<Map | null>(null)
  const headingRef = useRef<Record<string, HeadingState>>({})
  const livePosRef = useRef<Record<string, { lat: number; lon: number }>>({})
  const selectedIdRef = useRef<string | null>(selectedId)
  const onSelectRef = useRef(onSelect)
  const onMapReadyRef = useRef(onMapReady)
  const [mapReady, setMapReady] = useState(false)

  selectedIdRef.current = selectedId
  onSelectRef.current = onSelect
  onMapReadyRef.current = onMapReady

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return

    const initialTheme = getInitialTheme()
    const map = new maplibregl.Map({
      container: containerRef.current,
      style: getMapStyle(initialTheme),
      // Cinematic intro: incepem de la zoom 4 (Europa) → zoom in pe Suceava
      center: [26.2553, 47.6519],
      zoom: 4.5,
      pitch: 0,
      bearing: 0,
      attributionControl: false,
      pixelRatio: window.devicePixelRatio,
    })
    map.addControl(
      new maplibregl.NavigationControl({
        showCompass: true,
        showZoom: true,
        visualizePitch: true,
      }),
      'top-right',
    )

    mapRef.current = map

    // ---- Refolosibil: configureaza toate sursele + layers custom ----
    // Apelat la initial load si dupa fiecare setStyle (cand schimbi tema).
    const setupCustomLayers = async (theme: Theme) => {
      const ui = UI_PALETTE[theme]

      // ---- 1. ROUTES — colorate per vehicul ----
      const routeFeatures: GeoJSON.Feature<
        GeoJSON.LineString,
        { color: string; route_id: string }
      >[] = Object.values(ROUTES).map((r) => ({
        type: 'Feature',
        properties: {
          color: ROUTE_COLORS[r.id] ?? '#5b6479',
          route_id: r.id,
        },
        geometry: { type: 'LineString', coordinates: r.waypoints },
      }))

      map.addSource('routes', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: routeFeatures },
      })

      // Glow subtil sub traseu
      map.addLayer({
        id: 'routes-glow',
        type: 'line',
        source: 'routes',
        paint: {
          'line-color': ['get', 'color'],
          'line-width': [
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            5,
            14,
            8,
            18,
            12,
          ],
          'line-opacity': 0.15,
          'line-blur': 3,
        },
        layout: { 'line-cap': 'round', 'line-join': 'round' },
      })
      // Linia propriu-zisa, vizibila
      map.addLayer({
        id: 'routes-line',
        type: 'line',
        source: 'routes',
        paint: {
          'line-color': ['get', 'color'],
          'line-width': [
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            1.5,
            14,
            2.4,
            18,
            3.2,
          ],
          'line-opacity': 0.55,
        },
        layout: { 'line-cap': 'round', 'line-join': 'round' },
      })

      // ---- 1.5 PUNCTE DE REPER SUCEAVA (USV, Kaufland, Mall, etc) ----
      const poiFeatures: GeoJSON.Feature<
        GeoJSON.Point,
        { name: string; short: string; category: POI['category']; color: string }
      >[] = SUCEAVA_POIS.map((p) => ({
        type: 'Feature',
        properties: {
          name: p.name,
          short: p.short,
          category: p.category,
          color: POI_COLORS[p.category],
        },
        geometry: { type: 'Point', coordinates: [p.lon, p.lat] },
      }))

      map.addSource('pois', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: poiFeatures },
      })

      // Dot colorat sub fiecare POI
      map.addLayer({
        id: 'pois-dot',
        type: 'circle',
        source: 'pois',
        minzoom: 11.5,
        paint: {
          'circle-color': ['get', 'color'],
          'circle-radius': [
            'interpolate',
            ['linear'],
            ['zoom'],
            11.5,
            1.8,
            14,
            3.2,
            17,
            5,
          ],
          'circle-stroke-color': ui.poiStroke,
          'circle-stroke-width': 1.5,
          'circle-opacity': 0.95,
        },
      })

      // Text label
      map.addLayer({
        id: 'pois-label',
        type: 'symbol',
        source: 'pois',
        minzoom: 12,
        layout: {
          'text-field': ['get', 'short'],
          'text-font': ['Noto Sans Bold'],
          'text-size': [
            'interpolate',
            ['linear'],
            ['zoom'],
            12,
            10,
            14,
            11.5,
            17,
            13,
          ],
          'text-offset': [0, 0.95],
          'text-anchor': 'top',
          'text-max-width': 8,
          'text-allow-overlap': false,
          'text-ignore-placement': false,
          'text-padding': 4,
          'text-letter-spacing': 0.04,
        },
        paint: {
          'text-color': ui.textColor,
          'text-halo-color': ui.textHalo,
          'text-halo-width': 1.8,
          'text-halo-blur': 0.5,
          'text-opacity': [
            'interpolate',
            ['linear'],
            ['zoom'],
            12,
            0,
            12.6,
            1,
          ],
        },
      })

      // ---- 2. INCARCA iconita arrow (doar daca nu e deja cached) ----
      if (!map.hasImage('voltera-arrow')) {
        try {
          const img = await loadArrowImage()
          if (!map.hasImage('voltera-arrow')) {
            map.addImage('voltera-arrow', img, { sdf: true })
          }
        } catch {
          /* fallback: nu va exista vehicles-arrow, raman doar cercurile */
        }
      }

      // ---- 2.5 GHOST TRAFFIC (vehicule ambient, anonime) ----
      if (DEMO_MODE) {
        map.addSource('ghosts', {
          type: 'geojson',
          data: { type: 'FeatureCollection', features: [] },
        })
        map.addLayer({
          id: 'ghosts-circle',
          type: 'circle',
          source: 'ghosts',
          paint: {
            'circle-color': ui.ghostFill,
            'circle-radius': [
              'interpolate',
              ['linear'],
              ['zoom'],
              11,
              1.5,
              14,
              2.8,
              17,
              4,
              20,
              6,
            ],
            'circle-opacity': 0.55,
            'circle-stroke-color': ui.ghostStroke,
            'circle-stroke-width': 0.8,
          },
        })
      }

      // ---- 3. VEHICULE ----
      map.addSource('vehicles', {
        type: 'geojson',
        data: { type: 'FeatureCollection', features: [] },
      })

      // Halou cyan outer — selectat (spotlight intensified)
      map.addLayer({
        id: 'vehicles-glow-outer',
        type: 'circle',
        source: 'vehicles',
        filter: ['==', ['get', 'selected'], true],
        paint: {
          'circle-color': '#00D4FF',
          'circle-radius': [
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            28,
            14,
            42,
            18,
            70,
          ],
          'circle-opacity': 0.18,
          'circle-blur': 1.5,
        },
      })
      // Halou cyan inner — mai concentrat
      map.addLayer({
        id: 'vehicles-glow',
        type: 'circle',
        source: 'vehicles',
        filter: ['==', ['get', 'selected'], true],
        paint: {
          'circle-color': '#00D4FF',
          'circle-radius': [
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            16,
            14,
            24,
            18,
            38,
          ],
          'circle-opacity': 0.55,
          'circle-blur': 0.8,
        },
      })

      // Real device — halo verde pulsatoriu (doar pentru tableta ta)
      map.addLayer({
        id: 'real-device-halo-outer',
        type: 'circle',
        source: 'vehicles',
        filter: ['==', ['get', 'is_real_device'], true],
        paint: {
          'circle-color': '#22c55e',
          'circle-radius': [
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            22,
            14,
            36,
            18,
            56,
          ],
          'circle-opacity': 0.15,
          'circle-blur': 1.2,
        },
      })
      map.addLayer({
        id: 'real-device-halo-inner',
        type: 'circle',
        source: 'vehicles',
        filter: ['==', ['get', 'is_real_device'], true],
        paint: {
          'circle-color': '#22c55e',
          'circle-radius': [
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            14,
            14,
            22,
            18,
            36,
          ],
          'circle-opacity': 0.32,
          'circle-blur': 0.6,
          'circle-stroke-color': '#16a34a',
          'circle-stroke-width': 2,
          'circle-stroke-opacity': 0.85,
        },
      })

      // Cerc shadow (footprint colorat sub sageata) — camioane mai mari
      map.addLayer({
        id: 'vehicles-shadow',
        type: 'circle',
        source: 'vehicles',
        paint: {
          'circle-color': ['get', 'status_color'],
          'circle-radius': [
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            ['case', ['==', ['get', 'v_type'], 'truck'], 10, 7],
            14,
            ['case', ['==', ['get', 'v_type'], 'truck'], 15, 11],
            18,
            ['case', ['==', ['get', 'v_type'], 'truck'], 24, 18],
          ],
          'circle-opacity': 0.55,
          'circle-blur': 0.4,
        },
      })

      // Sageata SDF rotita dupa heading
      map.addLayer({
        id: 'vehicles-arrow',
        type: 'symbol',
        source: 'vehicles',
        layout: {
          'icon-image': 'voltera-arrow',
          'icon-size': [
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            ['case', ['==', ['get', 'v_type'], 'truck'], 0.42, 0.3],
            14,
            ['case', ['==', ['get', 'v_type'], 'truck'], 0.6, 0.45],
            18,
            ['case', ['==', ['get', 'v_type'], 'truck'], 0.9, 0.7],
          ],
          'icon-rotate': ['get', 'heading'],
          'icon-rotation-alignment': 'map',
          'icon-pitch-alignment': 'map',
          'icon-allow-overlap': true,
          'icon-ignore-placement': true,
          'icon-anchor': 'center',
        },
        paint: {
          'icon-color': ui.arrowIcon,
          'icon-halo-color': ui.arrowHalo,
          'icon-halo-width': 1,
          'icon-opacity': 0.98,
        },
      })
    }
    // ---- END setupCustomLayers ----

    map.on('load', async () => {
      await setupCustomLayers(initialTheme)

      // ---- 4. CLICK + HOVER (atasate o singura data — supravietuiesc setStyle) ----
      const handleClick = (e: maplibregl.MapLayerMouseEvent) => {
        const f = e.features?.[0]
        if (f?.properties?.vehicle_id) {
          onSelectRef.current(f.properties.vehicle_id as string)
        }
      }
      map.on('click', 'vehicles-arrow', handleClick)
      map.on('click', 'vehicles-shadow', handleClick)

      const setPointer = () => {
        map.getCanvas().style.cursor = 'pointer'
      }
      const clearPointer = () => {
        map.getCanvas().style.cursor = ''
      }
      map.on('mouseenter', 'vehicles-arrow', setPointer)
      map.on('mouseleave', 'vehicles-arrow', clearPointer)
      map.on('mouseenter', 'vehicles-shadow', setPointer)
      map.on('mouseleave', 'vehicles-shadow', clearPointer)

      setMapReady(true)
      onMapReadyRef.current?.(map)

      // ---- PULSE animation pentru real-device halo (1Hz breathing) ----
      let pulseT = 0
      const pulseInterval = window.setInterval(() => {
        if (!mapRef.current) return
        pulseT = (pulseT + 0.08) % (Math.PI * 2)
        const breathe = (Math.sin(pulseT) + 1) / 2 // 0..1
        const outerOpacity = 0.08 + breathe * 0.18
        const innerOpacity = 0.18 + breathe * 0.25
        try {
          if (mapRef.current.getLayer('real-device-halo-outer')) {
            mapRef.current.setPaintProperty(
              'real-device-halo-outer',
              'circle-opacity',
              outerOpacity,
            )
          }
          if (mapRef.current.getLayer('real-device-halo-inner')) {
            mapRef.current.setPaintProperty(
              'real-device-halo-inner',
              'circle-opacity',
              innerOpacity,
            )
          }
        } catch {
          /* layer may not exist mid theme switch */
        }
      }, 80)

      // ---- CINEMATIC INTRO: zoom-in din Europa pe Suceava (3.5s) ----
      window.setTimeout(() => {
        map.flyTo({
          center: [26.2553, 47.6519],
          zoom: 13,
          pitch: 35,
          bearing: 0,
          duration: 3500,
          essential: true,
          curve: 1.42,
        })
      }, 350)
    })

    // ---- THEME SWITCH: setStyle + re-add custom layers ----
    const themeUnsub = themeFlag.subscribe((newTheme) => {
      if (!mapRef.current) return
      setMapReady(false)
      map.setStyle(getMapStyle(newTheme), { diff: false })
      map.once('style.load', async () => {
        await setupCustomLayers(newTheme)
        setMapReady(true)
      })
    })

    return () => {
      themeUnsub()
      map.remove()
      mapRef.current = null
    }
  }, [])

  const buildFeatures = (
    vehiclesIn: FleetStatusRow[],
    selectedIdIn: string | null,
  ): GeoJSON.FeatureCollection<GeoJSON.Point, VehicleProps> => {
    const features: GeoJSON.Feature<GeoJSON.Point, VehicleProps>[] = []
    for (const v of vehiclesIn) {
      const live = livePosRef.current[v.vehicle_id]
      const lat = live?.lat ?? v.lat
      const lon = live?.lon ?? v.lon
      if (lat == null || lon == null) continue
      features.push({
        type: 'Feature',
        geometry: { type: 'Point', coordinates: [lon, lat] },
        properties: {
          vehicle_id: v.vehicle_id,
          status: v.status,
          status_color: STATUS_COLORS[v.status],
          heading: headingRef.current[v.vehicle_id]?.heading ?? 0,
          selected: v.vehicle_id === selectedIdIn,
          v_type: TRUCK_MAKES.has(v.make ?? '') ? 'truck' : 'car',
          is_real_device: v.vehicle_id === REAL_DEVICE_VEHICLE_ID,
        },
      })
    }
    return { type: 'FeatureCollection', features }
  }

  const updateHeading = (vehicleId: string, lat: number, lon: number): void => {
    const prev = headingRef.current[vehicleId]
    if (!prev) {
      headingRef.current[vehicleId] = { lastLat: lat, lastLon: lon, heading: 0 }
      return
    }
    const dlat = lat - prev.lastLat
    const dlon = lon - prev.lastLon
    if (Math.abs(dlat) < MIN_MOVE_DEG && Math.abs(dlon) < MIN_MOVE_DEG) {
      return
    }
    prev.heading = bearingDeg(prev.lastLat, prev.lastLon, lat, lon)
    prev.lastLat = lat
    prev.lastLon = lon
  }

  useEffect(() => {
    const map = mapRef.current
    if (!map || !mapReady) return
    const src = map.getSource('vehicles') as
      | maplibregl.GeoJSONSource
      | undefined
    src?.setData(buildFeatures(vehicles, selectedId))
  }, [vehicles, selectedId, mapReady])

  // ---- Ghosts polling (4Hz) ----
  useEffect(() => {
    if (!mapReady || !DEMO_MODE) return
    const update = () => {
      const map = mapRef.current
      if (!map) return
      const src = map.getSource('ghosts') as
        | maplibregl.GeoJSONSource
        | undefined
      if (!src) return
      const ghosts = getGhostPositions()
      src.setData({
        type: 'FeatureCollection',
        features: ghosts.map((g) => ({
          type: 'Feature',
          geometry: { type: 'Point', coordinates: [g.lon, g.lat] },
          properties: {},
        })),
      })
    }
    update()
    const id = window.setInterval(update, 250)
    return () => clearInterval(id)
  }, [mapReady])

  useEffect(() => {
    if (!mapReady) return
    const channel = supabase
      .channel('telemetry-live')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'telemetry_samples',
        },
        (payload) => {
          const s = payload.new as {
            vehicle_id: string
            lat: number | null
            lon: number | null
          }
          if (s.lat == null || s.lon == null) return
          updateHeading(s.vehicle_id, s.lat, s.lon)
          livePosRef.current[s.vehicle_id] = { lat: s.lat, lon: s.lon }
          onLivePosition?.(s.vehicle_id, s.lat, s.lon)
          const map = mapRef.current
          if (!map) return
          const src = map.getSource('vehicles') as
            | maplibregl.GeoJSONSource
            | undefined
          src?.setData(buildFeatures(vehicles, selectedIdRef.current))
        },
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [mapReady, vehicles, onLivePosition])

  useEffect(() => {
    if (!mapRef.current) return
    // Deselect: revin la pitch redus, zoom out
    if (!selectedId) {
      mapRef.current.easeTo({
        pitch: 35,
        duration: 700,
      })
      return
    }
    const v = vehicles.find((x) => x.vehicle_id === selectedId)
    const live = livePosRef.current[selectedId]
    const lat = live?.lat ?? v?.lat
    const lon = live?.lon ?? v?.lon
    if (lat != null && lon != null) {
      // Spotlight: zoom + pitch 55° pentru efect cinematic cu 3D buildings
      mapRef.current.flyTo({
        center: [lon, lat],
        zoom: 16.5,
        pitch: 55,
        speed: 1.2,
        padding: { right: 440 },
      })
    }
  }, [selectedId, vehicles])

  return (
    <>
      <div ref={containerRef} className="absolute inset-0" />
      <div className="pointer-events-none absolute bottom-2 left-1/2 z-50 -translate-x-1/2 rounded-full border border-cyan/40 bg-bg/80 px-2.5 py-1 font-mono text-[10px] tracking-widest text-cyan backdrop-blur">
        v4 · ARROWS + ROUTES · {new Date().toLocaleTimeString('ro-RO').slice(0, 5)}
      </div>
    </>
  )
}
