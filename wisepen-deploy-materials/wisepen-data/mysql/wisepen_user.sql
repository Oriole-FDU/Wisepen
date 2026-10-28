SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for user_group
-- ----------------------------
DROP TABLE IF EXISTS `user_group`;
CREATE TABLE `user_group`  (
  `group_id` bigint NOT NULL COMMENT '群组ID (雪花算法BIGINT)',
  `group_name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '群组名称',
  `group_desc` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '群组描述',
  `group_meta_info` json NULL COMMENT '小组扩展信息',
  `group_cover_url` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '群组封面URL',
  `group_type` tinyint NOT NULL COMMENT '群组类型',
  `owner_id` bigint NOT NULL COMMENT '群主ID (关联user_account的BIGINT)',
  `invite_code` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '邀请码',
  `member_count` int NOT NULL DEFAULT 0 COMMENT '成员数量',
  `token_used` int NOT NULL DEFAULT 0 COMMENT '组总共使用的Token',
  `token_balance` int NOT NULL DEFAULT 0 COMMENT '组Token余额',
  `ai_billing_policy` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'REVIEW_REQUIRED' COMMENT 'AI计费策略：DISABLED禁用、REVIEW_REQUIRED按资源审批、FREE自由计费',
  `del_flag` tinyint NOT NULL DEFAULT 0 COMMENT '逻辑删除 (0正常, 1删除)',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`group_id`) USING BTREE,
  UNIQUE INDEX `uk_invite_code`(`invite_code` ASC) USING BTREE,
  INDEX `idx_owner_id`(`owner_id` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户小组' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for group_member
-- ----------------------------
DROP TABLE IF EXISTS `group_member`;
CREATE TABLE `group_member`  (
  `group_id` bigint NOT NULL COMMENT '群组ID (关联user_group)',
  `user_id` bigint NOT NULL COMMENT '用户ID (关联user_account)',
  `role` tinyint NOT NULL COMMENT '小组角色：-1非成员，0所有者，1管理员，2普通成员',
  `join_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '加入时间',
  `token_limit` int NOT NULL DEFAULT 0 COMMENT '成员在组内的Token限额',
  `token_used` int NOT NULL DEFAULT 0 COMMENT '成员在组内已使用的Token',
  `ai_billing_priority` int NULL DEFAULT NULL COMMENT '用户使用多个小组支付AI费用时的优先级',
  PRIMARY KEY (`group_id`, `user_id`) USING BTREE,
  INDEX `idx_user_id`(`user_id` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '小组成员关系' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for group_resource_daily_metric
-- ----------------------------
DROP TABLE IF EXISTS `group_resource_daily_metric`;
CREATE TABLE `group_resource_daily_metric`  (
  `id` bigint NOT NULL COMMENT '主键',
  `group_id` bigint NOT NULL COMMENT '小组ID',
  `stat_date` date NOT NULL COMMENT '统计日期',
  `resource_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '资源ID',
  `resource_added_count` int NOT NULL DEFAULT 0 COMMENT '资源新增数',
  `resource_read_count` int NOT NULL DEFAULT 0 COMMENT '资源阅读数',
  `resource_like_count` int NOT NULL DEFAULT 0 COMMENT '资源点赞数',
  `resource_comment_count` int NOT NULL DEFAULT 0 COMMENT '资源评论数',
  `resource_ai_call_count` int NOT NULL DEFAULT 0 COMMENT '资源AI调用数',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_group_resource_daily_metric`(`group_id` ASC, `stat_date` ASC, `resource_id` ASC) USING BTREE,
  INDEX `idx_group_resource_daily_metric_read`(`group_id` ASC, `stat_date` ASC, `resource_read_count` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '小组资源每日统计' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for group_resource_summary_daily_metric
-- ----------------------------
DROP TABLE IF EXISTS `group_resource_summary_daily_metric`;
CREATE TABLE `group_resource_summary_daily_metric`  (
  `id` bigint NOT NULL COMMENT '主键',
  `group_id` bigint NOT NULL COMMENT '小组ID',
  `stat_date` date NOT NULL COMMENT '统计日期',
  `resource_added_count` int NOT NULL DEFAULT 0 COMMENT '资源新增数',
  `resource_read_count` int NOT NULL DEFAULT 0 COMMENT '资源阅读数',
  `resource_like_count` int NOT NULL DEFAULT 0 COMMENT '资源点赞数',
  `resource_comment_count` int NOT NULL DEFAULT 0 COMMENT '资源评论数',
  `resource_ai_call_count` int NOT NULL DEFAULT 0 COMMENT '资源AI调用数',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_group_resource_summary_daily_metric`(`group_id` ASC, `stat_date` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '小组资源每日汇总' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for group_resource_user_daily_metric
-- ----------------------------
DROP TABLE IF EXISTS `group_resource_user_daily_metric`;
CREATE TABLE `group_resource_user_daily_metric`  (
  `id` bigint NOT NULL COMMENT '主键',
  `group_id` bigint NOT NULL COMMENT '小组ID',
  `stat_date` date NOT NULL COMMENT '统计日期',
  `resource_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '资源ID',
  `actor_user_id` bigint NOT NULL COMMENT '行为用户ID',
  `resource_added_count` int NOT NULL DEFAULT 0 COMMENT '资源新增数',
  `resource_read_count` int NOT NULL DEFAULT 0 COMMENT '资源阅读数',
  `resource_like_count` int NOT NULL DEFAULT 0 COMMENT '资源点赞数',
  `resource_comment_count` int NOT NULL DEFAULT 0 COMMENT '资源评论数',
  `resource_ai_call_count` int NOT NULL DEFAULT 0 COMMENT '资源AI调用数',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_group_resource_user_daily_metric`(`group_id` ASC, `stat_date` ASC, `resource_id` ASC, `actor_user_id` ASC) USING BTREE,
  INDEX `idx_group_resource_user_daily_metric_read`(`group_id` ASC, `stat_date` ASC, `resource_id` ASC, `resource_read_count` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '小组资源用户每日统计' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for message
-- ----------------------------
DROP TABLE IF EXISTS `message`;
CREATE TABLE `message`  (
  `message_id` bigint NOT NULL COMMENT '消息ID',
  `delivery_scope` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '投递范围',
  `message_type` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '消息类型',
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '消息标题',
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '消息正文',
  `jump_url` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '消息跳转地址',
  `source_service` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '来源服务',
  `biz_trace_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '业务追踪ID',
  `extra` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '扩展信息',
  `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `read_count` bigint NOT NULL DEFAULT 0 COMMENT '已读人数',
  `message_hash` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '消息去重哈希',
  PRIMARY KEY (`message_id`) USING BTREE,
  UNIQUE INDEX `uk_source_biz_trace`(`source_service` ASC, `biz_trace_id` ASC) USING BTREE,
  INDEX `idx_scope_type_time`(`delivery_scope` ASC, `message_type` ASC, `create_time` ASC) USING BTREE,
  INDEX `idx_create_time`(`create_time` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '系统消息' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for message_recipient
-- ----------------------------
DROP TABLE IF EXISTS `message_recipient`;
CREATE TABLE `message_recipient`  (
  `id` bigint NOT NULL COMMENT '主键ID',
  `message_id` bigint NOT NULL COMMENT '消息ID',
  `delivery_scope` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '投递范围',
  `user_id` bigint NOT NULL COMMENT '接收用户ID',
  `read_time` datetime NULL DEFAULT NULL COMMENT '阅读时间',
  `delete_time` datetime NULL DEFAULT NULL COMMENT '用户删除时间',
  `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_user_message`(`user_id` ASC, `message_id` ASC) USING BTREE,
  INDEX `idx_user_scope_time`(`user_id` ASC, `delivery_scope` ASC, `create_time` ASC, `message_id` ASC) USING BTREE,
  INDEX `idx_user_delete_read_time`(`user_id` ASC, `delete_time` ASC, `read_time` ASC, `create_time` ASC) USING BTREE,
  INDEX `idx_message_id`(`message_id` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '消息接收记录' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for wallet_transaction_record
-- ----------------------------
DROP TABLE IF EXISTS `wallet_transaction_record`;
CREATE TABLE `wallet_transaction_record`  (
  `id` bigint NOT NULL COMMENT '主键ID',
  `trace_id` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '交易追踪ID',
  `operator_id` bigint NULL DEFAULT NULL COMMENT '操作用户ID',
  `payer_id` bigint NULL DEFAULT NULL COMMENT '付款方ID',
  `payer_type` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '付款方类型：USER、GROUP',
  `count` int NULL DEFAULT NULL COMMENT '变动数量',
  `wallet_transaction_type` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '钱包交易类型',
  `wallet_business_type` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '钱包业务类型',
  `meta` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '交易说明',
  `billing_detail` json NULL COMMENT 'Token计费明细JSON快照',
  `create_time` datetime NULL DEFAULT NULL COMMENT '创建时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_wallet_transaction_record_trace_id`(`trace_id` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '钱包交易流水' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for user_account
-- ----------------------------
DROP TABLE IF EXISTS `user_account`;
CREATE TABLE `user_account`  (
  `user_id` bigint NOT NULL COMMENT '主键ID (雪花算法)',
  `username` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '用户名 (唯一)',
  `campus_no` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '学工号',
  `password` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '加密密码',
  `identity_type` tinyint NOT NULL DEFAULT 1 COMMENT '身份 1:学生 2:老师 3:管理员',
  `nickname` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '昵称/显示名',
  `real_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '真实姓名',
  `avatar` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '头像URL',
  `email` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '绑定邮箱',
  `mobile` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '绑定手机',
  `user_status` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT 'UNIDENTIFIED' COMMENT '账号状态：NORMAL正常、UNIDENTIFIED未认证、BANNED封禁',
  `verification_mode` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '身份认证方式',
  `verification_provider_code` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '认证 Provider 编码',
  `del_flag` tinyint NULL DEFAULT 0 COMMENT '逻辑删除 0:未删 1:已删',
  `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`user_id`) USING BTREE,
  UNIQUE INDEX `uk_username`(`username` ASC) USING BTREE,
  INDEX `idx_email`(`email` ASC) USING BTREE,
  INDEX `idx_mobile`(`mobile` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户账号' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for user_invite_record
-- ----------------------------
DROP TABLE IF EXISTS `user_invite_record`;
CREATE TABLE `user_invite_record`  (
  `id` bigint NOT NULL COMMENT '主键',
  `inviter_user_id` bigint NOT NULL COMMENT '邀请人用户ID',
  `invitee_user_id` bigint NOT NULL COMMENT '被邀请人用户ID',
  `status` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'BOUND' COMMENT '邀请状态：BOUND、REWARDED',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `reward_time` datetime NULL DEFAULT NULL COMMENT '奖励兑现时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_invitee_user_id`(`invitee_user_id` ASC) USING BTREE,
  INDEX `idx_inviter_user_id`(`inviter_user_id` ASC) USING BTREE,
  INDEX `idx_inviter_create_time`(`inviter_user_id` ASC, `create_time` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户邀请记录' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for user_profile
-- ----------------------------
DROP TABLE IF EXISTS `user_profile`;
CREATE TABLE `user_profile`  (
  `user_id` bigint NOT NULL COMMENT '用户ID (关联 user_account.user_id)',
  `sex` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT 'UNKNOWN' COMMENT '性别',
  `university` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '复旦大学' COMMENT '所属高校',
  `college` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '所属学院 (如: 计算机科学技术学院)',
  `major` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '专业 (如: 软件工程)',
  `class_name` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '行政班 (如: 2022级硕1班)',
  `enrollment_year` int NULL DEFAULT NULL COMMENT '入学年份 (如: 2023)',
  `degree_level` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '培养层次',
  `academic_title` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '职称',
  `create_time` datetime NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `invite_code` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '用户专属邀请码',
  PRIMARY KEY (`user_id`) USING BTREE,
  UNIQUE INDEX `uk_user_profile_invite_code`(`invite_code` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户资料' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for user_task_record
-- ----------------------------
DROP TABLE IF EXISTS `user_task_record`;
CREATE TABLE `user_task_record`  (
  `id` bigint NOT NULL COMMENT '主键',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `task_code` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '任务类型',
  `reward_type` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'NONE' COMMENT '奖励类型：TOKEN、COIN、NONE',
  `reward_amount` int NOT NULL DEFAULT 0 COMMENT '奖励数量',
  `wallet_trace_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '对应钱包流水traceId',
  `meta` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '任务说明',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `complete_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '完成时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_user_task_time`(`user_id` ASC, `task_code` ASC, `complete_time` ASC) USING BTREE,
  INDEX `idx_wallet_trace_id`(`wallet_trace_id` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户任务完成记录' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for user_tour_record
-- ----------------------------
DROP TABLE IF EXISTS `user_tour_record`;
CREATE TABLE `user_tour_record`  (
  `id` bigint NOT NULL COMMENT '主键ID',
  `user_id` bigint NOT NULL COMMENT '用户ID',
  `tour_code` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL COMMENT '引导流程编码',
  `complete_time` datetime NOT NULL COMMENT '完成时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_user_tour`(`user_id` ASC, `tour_code` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_bin COMMENT = '用户引导完成记录' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for user_wallet
-- ----------------------------
DROP TABLE IF EXISTS `user_wallet`;
CREATE TABLE `user_wallet`  (
  `user_id` bigint NOT NULL COMMENT '用户ID（与 user_account.user_id 绑定）',
  `token_used` int NOT NULL DEFAULT 0 COMMENT '已用额度',
  `token_balance` int NOT NULL DEFAULT 0 COMMENT '额度上限',
  `coin_balance` int NOT NULL COMMENT 'Coin余额',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`user_id`) USING BTREE,
  CONSTRAINT `fk_user_wallets_user_id` FOREIGN KEY (`user_id`) REFERENCES `user_account` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户钱包' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Table structure for token_voucher
-- ----------------------------
DROP TABLE IF EXISTS `token_voucher`;
CREATE TABLE `token_voucher`  (
  `voucher_id` bigint NOT NULL COMMENT '点卡ID',
  `amount` int NULL DEFAULT NULL COMMENT 'Token额度',
  `code` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '兑换码',
  `status` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '点卡状态',
  `expire_time` datetime NULL DEFAULT NULL COMMENT '过期时间',
  PRIMARY KEY (`voucher_id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'Token点卡' ROW_FORMAT = DYNAMIC;

-- ----------------------------
-- Triggers structure for table group_member
-- ----------------------------
DROP TRIGGER IF EXISTS `trg_group_member_after_insert`;
delimiter ;;
CREATE TRIGGER `trg_group_member_after_insert` AFTER INSERT ON `group_member` FOR EACH ROW BEGIN
    UPDATE user_group
    SET member_count = IFNULL(member_count, 0) + 1
    WHERE group_id = NEW.group_id;
END
;;
delimiter ;

-- ----------------------------
-- Triggers structure for table group_member
-- ----------------------------
DROP TRIGGER IF EXISTS `trg_group_member_after_delete`;
delimiter ;;
CREATE TRIGGER `trg_group_member_after_delete` AFTER DELETE ON `group_member` FOR EACH ROW BEGIN
    UPDATE user_group
    SET member_count = IFNULL(member_count, 0) - 1
    WHERE group_id = OLD.group_id;
END
;;
delimiter ;

SET FOREIGN_KEY_CHECKS = 1;
