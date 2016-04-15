-- Convert schema 'sql/_source/deploy/18/001-auto.yml' to 'sql/_source/deploy/19/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE sms                 
                ADD COLUMN send_failed integer NULL,
                ADD COLUMN send_failed_count tinyint NULL;

;

COMMIT;

