-- Announcements + a sample notification (dev). Run AFTER 0003_notifications.sql.
-- (Real notifications are created automatically by the triggers when staff assign
--  tasks or comment. This just gives the bar + bell something to show on first login.)

insert into announcements (body, created_by)
select 'Staff meeting Friday at 9:00 AM. Newsletter drafts due June 7.', p.id
from profiles p where p.email = 'andrew@sparrowinc.org';

insert into announcements (body, created_by)
select 'Reminder: submit June timesheets by the 5th.', p.id
from profiles p where p.email = 'andrew@sparrowinc.org';

-- One sample notification for the test admin so the bell shows an unread item.
-- Looks the user up by email, so it works regardless of the auth-linked id.
insert into notifications (user_id, actor_id, type, task_id, body)
select me.id, andrew.id, 'assigned', t.id, t.title
from profiles me, profiles andrew, tasks t
where me.email = 'ryanlhanson@gmail.com'
  and andrew.email = 'andrew@sparrowinc.org'
  and t.title = 'Review board onboarding packet'
limit 1;
