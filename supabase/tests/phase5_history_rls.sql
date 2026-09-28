-- Run the WHOLE file after the Phase 5 migration and Phase 4 sample seed.
-- Synthetic users and attempts are rolled back; no real history is modified.
begin;
insert into auth.users(id, email, raw_user_meta_data) values
  ('55555555-5555-4555-8555-555555555551', 'phase5-a@example.test', '{}'),
  ('55555555-5555-4555-8555-555555555552', 'phase5-b@example.test', '{}');

set local role authenticated;
select set_config('request.jwt.claim.sub', '55555555-5555-4555-8555-555555555551', true);
do $$
declare
  payload jsonb := '{"id":"phase5-test","category_id":"english","score":0,"max_score":1,"correct_count":0,"incorrect_count":0,"skipped_count":1,"started_at":"2026-09-28T10:00:00Z","completed_at":"2026-09-28T10:01:00Z"}';
  answers jsonb := '[{"question_id":"en_1","selected_option_id":null,"is_correct":false,"points_earned":0}]';
begin
  perform public.save_assessment_attempt(payload, answers);
  perform public.save_assessment_attempt(payload, answers);
  if (select count(*) from public.assessment_attempts) <> 1 or
     (select count(*) from public.assessment_attempt_answers) <> 1 then
    raise exception 'Own save or duplicate prevention failed';
  end if;
  if (select percentage from public.assessment_attempts where id = 'phase5-test') <> 0 then
    raise exception 'Percentage generation failed';
  end if;
  -- Invalid answers must roll back the parent insert too.
  begin
    perform public.save_assessment_attempt(
      jsonb_set(payload, '{id}', '"phase5-invalid"'), '[]');
    raise exception 'Invalid summary unexpectedly accepted';
  exception when check_violation then null;
  end;
  if exists (select 1 from public.assessment_attempts where id = 'phase5-invalid') then
    raise exception 'Failed save left an orphan attempt';
  end if;
  begin
    perform public.save_assessment_attempt(
      jsonb_set(payload, '{id}', '"phase5-foreign-option"'),
      '[{"question_id":"en_1","selected_option_id":"en_2_0","is_correct":false,"points_earned":0}]');
    raise exception 'Foreign option unexpectedly accepted';
  exception when foreign_key_violation then null;
  end;
  -- Even one's own completed history cannot be edited/deleted through the API.
  begin
    update public.assessment_attempts set score = 0 where id = 'phase5-test';
    raise exception 'History update unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.assessment_attempt_answers where attempt_id = 'phase5-test';
    raise exception 'Answer delete unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '55555555-5555-4555-8555-555555555552', true);
do $$
begin
  if exists (select 1 from public.assessment_attempts) or
     exists (select 1 from public.assessment_attempt_answers) then
    raise exception 'User B can read user A history';
  end if;
  begin
    insert into public.assessment_attempts(
      user_id, id, category_id, score, max_score, correct_count,
      incorrect_count, skipped_count, started_at, completed_at
    ) values ('55555555-5555-4555-8555-555555555551', 'forged',
      'english', 0, 1, 0, 0, 1, now(), now());
    raise exception 'Forged attempt owner unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.assessment_attempt_answers(
      user_id, attempt_id, question_id, is_correct, points_earned
    ) values ('55555555-5555-4555-8555-555555555551', 'phase5-test', 'en_2', false, 0);
    raise exception 'Cross-user answer insert unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.assessment_attempt_answers(
      attempt_id, question_id, is_correct, points_earned
    ) values ('phase5-test', 'en_2', false, 0);
    raise exception 'Answer attached to another owner unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;
set local role anon;
do $$
begin
  begin
    perform * from public.assessment_attempts;
    raise exception 'Anonymous attempt read unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    perform * from public.assessment_attempt_answers;
    raise exception 'Anonymous answer read unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.save_assessment_attempt('{}', '[]');
    raise exception 'Anonymous save unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;
rollback;
