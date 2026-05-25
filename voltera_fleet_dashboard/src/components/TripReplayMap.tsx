'use client'

import { useEffect, useRef } from 'react'
import maplibregl, { Map, LngLatBoundsLike } from 'maplibre-gl'
import type { TelemetrySample } from '@/lib/supabase'
import { volteraMonochromeStyle } from '@/lib/map-style'

type Props = {
  samples: TelemetrySample[]
  cursorIndex: number
}

export default function TripReplayMap({ samples, cursorIndex }: Props) {
  const containerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<Map | null>(null)
  const cursorRef = useRef<maplibregl.Marker | null>(null)

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return
    const map = new maplibregl.Map({
      container: containerRef.current,
      style: volteraMonochromeStyle,
      center: [26.2553, 47.6519],
      zoom: 12,
      attributionControl: false,
    })
    map.addControl(new maplibregl.NavigationControl(), 'top-right')
    mapRef.current = map
    return () => {
      map.remove()
      mapRef.current = null
    }
  }, [])

  // Add polyline once samples sunt incarcate
  useEffect(() => {
    const map = mapRef.current
    if (!map || samples.length < 2) return

    const points = samples
      .filter((s) => s.lat != null && s.lon != null)
      .map((s) => [s.lon!, s.lat!] as [number, number])
    if (points.length < 2) return

    const addOrUpdate = () => {
      const data: GeoJSON.Feature<GeoJSON.LineString> = {
        type: 'Feature',
        properties: {},
        geometry: { type: 'LineString', coordinates: points },
      }
      if (map.getSource('trip')) {
        ;(map.getSource('trip') as maplibregl.GeoJSONSource).setData(data)
      } else {
        map.addSource('trip', { type: 'geojson', data })
        map.addLayer({
          id: 'trip-line-glow',
          type: 'line',
          source: 'trip',
          layout: { 'line-cap': 'round', 'line-join': 'round' },
          paint: {
            'line-color': '#00D4FF',
            'line-width': 8,
            'line-opacity': 0.25,
            'line-blur': 4,
          },
        })
        map.addLayer({
          id: 'trip-line',
          type: 'line',
          source: 'trip',
          layout: { 'line-cap': 'round', 'line-join': 'round' },
          paint: { 'line-color': '#00D4FF', 'line-width': 3 },
        })
      }

      // Fit bounds
      const lats = points.map((p) => p[1])
      const lons = points.map((p) => p[0])
      const bounds: LngLatBoundsLike = [
        [Math.min(...lons), Math.min(...lats)],
        [Math.max(...lons), Math.max(...lats)],
      ]
      map.fitBounds(bounds, { padding: 80, duration: 600 })

      // Start marker
      if (!map.getLayer('trip-start')) {
        new maplibregl.Marker({ color: '#00E676' })
          .setLngLat(points[0])
          .addTo(map)
        new maplibregl.Marker({ color: '#FF1744' })
          .setLngLat(points[points.length - 1])
          .addTo(map)
      }
    }

    if (map.loaded()) addOrUpdate()
    else map.once('load', addOrUpdate)
  }, [samples])

  // Cursor marker (slider position)
  useEffect(() => {
    const map = mapRef.current
    const sample = samples[cursorIndex]
    if (!map || !sample || sample.lat == null || sample.lon == null) return

    if (!cursorRef.current) {
      const el = document.createElement('div')
      el.className = 'vehicle-marker'
      el.style.background = '#00D4FF'
      el.style.color = '#00D4FF'
      el.innerHTML = '<span>▲</span>'
      cursorRef.current = new maplibregl.Marker({ element: el, anchor: 'center' })
        .setLngLat([sample.lon, sample.lat])
        .addTo(map)
    } else {
      cursorRef.current.setLngLat([sample.lon, sample.lat])
    }
  }, [cursorIndex, samples])

  return <div ref={containerRef} className="absolute inset-0" />
}
