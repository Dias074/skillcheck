-- Run AFTER both migrations in the Supabase SQL Editor.
-- Uses synthetic users inside a transaction; ROLLBACK leaves no accounts/data.
begin;
insert into auth.users(id, email, raw_user_meta_data) values
  ('11111111-1111-4111-8111-111111111111', 'rls-a@example.test', '{"display_name":"RLS A"}'),
  ('22222222-2222-4222-8222-222222222222', 'rls-b@example.test', '{"display_name":"RLS B"}');
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
do $$
declare visible_count integer; changed_count integer;
begin
  select count(*) into visible_count from public.profiles;
  if visible_count <> 1 then raise exception 'Profile isolation failed'; end if;
  if not exists (select 1 from public.profiles where display_name = 'RLS A') then
    raise exception 'Profile trigger failed';
  end if;
  update public.profiles set display_name = 'Updated A' where id = '11111111-1111-4111-8111-111111111111';
  get diagnostics changed_count = row_count;
  if changed_count <> 1 then raise exception 'Own profile update failed'; end if;
  update public.profiles set display_name = 'Forbidden' where id = '22222222-2222-4222-8222-222222222222';
  get diagnostics changed_count = row_count;
  if changed_count <> 0 then raise exception 'Cross-user profile update allowed'; end if;
  if (select count(*) from public.categories) <> 5 then raise exception 'Seed categories missing'; end if;
  if (select count(*) from public.questions) <> 15 then raise exception 'Seed questions missing'; end if;
  begin
    update public.categories set name = 'Forbidden' where id = 'english';
    raise exception 'Content write unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.profiles(id) values ('33333333-3333-4333-8333-333333333333');
    raise exception 'Profile insert unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;
set local role anon;
do $$
begin
  begin
    perform * from public.questions;
    raise exception 'Anonymous content access unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    perform * from public.profiles;
    raise exception 'Anonymous profile access unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
end;
$$;
reset role;
-- Verify the database rejects a correct option from another question.
do $$
begin
  begin
    update public.questions set correct_option_id = 'en_2_0' where id = 'en_1';
    set constraints questions_correct_option_fkey immediate;
    raise exception 'Foreign option unexpectedly accepted';
  exception when foreign_key_violation then null;
  end;
end;
$$;
rollback;
