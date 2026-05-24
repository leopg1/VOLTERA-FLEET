-- Seed pentru demo: 3 vehicule fictive in flota Voltera
-- Coordonate punct de plecare: Suceava centru (47.6519, 26.2553)

insert into vehicles (id, plate, vin, make, model, year, color, driver_name) values
  ('11111111-1111-1111-1111-111111111111', 'SV-01-VLT', '1HGCM82633A004352', 'Honda',     'Accord',  2003, '#22d3ee', 'Ion Popescu'),
  ('22222222-2222-2222-2222-222222222222', 'SV-02-VLT', 'WBADE6328TCN18327', 'BMW',       '530d',    2018, '#fb923c', 'Maria Ionescu'),
  ('33333333-3333-3333-3333-333333333333', 'SV-03-VLT', 'WVWZZZ1KZBW123456', 'Volkswagen','Passat',  2015, '#a78bfa', 'Stefan Munteanu')
on conflict (id) do update set
  plate = excluded.plate,
  driver_name = excluded.driver_name;

-- DTC demo deja stocat pe masina 2 (BMW)
insert into events (vehicle_id, type, severity, code, title, description, payload) values
  ('22222222-2222-2222-2222-222222222222', 'dtc', 'critical', 'P0420',
   'Catalyst System Efficiency Below Threshold (Bank 1)',
   'Catalizatorul nu mai converteste eficient gazele de evacuare. Posibile cauze: catalizator imbatranit, sonda lambda defecta, scurgeri admisie.',
   '{"system":"Powertrain","cleared":false}'::jsonb)
on conflict do nothing;
