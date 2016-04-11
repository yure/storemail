-- 
-- Created by SQL::Translator::Producer::MySQL
-- Created on Thu Mar 17 14:36:22 2016
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
  `params` varchar(255) NULL,
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
-- Table: `group_email`
--
CREATE TABLE `group_email` (
  `group_id` integer NOT NULL,
  `email` varchar(90) NOT NULL,
  `name` varchar(90) NULL,
  `side` varchar(15) NOT NULL DEFAULT 'A',
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
  PRIMARY KEY (`id`),
  UNIQUE `message_id_UNIQUE` (`message_id`),
  CONSTRAINT `message_fk_batch_id` FOREIGN KEY (`batch_id`) REFERENCES `batch` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `message_fk_group_id` FOREIGN KEY (`group_id`) REFERENCES `message_group` (`id`) ON DELETE SET NULL ON UPDATE SET NULL
) ENGINE=InnoDB;
--
-- Table: `message_group`
--
CREATE TABLE `message_group` (
  `id` integer NOT NULL auto_increment,
  `value` varchar(90) NOT NULL,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE `value_UNIQUE` (`value`)
) ENGINE=InnoDB;
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
