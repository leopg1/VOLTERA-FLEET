-- Voltera Fleet — schema MVP pentru demo academic ICE USV
-- Ruleaza in Supabase SQL Editor (Project → SQL Editor → New query → paste → Run)

-- ============================================================================
-- 1. EXTENSII
-- ============================================================================
create extension if not exists "uuid-ossp";
create extension if not exists postgis;

-- ============================================================================
-- 2. TABELE
-- ============================================================================

-- Vehicule din flota (creezi manual sau prin seed)
create table if not exists vehicles (
  id uuid primary key default uuid_generate_v4(),
  plate text not null unique,
  vin text,
  make text,
  model text,
  year int,
  color text default '#22d3ee',
  driver_name text,
  created_at timestamptz default now()
);

-- Telemetrie raw — fiecare sample de la dispozitivul din masina
create table if not exists telemetry_samples (
  id bigserial primary key,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  trip_id uuid,
  ts timestamptz not null default now(),
  lat double precision,
  lon double precision,
  speed_kmh real,
  rpm real,
  coolant real,
  throttle real,
  engine_load real,
  maf real,
  battery real,
  fuel_pct real,
  intake_air_temp real,
  geom geography(point, 4326)
    generated always as (
      case when lat is not null and lon is not null
        then st_setsrid(st_makepoint(lon, lat), 4326)::geography
        else null end
    ) stored
);

create index if not exists idx_telemetry_vehicle_ts on telemetry_samples (vehicle_id, ts desc);
create index if not exists idx_telemetry_trip on telemetry_samples (trip_id);
create index if not exists idx_telemetry_geom on telemetry_samples using gist (geom);

-- Trasee inregistrate
create table if not exists trips (
  id uuid primary key default uuid_generate_v4(),
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  driver_name text,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  distance_km real default 0,
  fuel_l real default 0,
  max_speed_kmh real default 0,
  max_rpm real default 0,
  eco_score int default 100,
  notes text
);

create index if not exists idx_trips_vehicle on trips (vehicle_id, started_at desc);

-- Evenimente: DTC, harsh brake/accel, overspeed, geofence, idle, low_battery, overheat
create table if not exists events (
  id uuid primary key default uuid_generate_v4(),
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  trip_id uuid,
  ts timestamptz not null default now(),
  type text not null,
  severity text not null check (severity in ('info','warning','critical')),
  code text,
  title text not null,
  description text,
  payload jsonb default '{}'::jsonb,
  resolved_at timestamptz
);

create index if not exists idx_events_vehicle_ts on events (vehicle_id, ts desc);
create index if not exists idx_events_unresolved on events (resolved_at) where resolved_at is null;

-- ============================================================================
-- 3. VIEW MATERIALIZED — fleet status (ultima pozitie + telemetrie per masina)
-- ============================================================================
-- View simplu (nu materialized) — datele sunt mereu fresh, performance ok pentru demo
create or replace view fleet_status as
  select
    v.id              as vehicle_id,
    v.plate,
    v.make,
    v.model,
    v.color,
    v.driver_name,
    s.ts              as last_seen_at,
    s.lat,
    s.lon,
    s.speed_kmh,
    s.rpm,
    s.coolant,
    s.throttle,
    s.engine_load,
    s.battery,
    s.fuel_pct,
    s.trip_id         as active_trip_id,
    case
      when s.ts is null then 'offline'
      when s.ts < now() - interval '2 minutes' then 'offline'
      when exists (
        select 1 from events e
        where e.vehicle_id = v.id
          and e.severity = 'critical'
          and e.resolved_at is null
      ) then 'alert'
      when s.speed_kmh > 5 then 'driving'
      else 'idle'
    end as status
  from vehicles v
  left join lateral (
    select * from telemetry_samples ts
    where ts.vehicle_id = v.id
    order by ts.ts desc
    limit 1
  ) s on true;

-- ============================================================================
-- 4. RLS — pentru demo permitem citire/scriere prin anon key
-- ============================================================================
-- ATENTIE: pentru productie ai nevoie de auth real. Pentru demo academic e ok.
alter table vehicles enable row level security;
alter table telemetry_samples enable row level security;
alter table trips enable row level security;
alter table events enable row level security;

drop policy if exists "demo_all_vehicles" on vehicles;
create policy "demo_all_vehicles" on vehicles
  for all to anon, authenticated using (true) with check (true);

drop policy if exists "demo_all_telemetry" on telemetry_samples;
create policy "demo_all_telemetry" on telemetry_samples
  for all to anon, authenticated using (true) with check (true);

drop policy if exists "demo_all_trips" on trips;
create policy "demo_all_trips" on trips
  for all to anon, authenticated using (true) with check (true);

drop policy if exists "demo_all_events" on events;
create policy "demo_all_events" on events
  for all to anon, authenticated using (true) with check (true);

-- ============================================================================
-- 5. REALTIME — publicam doar telemetrie + events
-- ============================================================================
-- Activeaza in Supabase Studio: Database → Replication → bifeaza tabelele
-- sau ruleaza:
alter publication supabase_realtime add table telemetry_samples;
alter publication supabase_realtime add table events;
alter publication supabase_realtime add table vehicles;
