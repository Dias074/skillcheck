begin;

-- IDs remain compatible with Assessment.id. Ownership is part of the key,
-- so two users cannot collide with or reserve each other's attempt IDs.
create table public.assessment_attempts (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id text not null check (btrim(id) <> ''),
  category_id text not null references public.categories(id),
  score integer not null check (score >= 0),
  max_score integer not null check (max_score > 0 and score <= max_score),
  percentage numeric generated always as (100.0 * score / max_score) stored,
  correct_count integer not null check (correct_count >= 0),
  incorrect_count integer not null check (incorrect_count >= 0),
  skipped_count integer not null check (skipped_count >= 0),
  started_at timestamptz not null,
  completed_at timestamptz not null check (completed_at >= started_at),
  created_at timestamptz not null default now(),
  primary key (user_id, id),
  check (correct_count + incorrect_count + skipped_count > 0),
  check (max_score >= correct_count + incorrect_count + skipped_count),
  check (score >= correct_count),
  check (max_score - score >= incorrect_count + skipped_count),
  check (correct_count > 0 or score = 0),
  check (incorrect_count + skipped_count > 0 or score = max_score)
);

create table public.assessment_attempt_answers (
  user_id uuid not null default auth.uid(),
  attempt_id text not null,
  question_id text not null references public.questions(id),
  selected_option_id text,
  is_correct boolean not null,
  points_earned integer not null check (points_earned >= 0),
  created_at timestamptz not null default now(),
  primary key (user_id, attempt_id, question_id),
  foreign key (user_id, attempt_id)
    references public.assessment_attempts(user_id, id) on delete cascade,
  foreign key (question_id, selected_option_id)
    references public.question_options(question_id, id),
  check (not is_correct or selected_option_id is not null),
  check ((is_correct and points_earned > 0) or
         (not is_correct and points_earned = 0))
);

create index assessment_attempts_recent_idx
  on public.assessment_attempts(user_id, completed_at desc, id);
create index assessment_attempts_category_recent_idx
  on public.assessment_attempts(user_id, category_id, completed_at desc, id);
create index assessment_attempt_answers_question_idx
  on public.assessment_attempt_answers(question_id);

alter table public.assessment_attempts enable row level security;
alter table public.assessment_attempt_answers enable row level security;
revoke all on public.assessment_attempts, public.assessment_attempt_answers
  from public, anon, authenticated;
grant select, insert on public.assessment_attempts, public.assessment_attempt_answers
  to authenticated;

create policy attempts_read_own on public.assessment_attempts
  for select to authenticated using ((select auth.uid()) = user_id);
create policy attempts_insert_own on public.assessment_attempts
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy attempt_answers_read_own on public.assessment_attempt_answers
  for select to authenticated using ((select auth.uid()) = user_id);
create policy attempt_answers_insert_own on public.assessment_attempt_answers
  for insert to authenticated with check (
    (select auth.uid()) = user_id and exists (
      select 1 from public.assessment_attempts a
      where a.user_id = assessment_attempt_answers.user_id
        and a.id = assessment_attempt_answers.attempt_id
    )
  );
-- No client UPDATE/DELETE privileges or policies: submitted history is immutable.

-- One RPC transaction saves the result and ALL answers, including skipped ones.
-- Scoring remains in AssessmentScorer. These checks enforce payload consistency,
-- not an anti-cheat boundary. Client-calculated scores are not exam credentials.
create function public.save_assessment_attempt(p_attempt jsonb, p_answers jsonb)
returns text language plpgsql security invoker set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_id text := p_attempt ->> 'id';
  v_inserted text;
  v_attempt public.assessment_attempts%rowtype;
  v_count integer;
  v_correct integer;
  v_incorrect integer;
  v_skipped integer;
  v_score bigint;
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if jsonb_typeof(p_attempt) is distinct from 'object' or
     jsonb_typeof(p_answers) is distinct from 'array' then
    raise exception 'Expected attempt object and answer array' using errcode = '22023';
  end if;

  insert into public.assessment_attempts (
    user_id, id, category_id, score, max_score, correct_count,
    incorrect_count, skipped_count, started_at, completed_at
  ) values (
    v_user, v_id, p_attempt ->> 'category_id',
    (p_attempt ->> 'score')::integer, (p_attempt ->> 'max_score')::integer,
    (p_attempt ->> 'correct_count')::integer,
    (p_attempt ->> 'incorrect_count')::integer,
    (p_attempt ->> 'skipped_count')::integer,
    (p_attempt ->> 'started_at')::timestamptz,
    (p_attempt ->> 'completed_at')::timestamptz
  ) on conflict (user_id, id) do nothing returning id into v_inserted;

  -- First successful submission wins. Retrying the same stable ID after a lost
  -- network response acknowledges the existing attempt without adding answers.
  if v_inserted is null then return v_id; end if;

  insert into public.assessment_attempt_answers (
    user_id, attempt_id, question_id, selected_option_id, is_correct, points_earned
  ) select v_user, v_id, x.question_id, x.selected_option_id, x.is_correct, x.points_earned
    from jsonb_to_recordset(p_answers) as x(
      question_id text, selected_option_id text, is_correct boolean, points_earned integer
    );

  select * into strict v_attempt from public.assessment_attempts
    where user_id = v_user and id = v_id;
  select count(*), count(*) filter (where is_correct),
    count(*) filter (where not is_correct and selected_option_id is not null),
    count(*) filter (where selected_option_id is null), coalesce(sum(points_earned), 0)
    into v_count, v_correct, v_incorrect, v_skipped, v_score
    from public.assessment_attempt_answers where user_id = v_user and attempt_id = v_id;

  if v_count <> v_attempt.correct_count + v_attempt.incorrect_count + v_attempt.skipped_count
     or v_correct <> v_attempt.correct_count or v_incorrect <> v_attempt.incorrect_count
     or v_skipped <> v_attempt.skipped_count or v_score <> v_attempt.score
     or exists (
       select 1 from public.assessment_attempt_answers a
       join public.questions q on q.id = a.question_id
       where a.user_id = v_user and a.attempt_id = v_id
         and q.category_id <> v_attempt.category_id
     ) then
    raise exception 'Answers do not match the attempt summary' using errcode = '23514';
  end if;
  return v_id;
end;
$$;
revoke all on function public.save_assessment_attempt(jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.save_assessment_attempt(jsonb, jsonb) to authenticated;

commit;
