SET max_statement_time=0;
-- Expects @window_start, @window_end, and @duration to be set by the caller.

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'messages.total', '', @window_start, @duration, COUNT(*)
FROM messages_new
WHERE created_at >= @window_start AND created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'messages.unique_senders', '', @window_start, @duration, COUNT(DISTINCT user_id)
FROM messages_new
WHERE created_at >= @window_start AND created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'messages.unique_receivers', '', @window_start, @duration, COUNT(DISTINCT receiver_id)
FROM messages_new
WHERE created_at >= @window_start AND created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'posts.total', type, @window_start, @duration, COUNT(*)
FROM posts
WHERE created_at >= @window_start AND created_at < @window_end
GROUP BY type
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'posts.unique_users', 'blogged', @window_start, @duration, COUNT(DISTINCT b.user_id)
FROM posts p
JOIN blogs b ON b.id = p.blog_id
WHERE p.type = 'regular'
  AND p.created_at >= @window_start AND p.created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'activity.total', activity_type, @window_start, @duration, COUNT(*)
FROM activity
WHERE created_at >= @window_start AND created_at < @window_end
GROUP BY activity_type
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'activity.unique_users', activity_type, @window_start, @duration, COUNT(DISTINCT user_id)
FROM activity
WHERE created_at >= @window_start AND created_at < @window_end
GROUP BY activity_type
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'activity.active_users', '', @window_start, @duration, COUNT(DISTINCT user_id)
FROM activity
WHERE created_at >= @window_start AND created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'activity.premium_paying.active_users', '', @window_start, @duration, COUNT(DISTINCT a.user_id)
FROM activity a
JOIN users u ON u.id = a.user_id
WHERE u.premium > @window_end
  AND a.created_at >= @window_start AND a.created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'activity.premium_expired.active_users', '', @window_start, @duration, COUNT(DISTINCT a.user_id)
FROM activity a
JOIN users u ON u.id = a.user_id
WHERE u.premium > '0000-00-00' AND u.premium < @window_end
  AND a.created_at >= @window_start AND a.created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);


INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'users.premium.paying', '', @window_start, @duration, COUNT(*)
FROM users
WHERE premium > @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'users.premium.expired', '', @window_start, @duration, COUNT(*)
FROM users
WHERE premium > '0000-00-00' AND premium < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'messages.premium_paying.total', 'user_id', @window_start, @duration, COUNT(*)
FROM messages_new m
JOIN users u ON u.id = m.user_id
WHERE u.premium > @window_end
  AND m.created_at >= @window_start AND m.created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'messages.premium_paying.total', 'receiver_id', @window_start, @duration, COUNT(*)
FROM messages_new m
JOIN users u ON u.id = m.receiver_id
WHERE u.premium > @window_end
  AND m.created_at >= @window_start AND m.created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'messages.premium_paying.unique_senders', 'user_id', @window_start, @duration, COUNT(DISTINCT m.user_id)
FROM messages_new m
JOIN users u ON u.id = m.user_id
WHERE u.premium > @window_end
  AND m.created_at >= @window_start AND m.created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'messages.premium_paying.unique_receivers', 'user_id', @window_start, @duration, COUNT(DISTINCT m.receiver_id)
FROM messages_new m
JOIN users u ON u.id = m.user_id
WHERE u.premium > @window_end
  AND m.created_at >= @window_start AND m.created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'messages.premium_expired.total', 'user_id', @window_start, @duration, COUNT(*)
FROM messages_new m
JOIN users u ON u.id = m.user_id
WHERE u.premium > '0000-00-00' AND u.premium < @window_end
  AND m.created_at >= @window_start AND m.created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'messages.premium_expired.total', 'receiver_id', @window_start, @duration, COUNT(*)
FROM messages_new m
JOIN users u ON u.id = m.receiver_id
WHERE u.premium > '0000-00-00' AND u.premium < @window_end
  AND m.created_at >= @window_start AND m.created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'messages.premium_expired.unique_senders', 'user_id', @window_start, @duration, COUNT(DISTINCT m.user_id)
FROM messages_new m
JOIN users u ON u.id = m.user_id
WHERE u.premium > '0000-00-00' AND u.premium < @window_end
  AND m.created_at >= @window_start AND m.created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'messages.premium_expired.unique_receivers', 'user_id', @window_start, @duration, COUNT(DISTINCT m.receiver_id)
FROM messages_new m
JOIN users u ON u.id = m.user_id
WHERE u.premium > '0000-00-00' AND u.premium < @window_end
  AND m.created_at >= @window_start AND m.created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'posts.premium_paying.total', type, @window_start, @duration, COUNT(*)
FROM posts p
JOIN blogs b ON b.id = p.blog_id
JOIN users u ON u.id = b.user_id
WHERE u.premium > @window_end
  AND p.created_at >= @window_start AND p.created_at < @window_end
GROUP BY type
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'posts.premium_paying.unique_users', 'blogged', @window_start, @duration, COUNT(DISTINCT b.user_id)
FROM posts p
JOIN blogs b ON b.id = p.blog_id
JOIN users u ON u.id = b.user_id
WHERE u.premium > @window_end
  AND p.type = 'regular'
  AND p.created_at >= @window_start AND p.created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'posts.premium_expired.total', type, @window_start, @duration, COUNT(*)
FROM posts p
JOIN blogs b ON b.id = p.blog_id
JOIN users u ON u.id = b.user_id
WHERE u.premium > '0000-00-00' AND u.premium < @window_end
  AND p.created_at >= @window_start AND p.created_at < @window_end
GROUP BY type
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'posts.premium_expired.unique_users', 'blogged', @window_start, @duration, COUNT(DISTINCT b.user_id)
FROM posts p
JOIN blogs b ON b.id = p.blog_id
JOIN users u ON u.id = b.user_id
WHERE u.premium > '0000-00-00' AND u.premium < @window_end
  AND p.type = 'regular'
  AND p.created_at >= @window_start AND p.created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'activity.premium_paying.total', a.activity_type, @window_start, @duration, COUNT(*)
FROM activity a
JOIN users u ON u.id = a.user_id
WHERE u.premium > @window_end
  AND a.created_at >= @window_start AND a.created_at < @window_end
GROUP BY a.activity_type
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'activity.premium_paying.unique_users', a.activity_type, @window_start, @duration, COUNT(DISTINCT a.user_id)
FROM activity a
JOIN users u ON u.id = a.user_id
WHERE u.premium > @window_end
  AND a.created_at >= @window_start AND a.created_at < @window_end
GROUP BY a.activity_type
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'activity.premium_expired.total', a.activity_type, @window_start, @duration, COUNT(*)
FROM activity a
JOIN users u ON u.id = a.user_id
WHERE u.premium > '0000-00-00' AND u.premium < @window_end
  AND a.created_at >= @window_start AND a.created_at < @window_end
GROUP BY a.activity_type
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'activity.premium_expired.unique_users', a.activity_type, @window_start, @duration, COUNT(DISTINCT a.user_id)
FROM activity a
JOIN users u ON u.id = a.user_id
WHERE u.premium > '0000-00-00' AND u.premium < @window_end
  AND a.created_at >= @window_start AND a.created_at < @window_end
GROUP BY a.activity_type
ON DUPLICATE KEY UPDATE value=VALUES(value);


INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'messages.premium.unique_senders', 'receiver_id', @window_start, @duration, COUNT(DISTINCT m.user_id)
FROM messages_new m
JOIN users u ON u.id = m.receiver_id
WHERE u.premium > @window_end
  AND m.created_at >= @window_start AND m.created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'messages.premium.unique_receivers', 'receiver_id', @window_start, @duration, COUNT(DISTINCT m.receiver_id)
FROM messages_new m
JOIN users u ON u.id = m.receiver_id
WHERE u.premium > @window_end
  AND m.created_at >= @window_start AND m.created_at < @window_end
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'posts.premium.total', p.type, @window_start, @duration, COUNT(*)
FROM posts p
JOIN blogs b ON b.id = p.blog_id
JOIN users u ON u.id = b.user_id
WHERE u.premium > @window_end
  AND p.created_at >= @window_start AND p.created_at < @window_end
GROUP BY p.type
ON DUPLICATE KEY UPDATE value=VALUES(value);

INSERT INTO metrics_hourly (metric_name, dimension, window_start, duration_seconds, value)
SELECT 'activity.premium.total', a.activity_type, @window_start, @duration, COUNT(*)
FROM activity a
JOIN users u ON u.id = a.user_id
WHERE u.premium > @window_end
  AND a.created_at >= @window_start AND a.created_at < @window_end
GROUP BY a.activity_type
ON DUPLICATE KEY UPDATE value=VALUES(value);
