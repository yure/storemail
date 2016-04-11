-- Convert schema 'sql/_source/deploy/7/001-auto.yml' to 'sql/_source/deploy/8/001-auto.yml':;

;
BEGIN;

;
SET foreign_key_checks=0;

;
CREATE TABLE `group_email` (
  `group_id` integer NOT NULL,
  `email` varchar(90) NOT NULL,
  `name` varchar(90) NULL,
  `side` varchar(15) NOT NULL DEFAULT 'A',
  INDEX `group_email_idx_group_id` (`group_id`),
  PRIMARY KEY (`group_id`, `email`),
  CONSTRAINT `group_email_fk_group_id` FOREIGN KEY (`group_id`) REFERENCES `message_group` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

;
CREATE TABLE `message_group` (
  `id` integer NOT NULL,
  `email` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE `value_UNIQUE` (`value`)
) ENGINE=InnoDB;

;
SET foreign_key_checks=1;

;
ALTER TABLE message ADD COLUMN group_id integer NULL,
                    ADD INDEX message_idx_group_id (group_id),
                    ADD CONSTRAINT message_fk_group_id FOREIGN KEY (group_id) REFERENCES message_group (id) ON DELETE SET NULL ON UPDATE SET NULL;

;

COMMIT;

