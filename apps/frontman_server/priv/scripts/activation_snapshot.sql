WITH bounds AS (
  SELECT date_trunc('week', CURRENT_TIMESTAMP AT TIME ZONE 'UTC') AS week_end
)
SELECT date_trunc('week', users.inserted_at)::date AS signup_week_utc,
       count(DISTINCT users.id) AS surviving_signups,
       count(DISTINCT users.id) FILTER (WHERE interactions.type = 'user_message')
         AS retained_user_message_users,
       count(DISTINCT users.id) FILTER (WHERE interactions.type = 'agent_completed')
         AS retained_agent_completed_users
FROM users
CROSS JOIN bounds
LEFT JOIN tasks ON tasks.user_id = users.id
LEFT JOIN interactions ON interactions.task_id = tasks.id
WHERE users.inserted_at >= bounds.week_end - INTERVAL '12 weeks'
  AND users.inserted_at < bounds.week_end
GROUP BY signup_week_utc
ORDER BY signup_week_utc;
