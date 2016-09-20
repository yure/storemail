SHOW CREATE TABLE message;
SELECT * FROM message ORDER BY id DESC;
SELECT * FROM message WHERE send_queue IS NOT NULL ORDER BY id DESC;
SELECT * FROM message m LEFT JOIN email e ON e.message_id = m.id ORDER BY id DESC;
SELECT COUNT(*) FROM message WHERE message_id IS NULL ORDER BY id DESC;

UPDATE message SET send_queue = null WHERE send_queue IS NOT NULL AND domain = 'dev.necesit.ro' ORDER BY id DESC;
SELECT id, domain, frm, subject FROM message WHERE send_queue IS NOT NULL AND domain = 'dev.necesit.ro' ORDER BY id DESC;
SELECT * FROM message WHERE source = 'import_group' ORDER BY id DESC;