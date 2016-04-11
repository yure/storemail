-- Convert schema 'sql/_source/deploy/10/001-auto.yml' to 'sql/_source/deploy/11/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE message ADD COLUMN reply_to varchar(255) NULL,
                    CHANGE COLUMN domain domain varchar(255) NULL,
                    CHANGE COLUMN frm frm varchar(255) NOT NULL,
                    CHANGE COLUMN name name varchar(255) NULL,
                    CHANGE COLUMN type type varchar(255) NOT NULL DEFAULT 'email',
                    CHANGE COLUMN body_type body_type varchar(255) NOT NULL DEFAULT 'plain',
                    CHANGE COLUMN message_id message_id varchar(255) NULL,
                    CHANGE COLUMN source source varchar(255) NULL;

;

COMMIT;

