create table "public"."syncups" (
    "id" uuid primary key not null default gen_random_uuid(),
    "seconds" integer not null default 300,
    "theme" text not null default 'bubblegum'::text,
    "title" text not null
);
ALTER PUBLICATION supabase_realtime ADD TABLE syncups;

create table "public"."attendees" (
    "id" uuid primary key not null default gen_random_uuid(),
    "name" text not null,
    "syncup_id" uuid not null references syncups(id) on delete cascade
);
ALTER PUBLICATION supabase_realtime ADD TABLE attendees;

create table "public"."meetings" (
    "id" uuid primary key not null default gen_random_uuid(),
    "date" timestamp with time zone not null default now(),
    "syncup_id" uuid not null references syncups(id) on delete cascade,
    "transcript" text not null
);
ALTER PUBLICATION supabase_realtime ADD TABLE meetings;
