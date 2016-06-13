-- Convert schema 'sql/_source/deploy/31/001-auto.yml' to 'sql/_source/deploy/32/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE email_blacklist ADD COLUMN record_created datetime NOT NULL,
                            ADD COLUMN record_updated datetime NOT NULL;

;

COMMIT;

