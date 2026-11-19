-- Shared community data. Only the authenticated RPC can read/write these tables.
begin;

create table public.community_profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    name text not null check (char_length(btrim(name)) between 1 and 60)
);
create table public.community_follows (
    follower uuid references public.community_profiles(id) on delete cascade,
    followed uuid references public.community_profiles(id) on delete cascade,
    primary key (follower, followed), check (follower <> followed)
);
create table public.community_groups (
    id uuid primary key default gen_random_uuid(),
    owner uuid not null references public.community_profiles(id) on delete cascade,
    name text not null check (char_length(btrim(name)) between 1 and 80),
    description text not null default '' check (char_length(description) <= 1000),
    created_at timestamptz not null default now()
);
create table public.community_members (
    group_id uuid references public.community_groups(id) on delete cascade,
    user_id uuid references public.community_profiles(id) on delete cascade,
    primary key (group_id, user_id)
);
create table public.community_posts (
    id uuid primary key,
    author uuid not null references public.community_profiles(id) on delete cascade,
    group_id uuid references public.community_groups(id) on delete cascade,
    kind text not null check (kind in ('note', 'activity')),
    body text not null check (char_length(btrim(body)) between 1 and 2000),
    created_at timestamptz not null default now()
);
create index community_posts_time on public.community_posts(created_at desc);
create table public.community_challenges (
    id uuid primary key,
    owner uuid not null references public.community_profiles(id) on delete cascade,
    group_id uuid references public.community_groups(id) on delete cascade,
    title text not null check (char_length(btrim(title)) between 1 and 100),
    target integer not null check (target between 1 and 1000000),
    unit text not null check (char_length(btrim(unit)) between 1 and 30),
    deadline timestamptz not null,
    created_at timestamptz not null default now()
);
create table public.community_progress (
    challenge_id uuid references public.community_challenges(id) on delete cascade,
    user_id uuid references public.community_profiles(id) on delete cascade,
    value integer not null default 0 check (value >= 0),
    primary key (challenge_id, user_id)
);

alter table public.community_profiles enable row level security;
alter table public.community_follows enable row level security;
alter table public.community_groups enable row level security;
alter table public.community_members enable row level security;
alter table public.community_posts enable row level security;
alter table public.community_challenges enable row level security;
alter table public.community_progress enable row level security;
revoke all on public.community_profiles, public.community_follows, public.community_groups,
    public.community_members, public.community_posts, public.community_challenges,
    public.community_progress from anon, authenticated;

create function public.community(action text default 'load', payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
    uid uuid := auth.uid();
    gid uuid;
    cid uuid;
    challenge public.community_challenges%rowtype;
    result jsonb;
begin
    if uid is null then raise exception 'Authentication required'; end if;
    -- Serialize writes by the same identity; prevents duplicate creates on retried requests.
    perform pg_advisory_xact_lock(hashtextextended(uid::text, 0));
    if action = 'profile' then
        insert into public.community_profiles(id, name) values (uid, btrim(payload->>'name'))
        on conflict (id) do update set name = excluded.name;
    elsif action <> 'load' then
        if not exists (select 1 from public.community_profiles where id = uid) then
            raise exception 'Join the community first';
        end if;
        gid := nullif(payload->>'group_id', '')::uuid;
        if gid is not null and action not in ('join_group', 'leave_group') and not exists (
            select 1 from public.community_members where group_id = gid and user_id = uid
        ) then raise exception 'Join this group first'; end if;

        case action
        when 'follow' then
            insert into public.community_follows values (uid, (payload->>'id')::uuid) on conflict do nothing;
        when 'unfollow' then
            delete from public.community_follows where follower = uid and followed = (payload->>'id')::uuid;
        when 'post' then
            insert into public.community_posts(id, author, group_id, kind, body)
            values ((payload->>'id')::uuid, uid, gid, payload->>'kind', btrim(payload->>'body'))
            on conflict (id) do nothing;
        when 'delete_post' then
            delete from public.community_posts where id = (payload->>'id')::uuid and author = uid;
            if not found then raise exception 'Only the author can delete this post'; end if;
        when 'create_group' then
            gid := (payload->>'id')::uuid;
            insert into public.community_groups(id, owner, name, description)
            values (gid, uid, btrim(payload->>'name'), coalesce(payload->>'description', ''))
            on conflict (id) do nothing;
            if not exists (select 1 from public.community_groups where id = gid and owner = uid) then
                raise exception 'Group already exists';
            end if;
            insert into public.community_members values (gid, uid) on conflict do nothing;
        when 'join_group' then
            insert into public.community_members values (gid, uid) on conflict do nothing;
        when 'leave_group' then
            if exists (select 1 from public.community_groups where id = gid and owner = uid) then
                raise exception 'The group creator must remain a member';
            end if;
            delete from public.community_progress where user_id = uid and challenge_id in
                (select id from public.community_challenges where group_id = gid);
            delete from public.community_members where group_id = gid and user_id = uid;
        when 'create_challenge' then
            if to_timestamp((payload->>'deadline')::double precision) <= now() then
                raise exception 'Choose a future deadline';
            end if;
            cid := (payload->>'id')::uuid;
            insert into public.community_challenges(id, owner, group_id, title, target, unit, deadline)
            values (cid, uid, gid, btrim(payload->>'title'), (payload->>'target')::integer,
                btrim(payload->>'unit'), to_timestamp((payload->>'deadline')::double precision))
            on conflict (id) do nothing;
            if not exists (select 1 from public.community_challenges where id = cid and owner = uid) then
                raise exception 'Challenge already exists';
            end if;
            insert into public.community_progress values (cid, uid, 0) on conflict do nothing;
        when 'progress' then
            select * into challenge from public.community_challenges where id = (payload->>'id')::uuid;
            if not found then raise exception 'Challenge not found'; end if;
            if challenge.deadline <= now() then raise exception 'This challenge has ended'; end if;
            if challenge.group_id is not null and not exists (
                select 1 from public.community_members where group_id = challenge.group_id and user_id = uid
            ) then raise exception 'Join this group first'; end if;
            if (payload->>'value')::integer > challenge.target then raise exception 'Progress exceeds the target'; end if;
            insert into public.community_progress values (challenge.id, uid, (payload->>'value')::integer)
            on conflict (challenge_id, user_id) do update set value = excluded.value;
        else raise exception 'Unknown community action';
        end case;
    end if;

    -- All group names are discoverable; group posts and challenge results require membership.
    select jsonb_build_object(
        'userID', uid,
        'profiles', coalesce((select jsonb_agg(to_jsonb(p)) from public.community_profiles p), '[]'::jsonb),
        'follows', coalesce((select jsonb_agg(to_jsonb(f)) from public.community_follows f
            where f.follower = uid or f.followed = uid), '[]'::jsonb),
        'groups', coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'owner', g.owner, 'name', g.name,
            'description', g.description, 'joined', exists (select 1 from public.community_members m where m.group_id = g.id and m.user_id = uid),
            'memberCount', (select count(*) from public.community_members m where m.group_id = g.id))) from public.community_groups g), '[]'::jsonb),
        'posts', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'author', p.author, 'groupID', p.group_id,
            'kind', p.kind, 'body', p.body, 'createdAt', extract(epoch from p.created_at))) from
            (select * from public.community_posts where
                (group_id is null or exists (select 1 from public.community_members m where m.group_id = community_posts.group_id and m.user_id = uid))
                order by created_at desc limit 500) p), '[]'::jsonb),
        'challenges', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'owner', c.owner, 'groupID', c.group_id,
            'title', c.title, 'target', c.target, 'unit', c.unit, 'deadline', extract(epoch from c.deadline)))
            from public.community_challenges c where c.group_id is null or exists
                (select 1 from public.community_members m where m.group_id = c.group_id and m.user_id = uid)), '[]'::jsonb),
        'progress', coalesce((select jsonb_agg(jsonb_build_object('challengeID', p.challenge_id, 'userID', p.user_id, 'value', p.value))
            from public.community_progress p join public.community_challenges c on c.id = p.challenge_id
            where c.group_id is null or exists (select 1 from public.community_members m where m.group_id = c.group_id and m.user_id = uid)), '[]'::jsonb)
    ) into result;
    return result;
end;
$$;
revoke all on function public.community(text, jsonb) from public, anon;
grant execute on function public.community(text, jsonb) to authenticated;
commit;
