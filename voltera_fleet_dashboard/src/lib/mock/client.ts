/**
 * Mock Supabase Client
 *
 * Returneaza un obiect cu aceeasi suprafata API pe care o foloseste codul
 * existent (from/select/order/is/eq/limit + channel/on/subscribe + auth).
 * In spate, citeste din simulator si se aboneaza la bus-urile telemetry / events.
 *
 * Trade-off: nu implementeaza FULL API-ul Supabase, doar ce e nevoie pentru
 * dashboard-ul Voltera Fleet. Adaugarea unui field nou la o query existenta
 * va functiona automat; o metoda noua (ex. .gte, .like) trebuie adaugata aici.
 */

import {
  start as startSimulator,
  telemetryBus,
  eventsBus,
  getFleetStatusSnapshot,
  getRecentEvents,
  getTrips,
  getAllTripSamples,
} from './simulator'
import type { TelemetrySample, FleetEvent } from '../supabase'

// ============ QueryBuilder ============

type RowFilter = (row: Record<string, unknown>) => boolean

class MockQueryBuilder<T = unknown> implements PromiseLike<{ data: T[] | null; error: null }> {
  private filters: RowFilter[] = []
  private orderBy: { column: string; ascending: boolean } | null = null
  private limitN: number | null = null

  constructor(private readonly table: string) {}

  select(_columns?: string) {
    // Coloanele nu sunt filtrate (returnam toate); nu e nevoie pentru demo.
    return this
  }

  order(column: string, opts?: { ascending?: boolean }) {
    this.orderBy = { column, ascending: opts?.ascending !== false }
    return this
  }

  is(column: string, value: null | unknown) {
    this.filters.push((row) => row[column] === value)
    return this
  }

  eq(column: string, value: unknown) {
    this.filters.push((row) => row[column] === value)
    return this
  }

  gte(column: string, value: number | string) {
    this.filters.push((row) => {
      const v = row[column] as number | string | null
      return v != null && v >= value
    })
    return this
  }

  lte(column: string, value: number | string) {
    this.filters.push((row) => {
      const v = row[column] as number | string | null
      return v != null && v <= value
    })
    return this
  }

  limit(n: number) {
    this.limitN = n
    return this
  }

  /** Returneaza o singura linie (folosit ocazional). */
  single() {
    const original = this.execute()
    return Promise.resolve({
      data: (original[0] as T) ?? null,
      error: original.length === 0 ? { code: 'PGRST116' } : null,
    })
  }

  /** Identic cu single() dar nu da eroare cand sunt 0 rows — folosit pe rute dinamice. */
  maybeSingle() {
    const original = this.execute()
    return Promise.resolve({
      data: (original[0] as T) ?? null,
      error: null,
    })
  }

  private execute(): T[] {
    const data = getTableSnapshot(this.table) as T[]
    let rows = data
    for (const f of this.filters) {
      rows = rows.filter((row) => f(row as Record<string, unknown>))
    }
    if (this.orderBy) {
      const { column, ascending } = this.orderBy
      rows = [...rows].sort((a, b) => {
        const av = (a as Record<string, unknown>)[column]
        const bv = (b as Record<string, unknown>)[column]
        if (av == null && bv == null) return 0
        if (av == null) return ascending ? -1 : 1
        if (bv == null) return ascending ? 1 : -1
        if (av < bv) return ascending ? -1 : 1
        if (av > bv) return ascending ? 1 : -1
        return 0
      })
    }
    if (this.limitN != null) rows = rows.slice(0, this.limitN)
    return rows
  }

  then<TResult1 = { data: T[] | null; error: null }, TResult2 = never>(
    onfulfilled?:
      | ((value: { data: T[] | null; error: null }) => TResult1 | PromiseLike<TResult1>)
      | null,
    onrejected?:
      | ((reason: unknown) => TResult2 | PromiseLike<TResult2>)
      | null,
  ): Promise<TResult1 | TResult2> {
    const data = this.execute()
    return Promise.resolve({ data, error: null }).then(
      onfulfilled as never,
      onrejected as never,
    ) as Promise<TResult1 | TResult2>
  }
}

function getTableSnapshot(table: string): unknown[] {
  switch (table) {
    case 'fleet_status':
      return getFleetStatusSnapshot()
    case 'events':
      return getRecentEvents()
    case 'trips':
      return getTrips()
    case 'telemetry_samples':
      // Pentru Trip Replay — returneaza samples pre-generate per trip
      return getAllTripSamples()
    case 'vehicles':
      return getFleetStatusSnapshot()
    default:
      return []
  }
}

// ============ Channel ============

type ChannelConfig = {
  event: string
  schema?: string
  table: string
  filter?: string
}

type ChannelSubscriber = {
  config: ChannelConfig
  callback: (payload: { new: unknown }) => void
}

class MockChannel {
  private subscribers: ChannelSubscriber[] = []
  private unsubFns: Array<() => void> = []

  constructor(public readonly name: string) {}

  on(
    _event: string,
    config: ChannelConfig,
    callback: (payload: { new: unknown }) => void,
  ) {
    this.subscribers.push({ config, callback })
    return this
  }

  subscribe() {
    // Conecteaza subscriberii la bus-urile potrivite din simulator
    for (const s of this.subscribers) {
      if (s.config.table === 'telemetry_samples') {
        const unsub = telemetryBus.subscribe(({ new: sample }) => {
          if (!matchesFilter(sample as Record<string, unknown>, s.config.filter)) return
          s.callback({ new: sample as unknown as TelemetrySample })
        })
        this.unsubFns.push(unsub)
      } else if (s.config.table === 'events') {
        const unsub = eventsBus.subscribe(({ new: event }) => {
          if (!matchesFilter(event as Record<string, unknown>, s.config.filter)) return
          s.callback({ new: event as unknown as FleetEvent })
        })
        this.unsubFns.push(unsub)
      }
    }
    return this
  }

  removeAll() {
    this.unsubFns.forEach((fn) => fn())
    this.unsubFns = []
    this.subscribers = []
  }
}

function matchesFilter(
  row: Record<string, unknown>,
  filter?: string,
): boolean {
  if (!filter) return true
  // Format Supabase: "vehicle_id=eq.<uuid>"
  const m = filter.match(/^(\w+)=eq\.(.+)$/)
  if (!m) return true
  return row[m[1]] === m[2]
}

// ============ Auth (stub) ============

const fakeUser = {
  id: 'demo-user-id',
  email: 'demo@voltera.local',
  user_metadata: { full_name: 'Demo Dispecer' },
}

const mockAuth = {
  getUser: async () => ({ data: { user: fakeUser }, error: null }),
  signInWithPassword: async () => ({ data: { user: fakeUser }, error: null }),
  signOut: async () => ({ error: null }),
  onAuthStateChange: () => ({
    data: { subscription: { unsubscribe: () => {} } },
  }),
}

// ============ Client ============

export type MockClient = {
  from: (table: string) => MockQueryBuilder
  channel: (name: string) => MockChannel
  removeChannel: (ch: MockChannel) => void
  auth: typeof mockAuth
}

export function createMockClient(): MockClient {
  // Lazy start: pornim simulatorul la prima utilizare a clientului
  startSimulator()
  return {
    from(table: string) {
      return new MockQueryBuilder(table)
    },
    channel(name: string) {
      return new MockChannel(name)
    },
    removeChannel(ch: MockChannel) {
      ch.removeAll()
    },
    auth: mockAuth,
  }
}
