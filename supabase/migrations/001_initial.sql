-- Executar num projeto Supabase NOVO. Revê políticas antes de produção.
create extension if not exists btree_gist;
create table public.profiles (id uuid primary key references auth.users(id) on delete cascade, name text not null default '', role text not null default 'pending' check(role in ('pending','admin','doctor','receptionist')), active boolean not null default false, created_at timestamptz not null default now());
create table public.patients (id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 1 and 160), phone text, email text, created_at timestamptz not null default now());
create table public.appointments (id uuid primary key default gen_random_uuid(), patient_id uuid not null references public.patients(id) on delete restrict, doctor_id uuid not null references public.profiles(id) on delete restrict, starts_at timestamptz not null, ends_at timestamptz not null, status text not null default 'scheduled' check(status in ('scheduled','confirmed','completed','cancelled')), created_by uuid references public.profiles(id), created_at timestamptz not null default now(), check(ends_at>starts_at),check(ends_at<=starts_at+interval '8 hours'));
-- Evita marcações simultâneas para o mesmo médico, mesmo com concorrência.
alter table public.appointments add constraint no_doctor_overlap exclude using gist (doctor_id with =,tstzrange(starts_at,ends_at,'[)') with &&) where (status <> 'cancelled');
create index appointments_starts_at_idx on public.appointments(starts_at);
create index appointments_doctor_idx on public.appointments(doctor_id,starts_at);
create table public.audit_log (id bigint generated always as identity primary key, actor uuid, table_name text not null, operation text not null, record_id uuid, happened_at timestamptz not null default now());
create or replace function public.create_profile() returns trigger language plpgsql security definer set search_path='' as $$ begin insert into public.profiles(id) values(new.id);return new;end;$$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.create_profile();
create or replace function public.my_role() returns text language sql stable security definer set search_path='' as $$select role from public.profiles where id=(select auth.uid()) and active=true limit 1$$;
create or replace function public.is_staff() returns boolean language sql stable security definer set search_path='' as $$select coalesce(public.my_role() in ('admin','receptionist','doctor'),false)$$;
create or replace function public.can_manage() returns boolean language sql stable security definer set search_path='' as $$select coalesce(public.my_role() in ('admin','receptionist'),false)$$;
create or replace function public.is_doctor(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.profiles where id=p_id and role='doctor' and active=true)$$;
revoke all on function public.create_profile() from public,anon,authenticated;
grant execute on function public.my_role(),public.is_staff(),public.can_manage(),public.is_doctor(uuid) to authenticated;
alter table public.profiles enable row level security;
alter table public.patients enable row level security;
alter table public.appointments enable row level security;
alter table public.audit_log enable row level security;
create policy profiles_read on public.profiles for select to authenticated using (public.is_staff() or id=(select auth.uid()));
-- As alterações de perfis só podem ser feitas por API com service_role, nunca pelo cliente.
create policy patients_read on public.patients for select to authenticated using(public.can_manage() or (public.my_role()='doctor' and exists(select 1 from public.appointments a where a.patient_id=patients.id and a.doctor_id=(select auth.uid()) and a.status<>'cancelled')));
create policy patients_insert on public.patients for insert to authenticated with check(public.can_manage());
create policy patients_update on public.patients for update to authenticated using(public.can_manage()) with check(public.can_manage());
create policy appointments_read on public.appointments for select to authenticated using(public.can_manage() or (public.my_role()='doctor' and doctor_id=(select auth.uid())));
create policy appointments_insert on public.appointments for insert to authenticated with check(public.can_manage() and public.is_doctor(doctor_id) and created_by=(select auth.uid()));
create policy appointments_update on public.appointments for update to authenticated using(public.can_manage()) with check(public.can_manage() and public.is_doctor(doctor_id));
-- Sem DELETE: cancelar alterando o estado, mantendo rastreabilidade.
create or replace function public.log_changes() returns trigger language plpgsql security definer set search_path='' as $$ begin insert into public.audit_log(actor,table_name,operation,record_id) values(auth.uid(),TG_TABLE_NAME,TG_OP,coalesce(new.id,old.id));return coalesce(new,old);end;$$;
create trigger audit_appointments after insert or update or delete on public.appointments for each row execute function public.log_changes();
create trigger audit_patients after insert or update or delete on public.patients for each row execute function public.log_changes();
revoke all on public.audit_log from anon,authenticated;
-- PRIMEIRO ADMIN: após criar utilizador no Supabase Auth, executar manualmente no SQL Editor:
-- update public.profiles set name='Administrador',role='admin',active=true where id='UUID_DO_UTILIZADOR';
