-- Insert data into reminders_lists
INSERT INTO reminders_lists(color, name)
  VALUES (cast(x'4a99ef' AS integer), 'Personal');

INSERT INTO reminders_lists(color, name)
  VALUES (cast(x'ed8935' AS integer), 'Family');

INSERT INTO reminders_lists(color, name)
  VALUES (cast(x'b25dd3' AS integer), 'Business');

-- Insert data into reminders
INSERT INTO reminders(date, list_id, notes, title)
  VALUES (CURRENT_DATE, 1, 'Milk\nEggs\nApples\nOatmeal\nSpinach', 'Groceries');

INSERT INTO reminders(date, is_flagged, list_id, notes, title)
  VALUES (CURRENT_DATE - INTERVAL '2 days', TRUE, 1, '', 'Haircut');

INSERT INTO reminders(date, list_id, notes, priority, title)
  VALUES (CURRENT_DATE, 1, 'Ask about diet', 3, 'Doctor appointment');

INSERT INTO reminders(date, is_completed, list_id, notes, title)
  VALUES (CURRENT_DATE - INTERVAL '190 days', TRUE, 1, '', 'Take a walk');

INSERT INTO reminders(date, list_id, notes, title)
  VALUES (CURRENT_DATE, 1, '', 'Buy concert tickets');

INSERT INTO reminders(date, is_flagged, list_id, notes, priority, title)
  VALUES (CURRENT_DATE + INTERVAL '2 days', TRUE, 2, '', 3, 'Pick up kids from school');

INSERT INTO reminders(date, is_completed, list_id, notes, priority, title)
  VALUES (CURRENT_DATE - INTERVAL '2 days', TRUE, 2, '', 1, 'Get laundry');

INSERT INTO reminders(date, is_completed, list_id, notes, priority, title)
  VALUES (CURRENT_DATE + INTERVAL '4 days', FALSE, 2, '', 3, 'Take out trash');

INSERT INTO reminders(date, list_id, notes, title)
  VALUES (CURRENT_DATE + INTERVAL '2 days', 3, 'Status of tax return\nExpenses for next year\nChanging payroll company', 'Call accountant');

INSERT INTO reminders(date, is_completed, list_id, notes, priority, title)
  VALUES (CURRENT_DATE - INTERVAL '2 days', TRUE, 3, '', 2, 'Send weekly emails');

-- Insert data into tags
INSERT INTO tags(name)
  VALUES ('car');

INSERT INTO tags(name)
  VALUES ('kids');

INSERT INTO tags(name)
  VALUES ('someday');

INSERT INTO tags(name)
  VALUES ('optional');

-- Insert data into reminder_tags
INSERT INTO reminder_tags(reminder_id, tag_id)
  VALUES (1, 3);

INSERT INTO reminder_tags(reminder_id, tag_id)
  VALUES (1, 4);

INSERT INTO reminder_tags(reminder_id, tag_id)
  VALUES (2, 3);

INSERT INTO reminder_tags(reminder_id, tag_id)
  VALUES (2, 4);

INSERT INTO reminder_tags(reminder_id, tag_id)
  VALUES (4, 1);

INSERT INTO reminder_tags(reminder_id, tag_id)
  VALUES (4, 2);

