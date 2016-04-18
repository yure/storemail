-- Convert schema 'sql/_source/deploy/23/001-auto.yml' to 'sql/_source/deploy/24/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE sms DROP COLUMN fallback_send_status,
                DROP COLUMN send_failed_count,
                ADD COLUMN failover_send_status smallint NULL;

;

COMMIT;

