begin;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.categories (
  id text primary key check (btrim(id) <> ''),
  name text not null check (btrim(name) <> ''),
  description text not null default '',
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now()
);
create table public.topics (
  id text primary key check (btrim(id) <> ''),
  category_id text not null references public.categories(id),
  name text not null check (btrim(name) <> ''),
  description text not null default '',
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  unique (id, category_id)
);
create table public.questions (
  id text primary key check (btrim(id) <> ''),
  category_id text not null references public.categories(id),
  topic_id text not null,
  question_text text not null check (btrim(question_text) <> ''),
  question_type text not null check (question_type in ('multiple_choice', 'true_false')),
  correct_option_id text not null,
  explanation text not null check (btrim(explanation) <> ''),
  difficulty text not null check (difficulty in ('easy', 'medium', 'hard')),
  points integer not null check (points > 0),
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  foreign key (topic_id, category_id) references public.topics(id, category_id)
);
create table public.question_options (
  id text primary key check (btrim(id) <> ''),
  question_id text not null references public.questions(id) on delete cascade,
  option_text text not null check (btrim(option_text) <> ''),
  sort_order integer not null default 0 check (sort_order >= 0),
  unique (question_id, id),
  unique (question_id, sort_order)
);
-- The correct option must belong to this question. Deferred for atomic question + option inserts.
alter table public.questions add constraint questions_correct_option_fkey
  foreign key (id, correct_option_id) references public.question_options(question_id, id)
  deferrable initially deferred;

create index categories_order_idx on public.categories(sort_order, id);
create index topics_category_order_idx on public.topics(category_id, sort_order);
create index questions_category_order_idx on public.questions(category_id, sort_order, id);
create index questions_topic_idx on public.questions(topic_id);
-- question_options' unique indexes already begin with question_id.

create function public.create_user_profile() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles(id, display_name)
    values (new.id, left(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), 80));
  return new;
end;
$$;
revoke all on function public.create_user_profile() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.create_user_profile();

-- Include users registered before this migration.
insert into public.profiles(id, display_name)
select id, left(btrim(coalesce(raw_user_meta_data ->> 'display_name', '')), 80)
from auth.users on conflict (id) do nothing;

create function public.set_profile_updated_at() returns trigger
language plpgsql set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
revoke all on function public.set_profile_updated_at() from public, anon, authenticated;
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_profile_updated_at();

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.topics enable row level security;
alter table public.questions enable row level security;
alter table public.question_options enable row level security;

revoke all on public.profiles, public.categories, public.topics, public.questions, public.question_options
  from public, anon, authenticated;
grant select on public.profiles, public.categories, public.topics, public.questions, public.question_options to authenticated;
grant update(display_name) on public.profiles to authenticated;

create policy profiles_read_own on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy profiles_update_own on public.profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy categories_read on public.categories for select to authenticated using (true);
create policy topics_read on public.topics for select to authenticated using (true);
create policy questions_read on public.questions for select to authenticated using (true);
create policy question_options_read on public.question_options for select to authenticated using (true);

commit;
