-- Llegué Bien — tablas para Supabase (pegar en SQL Editor y ejecutar)
-- La usuaria se identifica con su id de Clerk (auth.jwt()->>'sub').

create table perfiles (
  id     text primary key,               -- id de Clerk (lo inserta n8n con el webhook user.created)
  nombre text,
  email  text,
  creado timestamptz default now()
);

create table contactos (
  id               bigint generated always as identity primary key,
  usuaria_id       text not null default (auth.jwt()->>'sub'),
  nombre           text not null,
  codigo           text not null unique default substr(md5(random()::text), 1, 8),
  telegram_chat_id bigint,                -- se llena cuando el contacto abre el bot
  creado           timestamptz default now()
);

create table viajes (
  id         bigint generated always as identity primary key,
  usuaria_id text not null default (auth.jwt()->>'sub'),
  nombre     text,
  destino    text not null,
  limite     timestamptz not null,
  lat        double precision,
  lng        double precision,
  estado     text not null default 'en_camino'
             check (estado in ('en_camino', 'llego', 'alerta', 'panico')),
  creado     timestamptz default now()
);

create index on viajes (estado, limite);
create index on contactos (usuaria_id);

-- Cada usuaria solo ve y cambia lo suyo. n8n usa la service_role key y salta estas reglas.
alter table perfiles  enable row level security;
alter table contactos enable row level security;
alter table viajes    enable row level security;

create policy "ver mi perfil" on perfiles for select to authenticated
  using (id = auth.jwt()->>'sub');

create policy "mis contactos" on contactos for all to authenticated
  using (usuaria_id = auth.jwt()->>'sub')
  with check (usuaria_id = auth.jwt()->>'sub');

create policy "mis viajes" on viajes for all to authenticated
  using (usuaria_id = auth.jwt()->>'sub')
  with check (usuaria_id = auth.jwt()->>'sub');
