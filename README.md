# 源社区

源论坛 Android 客户端。使用 Kotlin、Jetpack Compose 和 Material 3。应用包名为 `ycoo.net.php`，当前版本为 `2.0.0+83`。

## 开发与打包

将根目录作为 Gradle 工程导入 Android Studio。配置 JDK 17、Android SDK 和本机正式签名配置 `key.properties`。签名配置中的 `storeFile` 相对于项目根目录，密钥和本机配置均由 Git 忽略。

在项目根目录运行以下 PowerShell 命令。

```powershell
.\gradlew.bat :app:testReleaseUnitTest :app:assembleRelease
.\tool\check_release.ps1
```

正式构建只打包 arm64-v8a，输出位于 `app/build/outputs/apk/release/`。应用内第三方许可随安装包提供。

开发和发布约定见 [DEVELOPMENT.md](DEVELOPMENT.md)。
