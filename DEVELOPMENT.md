# 源社区开发说明

`main` 使用 Kotlin、Jetpack Compose 和 Material 3，Android 模块为 `app/`。Flutter 源码可在迁移前的 Git 提交 `7f71a61` 中查看。

## 发布

当前正式版本为 `2.0.3+86`。从下一版起，修复递增补丁版本，新增功能递增次版本，并持续增加 `versionCode`。同步 Gradle、README、安装包文件名和发布校验脚本中的版本信息。

按 [README](README.md) 运行 Release 主机测试和构建，使用 `tool/check_release.ps1` 校验包名、版本、签名、ABI 和对齐。正式安装包仅支持 arm64-v8a。签名配置、密钥、安装包及构建缓存保存在本机。

主机测试覆盖页面状态、滚动手势和解析逻辑。实际设备的交互表现及需要登录的站点操作需在设备上另行验证。
