# 来源与许可证

本项目参考 znjhahaha/zhengfang-apk（正方教务助手）：

- 仓库：https://github.com/znjhahaha/zhengfang-apk
- 本次参考提交：`bbfa3d1803baa0a7be7015b43ec0fda719269519`
- 上游许可证：GNU GPL v3，见上游 LICENSE。
- 参考内容：课表/成绩/选课的页面组织、SchoolConfig.java 的接口路径与菜单代码、AcademicStudyReader.kt 的学期与分页参数、AcademicStudyParser.kt 的字段映射。
- iOS 端以 Swift/SwiftUI 独立实现，未包含安卓 APK、插件二进制、品牌图片、用户数据、凭据或上游签名校验机制。
- 原项目作者保有原有权利；本项目不是原作者发布的官方 iOS 版本。

与上游协议映射相关的改写及本项目新增实现均以 GPL-3.0-only 发布，许可全文见 LICENSE。仓库初始化时的 MIT 许可说明保留于 LICENSE.initial-MIT。

构建工具 XcodeGen 使用 MIT 许可证，GitHub Actions 工具由其各自仓库许可。它们仅用于构建，不作为 App 运行时依赖打包。
