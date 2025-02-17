-- Add reminders lists table
CREATE TABLE reminders_lists(
  id serial PRIMARY KEY,
  color integer NOT NULL DEFAULT cast(x'4a99ef' AS integer),
  name text NOT NULL
);

ALTER publication supabase_realtime
  ADD TABLE reminders_lists;

-- Add reminders table
CREATE TABLE reminders(
  id serial PRIMARY KEY,
  date date,
  is_completed boolean NOT NULL DEFAULT FALSE,
  is_flagged boolean NOT NULL DEFAULT FALSE,
  list_id integer NOT NULL REFERENCES reminders_lists(id) ON DELETE CASCADE,
  notes text NOT NULL DEFAULT '',
  priority integer,
  title text NOT NULL
);

ALTER publication supabase_realtime
  ADD TABLE reminders;

-- Add tags table
CREATE TABLE tags(
  id serial PRIMARY KEY,
  name text NOT NULL UNIQUE
);

ALTER publication supabase_realtime
  ADD TABLE tags;

-- Add reminder tags table
CREATE TABLE reminder_tags(
  reminder_id integer NOT NULL REFERENCES reminders(id) ON DELETE CASCADE,
  tag_id integer NOT NULL REFERENCES tags(id) ON DELETE CASCADE
);

ALTER publication supabase_realtime
  ADD TABLE reminder_tags;

