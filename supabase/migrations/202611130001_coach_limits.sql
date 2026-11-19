create table if not exists public.coach_daily_usage (
    scope text not null,
    day date not null default current_date,
    requests integer not null default 0,
    primary key (scope, day)
);
alter table public.coach_daily_usage enable row level security;
revoke all on public.coach_daily_usage from anon, authenticated;

create or replace function public.consume_coach_request(requested_user uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare
    user_count integer;
    total_count integer;
begin
    -- A global cap also bounds costs from repeated anonymous signups.
    insert into coach_daily_usage(scope, day, requests) values ('global', current_date, 1)
    on conflict (scope, day) do update set requests = coach_daily_usage.requests + 1
    returning requests into total_count;
    if total_count > 1000 then return false; end if;
    insert into coach_daily_usage(scope, day, requests) values (requested_user::text, current_date, 1)
    on conflict (scope, day) do update set requests = coach_daily_usage.requests + 1
    returning requests into user_count;
    return user_count <= 30;
end;
$$;
revoke all on function public.consume_coach_request(uuid) from public, anon, authenticated;
grant execute on function public.consume_coach_request(uuid) to service_role;
