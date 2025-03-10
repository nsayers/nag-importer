-- MySQL dump 10.19  Distrib 10.3.32-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: nagios
-- ------------------------------------------------------
-- Server version	10.3.32-MariaDB-0ubuntu0.20.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `command`
--

DROP TABLE IF EXISTS `command`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `command` (
  `id` int(255) AUTO_INCREMENT,
  `command_name` varchar(255) DEFAULT NULL,
  `command_line` text DEFAULT NULL,
  `use` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `notes_url` varchar(255) DEFAULT NULL,
  `action_url` varchar(255) DEFAULT NULL,
  `register` int(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `command`
--

LOCK TABLES `command` WRITE;
/*!40000 ALTER TABLE `command` DISABLE KEYS */;
/*!40000 ALTER TABLE `command` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contact`
--

DROP TABLE IF EXISTS `contact`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `contact` (
  `id` int(255) AUTO_INCREMENT,
  `contact_name` varchar(255) DEFAULT NULL,
  `alias` varchar(255) DEFAULT NULL,
  `use` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `contactgroups` varchar(255) DEFAULT NULL,
  `host_notifications_enabled` int(1) NOT NULL DEFAULT 1,
  `service_notifications_enabled` int(1) NOT NULL DEFAULT 1,
  `host_notification_period` varchar(255) NOT NULL DEFAULT '24x7',
  `service_notification_period` varchar(255) NOT NULL DEFAULT '24x7',
  `host_notification_options` varchar(14) NOT NULL DEFAULT 'd,u,r',
  `service_notification_options` varchar(14) NOT NULL DEFAULT 'w,u,c,r',
  `host_notification_commands` varchar(255) NOT NULL,
  `service_notification_commands` varchar(255) NOT NULL,
  `hostgroup_members` varchar(255) DEFAULT NULL,
  `servicegroup_members` varchar(255) DEFAULT NULL,
  `contactgroup_members` varchar(255) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `pager` varchar(255) DEFAULT NULL,
  `addressx` varchar(255) DEFAULT NULL,
  `can_submit_commands` int(1) DEFAULT NULL,
  `retain_status_information` int(1) DEFAULT NULL,
  `retain_nonstatus_information` int(1) DEFAULT NULL,
  `_PROWL` varchar(255) DEFAULT NULL,
  `_PROWL_PRIO_UP` varchar(255) DEFAULT NULL,
  `_PROWL_PRIO_OK` varchar(255) DEFAULT NULL,
  `_PROWL_PRIO_DOWN` varchar(255) DEFAULT NULL,
  `_PROWL_PRIO_WARN` varchar(255) DEFAULT NULL,
  `_PROWL_PRIO_CRIT` varchar(255) DEFAULT NULL,
  `_PROWL_PRIO_UNK` varchar(255) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `notes_url` varchar(255) DEFAULT NULL,
  `action_url` varchar(255) DEFAULT NULL,
  `register` int(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `contact`
--

LOCK TABLES `contact` WRITE;
/*!40000 ALTER TABLE `contact` DISABLE KEYS */;
/*!40000 ALTER TABLE `contact` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contactgroup`
--

DROP TABLE IF EXISTS `contactgroup`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `contactgroup` (
  `id` int(255) AUTO_INCREMENT,
  `contactgroup_name` varchar(255) DEFAULT NULL,
  `use` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `alias` varchar(255) DEFAULT NULL,
  `members` varchar(255) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `notes_url` varchar(255) DEFAULT NULL,
  `action_url` varchar(255) DEFAULT NULL,
  `register` int(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `contactgroup`
--

LOCK TABLES `contactgroup` WRITE;
/*!40000 ALTER TABLE `contactgroup` DISABLE KEYS */;
/*!40000 ALTER TABLE `contactgroup` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `host`
--

DROP TABLE IF EXISTS `host`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `host` (
  `id` int(255) AUTO_INCREMENT,
  `host_name` varchar(255) DEFAULT NULL,
  `use` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `alias` varchar(255) DEFAULT NULL,
  `display_name` varchar(255) DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `parents` varchar(255) DEFAULT NULL,
  `hostgroups` varchar(255) DEFAULT NULL,
  `host_groups` varchar(255) DEFAULT NULL,
  `check_command` varchar(255) DEFAULT NULL,
  `initial_state` varchar(10) DEFAULT NULL,
  `max_check_attempts` int(2) NOT NULL DEFAULT 3,
  `check_interval` int(4) DEFAULT NULL,
  `retry_interval` int(4) DEFAULT NULL,
  `retry_check_interval` int(4) DEFAULT NULL,
  `active_checks_enabled` int(1) DEFAULT NULL,
  `passive_checks_enabled` int(1) DEFAULT NULL,
  `check_period` varchar(255) NOT NULL DEFAULT '24x7',
  `obsess_over_host` int(1) DEFAULT NULL,
  `check_freshness` int(1) DEFAULT NULL,
  `freshness_threshold` int(4) DEFAULT NULL,
  `event_handler` varchar(255) DEFAULT NULL,
  `event_handler_enabled` int(1) DEFAULT NULL,
  `low_flap_threshold` int(4) DEFAULT NULL,
  `high_flap_threshold` int(4) DEFAULT NULL,
  `flap_detection_enabled` int(1) DEFAULT NULL,
  `flap_detection_options` varchar(10) DEFAULT NULL,
  `process_perf_data` int(1) DEFAULT NULL,
  `retain_status_information` int(1) DEFAULT NULL,
  `retain_nonstatus_information` int(1) DEFAULT NULL,
  `contacts` varchar(255) DEFAULT NULL,
  `contact_groups` varchar(255) NOT NULL DEFAULT 'admin',
  `notification_interval` varchar(255) DEFAULT NULL,
  `first_notification_delay` int(4) DEFAULT NULL,
  `notification_period` varchar(255) NOT NULL DEFAULT '24x7',
  `notification_options` varchar(10) DEFAULT NULL,
  `notifications_enabled` int(1) DEFAULT NULL,
  `stalking_options` varchar(10) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `notes_url` varchar(255) DEFAULT NULL,
  `action_url` varchar(255) DEFAULT NULL,
  `icon_image` varchar(255) DEFAULT NULL,
  `icon_image_alt` varchar(255) DEFAULT NULL,
  `vrml_image` varchar(255) DEFAULT NULL,
  `statusmap_image` varchar(255) DEFAULT NULL,
  `2d_coords` varchar(255) DEFAULT NULL,
  `3d_coords` varchar(255) DEFAULT NULL,
  `register` int(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `host`
--

LOCK TABLES `host` WRITE;
/*!40000 ALTER TABLE `host` DISABLE KEYS */;
/*!40000 ALTER TABLE `host` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `hostdependency`
--

DROP TABLE IF EXISTS `hostdependency`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `hostdependency` (
  `id` int(255) AUTO_INCREMENT,
  `dependent_host` varchar(255) DEFAULT NULL,
  `dependent_hostgroup_name` varchar(255) DEFAULT NULL,
  `use` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `host_name` varchar(255) DEFAULT NULL,
  `hostgroup_name` varchar(255) DEFAULT NULL,
  `inherits_parent` int(1) DEFAULT NULL,
  `execution_failure_criteria` varchar(14) DEFAULT NULL,
  `notification_failure_criteria` varchar(14) DEFAULT NULL,
  `dependency_period` varchar(255) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `notes_url` varchar(255) DEFAULT NULL,
  `action_url` varchar(255) DEFAULT NULL,
  `register` int(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `hostdependency`
--

LOCK TABLES `hostdependency` WRITE;
/*!40000 ALTER TABLE `hostdependency` DISABLE KEYS */;
/*!40000 ALTER TABLE `hostdependency` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `hostescalation`
--

DROP TABLE IF EXISTS `hostescalation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `hostescalation` (
  `id` int(255) AUTO_INCREMENT,
  `host_name` varchar(255) DEFAULT NULL,
  `use` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `hostgroup_name` varchar(255) DEFAULT NULL,
  `contacts` varchar(255) DEFAULT NULL,
  `contact_groups` varchar(255) DEFAULT NULL,
  `first_notification` int(10) DEFAULT NULL,
  `last_notification` int(10) DEFAULT NULL,
  `notification_interval` varchar(255) DEFAULT NULL,
  `escalation_period` varchar(255) DEFAULT NULL,
  `escalation_options` varchar(14) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `notes_url` varchar(255) DEFAULT NULL,
  `action_url` varchar(255) DEFAULT NULL,
  `register` int(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `hostescalation`
--

LOCK TABLES `hostescalation` WRITE;
/*!40000 ALTER TABLE `hostescalation` DISABLE KEYS */;
/*!40000 ALTER TABLE `hostescalation` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `hostextinfo`
--

DROP TABLE IF EXISTS `hostextinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `hostextinfo` (
  `id` int(255) AUTO_INCREMENT,
  `host_name` varchar(255) DEFAULT NULL,
  `use` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `notes_url` varchar(255) DEFAULT NULL,
  `action_url` varchar(255) DEFAULT NULL,
  `icon_image` varchar(255) DEFAULT NULL,
  `icon_image_alt` varchar(255) DEFAULT NULL,
  `vrml_image` varchar(255) DEFAULT NULL,
  `statusmap_image` varchar(255) DEFAULT NULL,
  `2d_coords` varchar(255) DEFAULT NULL,
  `3d_coords` varchar(255) DEFAULT NULL,
  `register` int(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `hostextinfo`
--

LOCK TABLES `hostextinfo` WRITE;
/*!40000 ALTER TABLE `hostextinfo` DISABLE KEYS */;
/*!40000 ALTER TABLE `hostextinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `hostgroup`
--

DROP TABLE IF EXISTS `hostgroup`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `hostgroup` (
  `id` int(255) AUTO_INCREMENT,
  `hostgroup_name` varchar(255) NOT NULL,
  `use` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `alias` varchar(255) DEFAULT NULL,
  `members` TEXT DEFAULT NULL,
  `hostgroup_members` varchar(255) DEFAULT NULL,
  `servicegroup_members` varchar(255) DEFAULT NULL,
  `contactgroup_members` varchar(255) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `notes_url` varchar(255) DEFAULT NULL,
  `action_url` varchar(255) DEFAULT NULL,
  `register` int(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `hostgroup`
--

LOCK TABLES `hostgroup` WRITE;
/*!40000 ALTER TABLE `hostgroup` DISABLE KEYS */;
/*!40000 ALTER TABLE `hostgroup` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `service`
--

DROP TABLE IF EXISTS `service`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `service` (
  `id` int(255) AUTO_INCREMENT,
  `host_name` varchar(255) DEFAULT NULL,
  `hostgroup_name` varchar(255) DEFAULT NULL,
  `use` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `alias` varchar(255) DEFAULT NULL,
  `service_description` varchar(255) DEFAULT NULL,
  `display_name` varchar(255) DEFAULT NULL,
  `servicegroups` varchar(255) DEFAULT NULL,
  `is_volatile` int(1) DEFAULT NULL,
  `check_command` varchar(255) DEFAULT NULL,
  `initial_state` varchar(10) DEFAULT NULL,
  `max_check_attempts` int(4) DEFAULT NULL,
  `check_interval` int(4) DEFAULT NULL,
  `normal_check_interval` int(4) DEFAULT NULL,
  `retry_interval` int(4) DEFAULT NULL,
  `retry_check_interval` int(4) DEFAULT NULL,
  `active_checks_enabled` int(1) DEFAULT NULL,
  `passive_checks_enabled` int(1) DEFAULT NULL,
  `enable_predictive_service_dependency_checks` int(4) DEFAULT NULL,
  `check_period` varchar(255) DEFAULT NULL,
  `obsess_over_service` int(1) DEFAULT NULL,
  `check_freshness` int(1) DEFAULT NULL,
  `freshness_threshold` int(4) DEFAULT NULL,
  `event_handler` varchar(255) DEFAULT NULL,
  `event_handler_enabled` int(1) DEFAULT NULL,
  `low_flap_threshold` int(4) DEFAULT NULL,
  `high_flap_threshold` int(4) DEFAULT NULL,
  `flap_detection_enabled` int(4) DEFAULT NULL,
  `flap_detection_options` varchar(10) DEFAULT NULL,
  `process_perf_data` int(1) DEFAULT NULL,
  `retain_status_information` int(1) DEFAULT NULL,
  `retain_nonstatus_information` int(1) DEFAULT NULL,
  `notification_interval` varchar(255) DEFAULT NULL,
  `first_notification_delay` int(4) DEFAULT NULL,
  `notification_period` varchar(255) NOT NULL DEFAULT '24x7',
  `notification_options` varchar(14) DEFAULT NULL,
  `notifications_enabled` int(1) DEFAULT NULL,
  `failure_prediction_enabled` varchar(255) DEFAULT NULL,
  `contacts` varchar(255) DEFAULT NULL,
  `contact_groups` varchar(255) DEFAULT NULL,
  `stalking_options` varchar(14) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `notes_url` varchar(255) DEFAULT NULL,
  `action_url` varchar(255) DEFAULT NULL,
  `icon_image` varchar(255) DEFAULT NULL,
  `icon_image_alt` varchar(255) DEFAULT NULL,
  `register` int(1) DEFAULT NULL,
  `parallelize_check` int(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `service`
--

LOCK TABLES `service` WRITE;
/*!40000 ALTER TABLE `service` DISABLE KEYS */;
/*!40000 ALTER TABLE `service` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `servicedependency`
--

DROP TABLE IF EXISTS `servicedependency`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `servicedependency` (
  `id` int(255) AUTO_INCREMENT,
  `host_name` varchar(255) DEFAULT NULL,
  `use` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `dependent_host_name` varchar(255) DEFAULT NULL,
  `dependent_hostgroup_name` varchar(255) DEFAULT NULL,
  `servicegroup_name` varchar(255) DEFAULT NULL,
  `dependent_servicegroup_name` varchar(255) DEFAULT NULL,
  `dependent_service_description` varchar(255) DEFAULT NULL,
  `hostgroup_name` varchar(255) NOT NULL,
  `service_description` varchar(255) NOT NULL,
  `inherits_parent` smallint(2) DEFAULT NULL,
  `execution_failure_criteria` varchar(14) NOT NULL,
  `notification_failure_criteria` varchar(14) NOT NULL,
  `dependency_period` varchar(255) NOT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `notes_url` varchar(255) DEFAULT NULL,
  `action_url` varchar(255) DEFAULT NULL,
  `register` int(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `servicedependency`
--

LOCK TABLES `servicedependency` WRITE;
/*!40000 ALTER TABLE `servicedependency` DISABLE KEYS */;
/*!40000 ALTER TABLE `servicedependency` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `serviceescalation`
--

DROP TABLE IF EXISTS `serviceescalation`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `serviceescalation` (
  `id` int(255) AUTO_INCREMENT,
  `host_name` varchar(255) DEFAULT NULL,
  `hostgroup_name` varchar(255) DEFAULT NULL,
  `use` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `service_description` varchar(255) DEFAULT NULL,
  `contacts` varchar(255) DEFAULT NULL,
  `contact_groups` varchar(255) DEFAULT NULL,
  `first_notification` int(10) DEFAULT NULL,
  `last_notification` int(10) DEFAULT NULL,
  `notification_interval` varchar(255) DEFAULT NULL,
  `escalation_period` varchar(255) DEFAULT NULL,
  `escalation_options` varchar(14) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `notes_url` varchar(255) DEFAULT NULL,
  `action_url` varchar(255) DEFAULT NULL,
  `register` int(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `serviceescalation`
--

LOCK TABLES `serviceescalation` WRITE;
/*!40000 ALTER TABLE `serviceescalation` DISABLE KEYS */;
/*!40000 ALTER TABLE `serviceescalation` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `serviceextinfo`
--

DROP TABLE IF EXISTS `serviceextinfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `serviceextinfo` (
  `id` int(255) AUTO_INCREMENT,
  `host_name` varchar(255) DEFAULT NULL,
  `service_description` varchar(255) DEFAULT NULL,
  `use` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `notes_url` varchar(255) DEFAULT NULL,
  `action_url` varchar(255) DEFAULT NULL,
  `icon_image` varchar(255) DEFAULT NULL,
  `icon_image_alt` varchar(255) DEFAULT NULL,
  `register` int(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `serviceextinfo`
--

LOCK TABLES `serviceextinfo` WRITE;
/*!40000 ALTER TABLE `serviceextinfo` DISABLE KEYS */;
/*!40000 ALTER TABLE `serviceextinfo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `servicegroup`
--

DROP TABLE IF EXISTS `servicegroup`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `servicegroup` (
  `id` int(255) AUTO_INCREMENT,
  `servicegroup_name` varchar(255) DEFAULT NULL,
  `alias` varchar(255) DEFAULT NULL,
  `members` text DEFAULT NULL,
  `use` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `hostgroup_members` varchar(255) DEFAULT NULL,
  `servicegroup_members` varchar(255) DEFAULT NULL,
  `contactgroup_members` varchar(255) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `notes_url` varchar(255) DEFAULT NULL,
  `action_url` varchar(255) DEFAULT NULL,
  `register` int(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `servicegroup`
--

LOCK TABLES `servicegroup` WRITE;
/*!40000 ALTER TABLE `servicegroup` DISABLE KEYS */;
/*!40000 ALTER TABLE `servicegroup` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `timeperiod`
--

DROP TABLE IF EXISTS `timeperiod`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `timeperiod` (
  `id` int(255) AUTO_INCREMENT,
  `timeperiod_name` varchar(255) DEFAULT NULL,
  `alias` varchar(255) DEFAULT NULL,
  `use` varchar(255) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `sunday` varchar(255) NOT NULL DEFAULT '00:00-24:00',
  `monday` varchar(255) NOT NULL DEFAULT '00:00-24:00',
  `tuesday` varchar(255) NOT NULL DEFAULT '00:00-24:00',
  `wednesday` varchar(255) NOT NULL DEFAULT '00:00-24:00',
  `thursday` varchar(255) NOT NULL DEFAULT '00:00-24:00',
  `friday` varchar(255) NOT NULL DEFAULT '00:00-24:00',
  `saturday` varchar(255) NOT NULL DEFAULT '00:00-24:00',
  `notes` varchar(255) DEFAULT NULL,
  `notes_url` varchar(255) DEFAULT NULL,
  `action_url` varchar(255) DEFAULT NULL,
  `register` int(1) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `timeperiod`
--

LOCK TABLES `timeperiod` WRITE;
/*!40000 ALTER TABLE `timeperiod` DISABLE KEYS */;
/*!40000 ALTER TABLE `timeperiod` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2022-01-20 16:44:11
