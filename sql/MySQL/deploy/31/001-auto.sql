-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Mon Jun 13 12:28:57 2016
-- 
;
SET foreign_key_checks=0;
--
-- Table: `batch`
--
CREATE TABLE `batch` (
  `id` integer NOT NULL auto_increment,
  `domain` varchar(90) NULL,
  `name` varchar(255) NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;
--
-- Table: `click`
--
CREATE TABLE `click` (
  `id` integer NOT NULL auto_increment,
  `message_id` integer NOT NULL,
  `date` datetime NULL,
  `url` text NOT NULL,
  `host` varchar(255) NULL,
  `path` varchar(255) NULL,
  `params` text NULL,
  INDEX `click_idx_message_id` (`message_id`),
  PRIMARY KEY (`id`),
  CONSTRAINT `click_fk_message_id` FOREIGN KEY (`message_id`) REFERENCES `message` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
--
-- Table: `email`
--
CREATE TABLE `email` (
  `message_id` integer NOT NULL,
  `email` varchar(90) NOT NULL,
  `type` varchar(15) NOT NULL DEFAULT 'to',
  `name` varchar(90) NULL,
  INDEX `email_idx_message_id` (`message_id`),
  PRIMARY KEY (`message_id`, `email`, `type`),
  CONSTRAINT `email_fk_message_id` FOREIGN KEY (`message_id`) REFERENCES `message` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
--
-- Table: `email_blacklist`
--
CREATE TABLE `email_blacklist` (
  `email` varchar(90) NOT NULL,
  `timestamp` integer NOT NULL,
  `type` varchar(255) NULL,
  `reason` varchar(255) NULL,
  PRIMARY KEY (`email`)
);
--
-- Table: `group_email`
--
CREATE TABLE `group_email` (
  `group_id` integer NOT NULL,
  `email` varchar(255) NOT NULL,
  `name` varchar(90) NULL,
  `side` varchar(15) NOT NULL,
  `can_send` tinyint NOT NULL DEFAULT 1,
  `can_recieve` tinyint NOT NULL DEFAULT 1,
  INDEX `group_email_idx_group_id` (`group_id`),
  PRIMARY KEY (`group_id`, `email`),
  CONSTRAINT `group_email_fk_group_id` FOREIGN KEY (`group_id`) REFERENCES `message_group` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
--
-- Table: `message`
--
CREATE TABLE `message` (
  `id` integer NOT NULL auto_increment,
  `domain` varchar(255) NULL,
  `batch_id` integer NULL,
  `group_id` integer NULL,
  `group_message_parent_id` integer NULL,
  `frm` varchar(255) NOT NULL,
  `reply_to` varchar(255) NULL,
  `name` varchar(255) NULL,
  `body` text NULL,
  `plain_body` text NULL,
  `raw_body` text NULL,
  `date` timestamp NOT NULL DEFAULT current_timestamp,
  `subject` text NULL,
  `direction` varchar(1) NOT NULL,
  `new` tinyint NOT NULL DEFAULT 1,
  `send_queue` tinyint NULL,
  `send_queue_fail_count` tinyint NOT NULL DEFAULT 0,
  `send_queue_sleep` integer NOT NULL DEFAULT 0,
  `type` varchar(255) NOT NULL DEFAULT 'email',
  `body_type` varchar(255) NOT NULL DEFAULT 'plain',
  `message_id` varchar(255) NULL,
  `source` varchar(255) NULL,
  `sent` integer NULL,
  `opened` integer NULL,
  INDEX `message_idx_batch_id` (`batch_id`),
  INDEX `message_idx_group_id` (`group_id`),
  INDEX `message_idx_group_message_parent_id` (`group_message_parent_id`),
  PRIMARY KEY (`id`),
  UNIQUE `message_id_UNIQUE` (`message_id`),
  CONSTRAINT `message_fk_batch_id` FOREIGN KEY (`batch_id`) REFERENCES `batch` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `message_fk_group_id` FOREIGN KEY (`group_id`) REFERENCES `message_group` (`id`) ON DELETE SET NULL ON UPDATE SET NULL,
  CONSTRAINT `message_fk_group_message_parent_id` FOREIGN KEY (`group_message_parent_id`) REFERENCES `message` (`id`) ON DELETE SET NULL ON UPDATE SET NULL
) ENGINE=InnoDB;
--
-- Table: `message_group`
--
CREATE TABLE `message_group` (
  `id` integer NOT NULL auto_increment,
  `email` varchar(90) NOT NULL,
  `name` varchar(255) NULL,
  PRIMARY KEY (`id`),
  UNIQUE `email_UNIQUE` (`email`)
) ENGINE=InnoDB;
--
-- Table: `send_grid_event`
--
CREATE TABLE `send_grid_event` (
  `id` integer NOT NULL auto_increment,
  `timestamp` integer NULL,
  `sendgrid_id` varchar(64) NULL,
  `email` varchar(255) NULL,
  `type` varchar(255) NULL,
  `data` text NULL,
  `record_created` datetime NOT NULL,
  `record_updated` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE `send_grid_event_sendgrid_id` (`sendgrid_id`)
);
--
-- Table: `sms`
--
CREATE TABLE `sms` (
  `id` integer NOT NULL auto_increment,
  `domain` varchar(255) NULL,
  `frm` varchar(255) NOT NULL,
  `to` varchar(255) NOT NULL,
  `body` text NULL,
  `created` timestamp NOT NULL DEFAULT current_timestamp,
  `port` varchar(25) NULL,
  `send_queue` tinyint NULL,
  `send_status` tinyint NULL,
  `failover_send_status` smallint NULL,
  `send_failed` integer NULL,
  `send_timestamp` datetime NULL,
  `direction` varchar(1) NOT NULL,
  `gateway_id` varchar(255) NULL,
  PRIMARY KEY (`id`)
);
--
-- Table: `tag`
--
CREATE TABLE `tag` (
  `message_id` integer NOT NULL,
  `value` varchar(90) NOT NULL,
  INDEX `tag_idx_message_id` (`message_id`),
  PRIMARY KEY (`message_id`, `value`),
  CONSTRAINT `tag_fk_message_id` FOREIGN KEY (`message_id`) REFERENCES `message` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
SET foreign_key_checks=1;
