-- Velora Jewells initial schema. Apply only to the dedicated Velora Supabase project.
-- Never apply this to Elyra. All exposed tables use RLS.
create extension if not exists pgcrypto;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  sku text unique,
  slug text unique not null,
  name text not null,
  description text not null default '',
  category text not null check (category in ('Pendants','Rings','Chains','Bracelets','Other')),
  price_paise integer not null check (price_paise > 0),
  stock_qty integer not null default 0 check (stock_qty >= 0),
  image_urls text[] not null default '{}',
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number bigint generated always as identity unique,
  customer_id uuid references auth.users(id) on delete set null,
  customer_name text not null,
  phone text not null,
  email text,
  address jsonb not null,
  payment_method text not null check (payment_method in ('prepaid','cod')),
  payment_status text not null default 'pending' check (payment_status in ('pending','advance_paid','paid','failed','refunded')),
  order_status text not null default 'pending_payment' check (order_status in ('pending_payment','confirmed','processing','shipped','delivered','cancelled','refunded')),
  product_subtotal_paise integer not null check (product_subtotal_paise >= 50000),
  cod_advance_paise integer not null default 0 check (cod_advance_paise in (0,7000)),
  amount_due_at_delivery_paise integer not null default 0 check (amount_due_at_delivery_paise >= 0),
  shipping_fee_paise integer not null default 0 check (shipping_fee_paise >= 0),
  payment_provider text,
  provider_order_id text,
  provider_payment_id text,
  tracking_provider text,
  tracking_number text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((payment_method = 'cod' and cod_advance_paise = 7000 and amount_due_at_delivery_paise = product_subtotal_paise)
      or (payment_method = 'prepaid' and cod_advance_paise = 0 and amount_due_at_delivery_paise = 0))
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,
  sku text,
  unit_price_paise integer not null check (unit_price_paise > 0),
  quantity integer not null check (quantity > 0),
  line_total_paise integer generated always as (unit_price_paise * quantity) stored
);

create table if not exists public.cart_events (
  id uuid primary key default gen_random_uuid(),
  session_id text not null,
  user_id uuid references auth.users(id) on delete set null,
  event_type text not null check (event_type in ('view_product','add_to_cart','remove_from_cart','checkout_started')),
  product_id uuid references public.products(id) on delete set null,
  quantity integer check (quantity is null or quantity >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.payment_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  provider text not null,
  provider_event_id text not null unique,
  event_type text not null,
  verified boolean not null default false,
  payload jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  old_status text,
  new_status text not null,
  changed_by uuid references auth.users(id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);

alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.cart_events enable row level security;
alter table public.payment_events enable row level security;
alter table public.order_status_history enable row level security;

-- Public shoppers may read published catalog entries only.
create policy "published products are readable" on public.products
for select to anon, authenticated using (is_published = true);

-- Admin authorization must be assigned server-side in app_metadata, never user_metadata.
create policy "admins manage products" on public.products
for all to authenticated
using ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Customer orders and payment events are server-created/updated by trusted backend functions.
-- No direct anon/authenticated policies are intentionally granted for orders, items, payments or status history.
-- Cart events should be written through a rate-limited server endpoint to avoid forged analytics.
revoke all on public.orders, public.order_items, public.payment_events, public.order_status_history from anon, authenticated;
revoke insert, update, delete on public.cart_events from anon, authenticated;
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated; -- RLS limits these operations to admins
