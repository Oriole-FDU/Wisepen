-- =============================================================================
-- 02-wisepen-user.sql
-- -----------------------------------------------------------------------------
-- wisepen_user 库 schema
-- 警告：本文件含 DROP TABLE IF EXISTS，**不可重入**。重复执行会清空数据。
-- =============================================================================
CREATE DATABASE IF NOT EXISTS wisepen_user DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE wisepen_user;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for sys_group
-- ----------------------------
DROP TABLE IF EXISTS `sys_group`;
CREATE TABLE `sys_group`  (
  `group_id` bigint NOT NULL COMMENT '群组ID (雪花算法BIGINT)',
  `group_name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '群组名称',
  `group_desc` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '群组描述',
  `group_cover_url` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '群组封面URL',
  `group_type` tinyint NOT NULL COMMENT '群组类型',
  `owner_id` bigint NOT NULL COMMENT '群主ID (关联sys_user的BIGINT)',
  `invite_code` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '邀请码',
  `member_count` int NOT NULL DEFAULT 0 COMMENT '成员数量',
  `token_used` int NOT NULL DEFAULT 0 COMMENT '组总共使用的Token',
  `token_balance` int NOT NULL DEFAULT 0 COMMENT '组Token余额',
  `del_flag` tinyint NOT NULL DEFAULT 0 COMMENT '逻辑删除 (0正常, 1删除)',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`group_id`) USING BTREE,
  UNIQUE INDEX `uk_invite_code`(`invite_code` ASC) USING BTREE,
  INDEX `idx_owner_id`(`owner_id` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '群组核心表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for sys_group_member
-- ----------------------------
DROP TABLE IF EXISTS `sys_group_member`;
CREATE TABLE `sys_group_member`  (
  `group_id` bigint NOT NULL COMMENT '群组ID (关联sys_group)',
  `user_id` bigint NOT NULL COMMENT '用户ID (关联sys_user)',
  `role` tinyint NOT NULL COMMENT 'OWNER(0, \"OWNER\"),\r\n    ADMIN(1, \"ADMIN\"),\r\n    MEMBER(2, \"MEMBER\"),\r\n    NOT_MEMBER(-1, \"NOT_MEMBER\");',
  `join_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '加入时间',
  `token_limit` int NOT NULL DEFAULT 0 COMMENT '成员在组内的Token限额',
  `token_used` int NOT NULL DEFAULT 0 COMMENT '成员在组内已使用的Token',
  PRIMARY KEY (`group_id`, `user_id`) USING BTREE,
  INDEX `idx_user_id`(`user_id` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '群组成员关系表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for sys_token_record
-- ----------------------------
DROP TABLE IF EXISTS `sys_token_record`;
CREATE TABLE `sys_token_record`  (
  `id` bigint NOT NULL,
  `trace_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `operator_id` bigint NULL DEFAULT NULL COMMENT '操作方 Id',
  `payer_id` bigint NULL DEFAULT NULL,
  `payer_type` tinyint NULL DEFAULT NULL COMMENT 'USER(1,\"USER\"),\r\n	GROUP(2,\"GROUP\");',
  `token_count` int NULL DEFAULT NULL,
  `token_transaction_type` tinyint NOT NULL COMMENT 'REFILL(1, \"REFILL\"),\r\n	SPEND(2, \"SPEND\"),\r\n	TRANSFER_IN(3, \"TRANSFER_IN\"),\r\n	TRANSFER_OUT(4, \"TRANSFER_OUT\");',
  `meta` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `create_time` datetime NULL DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for sys_user
-- ----------------------------
DROP TABLE IF EXISTS `sys_user`;
CREATE TABLE `sys_user`  (
  `user_id` bigint NOT NULL COMMENT '主键ID (雪花算法)',
  `username` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '用户名 (唯一)',
  `campus_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT 'PENDING',
  `password` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '加密密码',
  `identity_type` tinyint NOT NULL DEFAULT 1 COMMENT '身份 1:学生 2:老师 3:管理员',
  `nickname` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '昵称/显示名',
  `real_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `avatar` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '头像URL',
  `email` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '绑定邮箱',
  `mobile` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '绑定手机',
  `status` tinyint NULL DEFAULT 1 COMMENT '状态 1:正常 0:禁用',
  `verification_mode` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `del_flag` tinyint NULL DEFAULT 0 COMMENT '逻辑删除 0:未删 1:已删',
  `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`) USING BTREE,
  UNIQUE INDEX `uk_username`(`username` ASC) USING BTREE,
  INDEX `idx_email`(`email` ASC) USING BTREE,
  INDEX `idx_mobile`(`mobile` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户核心账号表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for sys_user_profile
-- ----------------------------
DROP TABLE IF EXISTS `sys_user_profile`;
CREATE TABLE `sys_user_profile`  (
  `user_id` bigint NOT NULL COMMENT '用户ID (关联 sys_user.id)',
  `sex` tinyint NULL DEFAULT 2 COMMENT '性别 0:男 1:女',
  `university` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '复旦大学' COMMENT '所属高校',
  `college` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '所属学院 (如: 计算机科学技术学院)',
  `major` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '专业 (如: 软件工程)',
  `class_name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '行政班 (如: 2022级硕1班)',
  `enrollment_year` int NULL DEFAULT NULL COMMENT '入学年份 (如: 2023)',
  `degree_level` tinyint NULL DEFAULT NULL COMMENT '培养层次 1:本科 2:硕士 3:博士',
  `academic_title` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '职称',
  `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP,
  `update_time` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户详细档案表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for sys_user_wallets
-- ----------------------------
DROP TABLE IF EXISTS `sys_user_wallets`;
CREATE TABLE `sys_user_wallets`  (
  `user_id` bigint NOT NULL COMMENT '用户ID（与 sys_user.id 绑定）',
  `token_used` int NOT NULL DEFAULT 0 COMMENT '已用额度',
  `token_balance` int NOT NULL DEFAULT 0 COMMENT '额度上限',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`user_id`) USING BTREE,
  CONSTRAINT `fk_user_wallets_user_id` FOREIGN KEY (`user_id`) REFERENCES `sys_user` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户额度钱包表' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for sys_vouchers
-- ----------------------------
DROP TABLE IF EXISTS `sys_vouchers`;
CREATE TABLE `sys_vouchers`  (
  `voucher_id` bigint NOT NULL,
  `amount` int NULL DEFAULT NULL,
  `code` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `status` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `expire_time` datetime NULL DEFAULT NULL,
  PRIMARY KEY (`voucher_id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Triggers structure for table sys_group_member
-- ----------------------------
DROP TRIGGER IF EXISTS `trg_sys_group_member_after_insert`;
delimiter ;;
CREATE TRIGGER `trg_sys_group_member_after_insert` AFTER INSERT ON `sys_group_member` FOR EACH ROW BEGIN
    UPDATE sys_group
    SET member_count = IFNULL(member_count, 0) + 1
    WHERE group_id = NEW.group_id;
END
;;
delimiter ;

-- ----------------------------
-- Triggers structure for table sys_group_member
-- ----------------------------
DROP TRIGGER IF EXISTS `trg_sys_group_member_after_delete`;
delimiter ;;
CREATE TRIGGER `trg_sys_group_member_after_delete` AFTER DELETE ON `sys_group_member` FOR EACH ROW BEGIN
    UPDATE sys_group
    SET member_count = IFNULL(member_count, 0) - 1
    WHERE group_id = OLD.group_id;
END
;;
delimiter ;

SET FOREIGN_KEY_CHECKS = 1;
