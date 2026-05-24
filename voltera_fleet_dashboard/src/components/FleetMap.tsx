'use client'

import { useEffect, useRef, useState } from 'react'
import maplibregl, { Map, Marker } from 'maplibre-gl'
import { supabase, type FleetStatusRow } from '@/lib/supabase'

const STATUS_COLORS: Record<FleetStatusRow['status'], string> = {
  driving: '#00E676',
  idle: '#FFC400',
  alert: '#FF1744',
  offline: '#4A5260',
}

type Props = {
  vehicles: FleetStatusRow[]
  onSelect: (vehicleId: string) => void
  selectedId: string | null
  onLivePosition?: (vehicleId: string, lat: number, lon: number) => void
}

/**
 * Mapa live cu pinii flotei.
 *
 * Sursa de adevar pentru pozitia *de baza* este props.vehicles (poll fleet_status).
 * Peste asta, ne abonam la INSERT-urile din telemetry_samples — orice nou sample
 * misca pinul respectiv instant (sub 100ms latenta), fara sa astepte urmatorul poll.
 * Pentru vehiculul selectat, mentinem si un "trail" — ultimele N puncte ca polyline,
 * ca user-ul sa vada miscarea, nu doar pozitia finala.
 */
export default function FleetMap({
  vehicles,
  onSelect,
  selectedId,
  onLivePosition,
}: Props) {
  const containerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<Map | null>(null)
  const markersRef = useRef<Record<string, Marker>>({})
  const trailRef = useRef<Array<[number, number]>>([])
  const [mapReady, setMapReady] = useState(false)

  // ---- Map init ----
  useEffect(() => {
    if (!containerRef.current || mapRef.current) return

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: 'https://tiles.openfreemap.org/styles/dark',
      center: [26.2553, 47.6519],
      zoom: 12,
      attributionControl: false,
    })
    map.addControl(new maplibregl.NavigationControl({ showCompass: true }), 'top-right')
    map.addControl(new maplibregl.AttributionControl({ compact: true }), 'bottom-right')

    map.on('load', () => {
      // Sursa + layer pentru trail-ul vehiculului selectat
      map.addSource('trail', {
        type: 'geojson',
        data: {
          type: 'FeatureCollection',
          features: [],
        },
      })
      map.addLayer({
        id: 'trail-glow',
        type: 'line',
        source: 'trail',
        paint: {
          'line-color': '#00D4FF',
          'line-width': 8,
          'line-opacity': 0.15,
          'line-blur': 4,
        },
        layout: { 'line-cap': 'round', 'line-join': 'round' },
      })
      map.addLayer({
        id: 'trail-line',
        type: 'line',
        source: 'trail',
        paint: {
          'line-color': '#00D4FF',
          'line-width': 3,
          'line-opacity': 0.85,
        },
        layout: { 'line-cap': 'round', 'line-join': 'round' },
      })
      setMapReady(true)
    })

    mapRef.current = map

    return () => {
      map.remove()
      mapRef.current = null
      markersRef.current = {}
      trailRef.current = []
    }
  }, [])

  // ---- Sync markeri din fleet_status (poll de baza) ----
  useEffect(() => {
    const map = mapRef.current
    if (!map || !mapReady) return

    const seen = new Set<string>()

    vehicles.forEach((v) => {
      if (v.lat == null || v.lon == null) return
      seen.add(v.vehicle_id)

      const color = STATUS_COLORS[v.status]
      const isSelected = selectedId === v.vehicle_id
      const recentlyLive =
        v.last_seen_at &&
        Date.now() - new Date(v.last_seen_at).getTime() < 10_000

      let marker = markersRef.current[v.vehicle_id]
      if (!marker) {
        const el = document.createElement('div')
        el.className = 'vehicle-marker'
        const initials =
          (v.plate ?? '').replace(/\s+/g, '').slice(-2) || '??'
        el.innerHTML = `<span>${initials}</span>`
        el.style.background = color
        el.style.color = color
        el.addEventListener('click', (e) => {
          e.stopPropagation()
          onSelect(v.vehicle_id)
        })
        marker = new maplibregl.Marker({ element: el, anchor: 'center' })
          .setLngLat([v.lon, v.lat])
          .addTo(map)
        markersRef.current[v.vehicle_id] = marker
      } else {
        marker.setLngLat([v.lon, v.lat])
        const el = marker.getElement()
        el.style.background = color
        el.style.color = color
      }

      const el = marker.getElement()
      el.style.outline = isSelected ? '3px solid #00D4FF' : 'none'
      el.style.outlineOffset = '2px'
      el.style.zIndex = isSelected ? '10' : '1'

      // pulse = "live in ultimele 10s" sau "status alert"
      const wantPulse = v.status === 'alert' || recentlyLive
      const existingPulse = el.querySelector('.pulse')
      if (wantPulse && !existingPulse) {
        const p = document.createElement('div')
        p.className = 'pulse'
        el.appendChild(p)
      } else if (!wantPulse && existingPulse) {
        existingPulse.remove()
      }
    })

    Object.keys(markersRef.current).forEach((id) => {
      if (!seen.has(id)) {
        markersRef.current[id].remove()
        delete markersRef.current[id]
      }
    })
  }, [vehicles, onSelect, selectedId, mapReady])

  // ---- Realtime: misca markerul instant la fiecare sample nou ----
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
          const marker = markersRef.current[s.vehicle_id]
          if (marker) marker.setLngLat([s.lon, s.lat])
          onLivePosition?.(s.vehicle_id, s.lat, s.lon)

          // Adauga in trail daca e vehiculul selectat
          if (s.vehicle_id === selectedId) {
            trailRef.current.push([s.lon, s.lat])
            if (trailRef.current.length > 120) trailRef.current.shift()
            const src = mapRef.current?.getSource('trail') as
              | maplibregl.GeoJSONSource
              | undefined
            src?.setData({
              type: 'FeatureCollection',
              features: [
                {
                  type: 'Feature',
                  properties: {},
                  geometry: {
                    type: 'LineString',
                    coordinates: trailRef.current,
                  },
                },
              ],
            })
          }
        },
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [mapReady, selectedId, onLivePosition])

  // ---- Schimba selected → reseteaza trail-ul ----
  useEffect(() => {
    trailRef.current = []
    const src = mapRef.current?.getSource('trail') as
      | maplibregl.GeoJSONSource
      | undefined
    src?.setData({ type: 'FeatureCollection', features: [] })
  }, [selectedId])

  // ---- Fly to selected ----
  useEffect(() => {
    if (!selectedId || !mapRef.current) return
    const v = vehicles.find((x) => x.vehicle_id === selectedId)
    if (v?.lat != null && v.lon != null) {
      mapRef.current.flyTo({
        center: [v.lon, v.lat],
        zoom: 15,
        speed: 1.2,
        padding: { right: 440 },
      })
    }
  }, [selectedId, vehicles])

  return <div ref={containerRef} className="absolute inset-0" />
}
