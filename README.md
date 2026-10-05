# 校园助手 · iOS

以 [正方教务助手 Android 开源版](https://github.com/znjhahaha/zhengfang-apk) 为界面和协议参考的 iOS 初版。Windows 写代码，GitHub 标准 macOS runner 编译。**不是 APK 转换器，也不是已经完成全部安卓功能的移植。**

## 初版功能

- SwiftUI 原生课表（日视图、一周分列总览、周次筛选、详情）、成绩及学分加权 GPA。
- 演示模式明确标注，真实同步失败不会填入演示数据。
- 自定义 HTTPS 学校教务根地址、学年和学期。
- 在学校原有网页中登录、完成验证码，复用本次 App 运行的网页 Cookie。
- 新正方通用接口课表和分页成绩查询；全部成功后保存本机离线缓存。
- 在 App 中打开学校选课页面，由用户操作校方页面。
- 切换学校或学期清空旧缓存；退出清除数据；取消旧请求，防止跨学校结果覆盖。

**尚未实测用户学校。** 安卓支持某学校，不代表本初版已完成该学校 iOS 适配。旧正方、强智、金智、乘方、校园插件、自动抢课队列、后台定时、考试与日历导出、小组件、自动续登暂未迁移。特殊课表路由、非标准周次/节次返回格式会明确报错，不编造课程。

## 免费云端构建

仓库为公开仓库，工作流使用标准 `macos-15`，未启用付费 larger runner。每次推送 `main`、`feature/**`、`fix/**` 或版本标签，会运行：

1. Swift 核心单元测试；
2. XcodeGen 生成工程并编译 iOS 模拟器版；
3. 在 iPhone 模拟器启动四个页面并截图；
4. 编译真机 ARM64 应用，输出 `Campus-unsigned.ipa`。

GitHub → **Actions → iOS initial build → 成功运行 → Artifacts → Campus-unsigned-IPA**。下载并解压外层 ZIP，取得 IPA。Artifacts 保留 7 天以控制存储；源码和版本标签长期保留，可重新构建。

**该 IPA 未签名，不能直接点开安装。** 可在 Windows 使用官方 [Sideloadly](https://sideloadly.io/) 以自己的 Apple ID 重签安装。免费签名通常 7 天有效，需要续签；签名流程在本机完成，不要把 Apple ID 密码、教务密码或签名文件提交到 GitHub。本工作流不需要 Apple 证书。

## 使用

首次启动为演示模式。设置 → 填学校名称与教务根地址（如 `https://学校域名/jwglxt`，不要带票据、查询参数或具体 HTML 页面）→ 选择学期 → 保存 → 学校登录 → 在学校页面完成登录 → 登录后同步。

登录、统一认证、验证码依旧由学校网页处理。初版不读取密码，退出 App 后需重新登录；只缓存课表和成绩。学校仅支持 HTTP、证书异常、专属门户或校园内网时，不能保证接入；未降低 TLS 校验。

GPA 只使用学校返回的有效学分与绩点，不把“优秀”等成绩自行转换，不对重修记录作无依据的取舍。

## 开发与备份

- `main`：经云端验证的初版及后续合并版本。
- `v0.1.0`：首个验证通过的源码备份标签。
- 后续使用 `feature/<主题>` 或 `fix/<问题>` 分支，通过构建后合并。
- `App/`：原生界面、网页登录和会话管理。
- `Sources/CampusCore/`：学校地址、数据模型、正方解析、学期/周次逻辑。
- `Tests/`：可在云端 Mac 独立运行的协议测试。

在 Mac 或云端执行 `swift test`、`xcodegen generate`。Windows 不需要安装 Xcode。`project.yml` 为工程源文件，生成的 `.xcodeproj` 不提交。

## 授权与来源

参照与改写来源见 [THIRD_PARTY.md](THIRD_PARTY.md)。当前 iOS 实现按 GPL-3.0-only 提供；仓库创建时的 MIT 文本另行保存在 `LICENSE.initial-MIT`，不用于重新许可上游衍生内容。
