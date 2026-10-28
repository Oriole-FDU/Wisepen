SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for storage_record
-- ----------------------------
DROP TABLE IF EXISTS `storage_record`;
CREATE TABLE `storage_record`  (
  `id` bigint NOT NULL COMMENT '文件记录ID（MyBatis-Plus雪花算法生成）',
  `scene` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '存储场景',
  `object_key` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '对象存储相对路径',
  `md5` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '文件物理MD5；上传占位时可为空或预期值，完成后为真实值',
  `size` bigint NULL DEFAULT 0 COMMENT '文件物理字节数',
  `provider_code` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '存储提供商配置编码',
  `status` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件状态：UPLOADING、AVAILABLE、DELETED',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_object_key`(`object_key` ASC) USING BTREE,
  INDEX `idx_md5_provider`(`md5` ASC, `provider_code` ASC) USING BTREE,
  INDEX `idx_status_create`(`status` ASC, `create_time` ASC) USING BTREE,
  INDEX `idx_status_update`(`status` ASC, `update_time` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '文件存储记录' ROW_FORMAT = DYNAMIC;

SET FOREIGN_KEY_CHECKS = 1;
