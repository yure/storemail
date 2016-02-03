-- Convert schema 'sql/_source/deploy/3/001-auto.yml' to 'sql/_source/deploy/4/001-auto.yml':;

;
BEGIN;

;
SET foreign_key_checks=0;

;
CREATE TABLE `click` (
  `id` integer NOT NULL auto_increment,
  `message_id` integer NOT NULL,
  `date` datetime NULL,
  `url` text NOT NULL,
  INDEX `click_idx_message_id` (`message_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `click_fk_message_id` FOREIGN KEY (`message_id`) REFERENCES `message` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

;
SET foreign_key_checks=1;

;

COMMIT;

