# 清爽助手（iOS 17.0 / TrollStore）

这是一个安全优先的 iOS 清理工具原型，使用 SwiftUI 编写，目标设备为 iOS 17.0，Windows 用户通过 GitHub Actions 的 macOS runner 云端编译。

## 重要限制
- iOS 沙盒默认不允许一个 App 删除其他 App 私有容器中的缓存。
- TrollStore 安装本身不等于自动获得所有文件系统权限。
- 本版本只扫描/清理本 App 自己的 `Caches` 和 `tmp`，并检查本 App 可访问范围内的诊断文件。它不会假装能清理整个 iOS 系统，也不会删除其他 App 数据。
- 不请求私有系统 entitlement，不遍历/删除未知系统目录，不清理照片、聊天记录、数据库或钥匙串。
- 当前版本是可编译的安全原型。若要扩展到设备级目录，需要针对 iOS 17.0 + TrollStore 实测权限后再添加白名单路径。

## 云端编译（Windows）
1. 在 GitHub 登录/注册账号。
2. 新建一个 **Private** 仓库，例如 `ios-safe-cleaner`。
3. 将本项目文件上传到仓库根目录（保留 `.github/workflows/build.yml`）。
4. 打开仓库的 **Actions** 页面，允许运行 Actions。
5. 点击 `Build IPA` 工作流，再点 `Run workflow`。
6. 完成后打开该次运行页面底部的 **Artifacts**，下载 `QingShuang-iOS17-IPA`。
7. 解压后取得 `QingShuang.ipa`，传到 iPhone，用 TrollStore 打开安装。

## 安装说明
IPA 为供 TrollStore 使用的未签名打包产物，不是 App Store / 普通侧载签名包。请只安装自己构建、来源可信的文件。

## 当前功能
- 显示本 App 缓存、临时目录的扫描结果
- 逐项勾选后清理本 App 缓存和临时文件
- 显示实际删除数量和释放空间
- 只扫描有限且明确的本 App 目录
