-- Convert schema 'sql/_source/deploy/12/001-auto.yml' to 'sql/_source/deploy/13/001-auto.yml':;

;
BEGIN;

;
ALTER TABLE message ADD COLUMN group_message_parent_id integer NULL,
                    ADD INDEX message_idx_group_message_parent_id (group_message_parent_id),
                    ADD CONSTRAINT message_fk_group_message_parent_id FOREIGN KEY (group_message_parent_id) REFERENCES message (id) ON DELETE SET NULL ON UPDATE SET NULL;

;

COMMIT;

