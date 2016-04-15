-- Convert schema 'sql/_source/deploy/20/001-auto.yml' to 'sql/_source/deploy/21/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE sms ADD COLUMN fallback_send_status tinyint NULL;

;

COMMIT;

