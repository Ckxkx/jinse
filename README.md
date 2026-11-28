<p align="center"><img src="App/Assets.xcassets/AppIcon.appiconset/image.png" width="88" height="88" alt="锦瑟应用图标"></p>
<h1 align="center">锦瑟 · 我的时间线</h1>
<p align="center">锦瑟无端五十弦，一弦一柱思华年。</p>
<p align="center">用文字、照片和地点，记一本可以按月翻阅的生活手记。</p>
<p align="center"><a href="https://ckxkx.github.io/jinse/">打开网页版</a> · <a href="https://github.com/Ckxkx/jinse/actions/workflows/sidestore.yml">下载 iPhone 版</a> · <a href="https://github.com/Ckxkx/jinse/actions/workflows/sidestore.yml">构建 IPA</a></p>

## 翻阅手记

从十月的厦门海岸翻到杭州的周末咖啡馆。首次打开有两篇带原创插画的示例，你可以编辑或删除，再从自己的第一篇开始。

| 想做什么 | 怎样操作 |
| --- | --- |
| 留下片刻 | 从首页进入「我的时间线」，点右上角加号，写个标题即可保存。也可以附上正文、照片、地点和标签。 |
| 补记往事 | 保存前选好日期，时间线会翻到记录所在的月份。 |
| 找回一篇 | 按月份和标签筛选，或搜索标题、正文、地点。日历中的圆点表示当天有记录。 |
| 整理记录 | 打开详情后编辑、移除照片或删除整篇。删除需再次确认。 |

## 选择使用方式

| | 网页版 | iPhone 原生版 |
| --- | --- | --- |
| 入口 | [GitHub Pages](https://ckxkx.github.io/jinse/) | iOS 17 或更高版本，可用 SideStore 安装 |
| 存储 | 当前浏览器的 IndexedDB，首次加载并完成离线缓存后可断网使用 | SwiftData 数据库和应用私有照片目录 |
| 工程 | [gh-pages 分支](https://github.com/Ckxkx/jinse/tree/gh-pages)，原生 HTML、CSS、JavaScript | [main 分支](https://github.com/Ckxkx/jinse/tree/main)，SwiftUI、SwiftData、PhotosPicker |

两个版本都无需登录，记录和选取的照片只保存在当前设备。网页版与原生版各自保存手记。清除网站数据、结束无痕会话或卸载原生应用可能移除相应记录。

### 用 SideStore 安装

1. 在 iPhone 上登录 GitHub，打开页面顶部的 iPhone 下载入口，选择最近成功的运行，在 Artifacts 下载 Timeline-SideStore。
2. 在「文件」中轻点 ZIP 解压，得到 **Timeline-unsigned.ipa**。
3. 打开已配置好的 SideStore，进入 **My Apps → ＋**，选择 IPA 完成签名和安装。

如下载附件已过期，打开 [SideStore 构建工作流](https://github.com/Ckxkx/jinse/actions/workflows/sidestore.yml)，点击 **Run workflow**。完成后从运行摘要的 **Artifacts → Timeline-SideStore** 下载。此方式无需在仓库配置 Apple 签名材料。

## 构建与测试

[iPhone CI](https://github.com/Ckxkx/jinse/actions/workflows/ci.yml) 在推送到 main 和提交 Pull Request 时运行。macOS runner 选择已安装的 Xcode 26 和可用 iPhone 模拟器，验证新增、旧日期排序、编辑、删除、重开数据库，以及从首页新增记录的完整操作。运行摘要的 `simulator-results` 附件提供构建日志和测试结果。

<details>
<summary><strong>通过 TestFlight 分发 · 无 Mac 完整操作指南</strong></summary>

## 在 Windows 准备签名

1. 使用开启双重认证的 Apple 账号加入 [Apple Developer Program](https://developer.apple.com/programs/enroll/)，在开发者网站和 App Store Connect 接受待处理协议。在开发者账号 Membership details 记下 Team ID。
2. 打开 Certificates, Identifiers & Profiles → Identifiers → ＋ → App IDs → App。填写描述和自己的唯一 Explicit Bundle ID，例如 com.yourcompany.jinse。后续各页面使用同一标识符。
3. 在 Windows 安装包含 OpenSSL 的 Git for Windows。打开 Git Bash，在自己的私密目录运行下面命令。填写证书申请者姓名、邮箱等信息。第一条会让你为本地私钥设置密码。
   
   ~~~bash
   openssl genrsa -aes256 -out distribution.key 2048
   openssl req -new -key distribution.key -out distribution.csr
   ~~~

4. 在 Certificates → ＋ 选择 Apple Distribution，上传 distribution.csr，下载签发的 .cer 文件，改名为 distribution.cer，放回同一目录。在 Git Bash 执行以下命令。导出时设置非空的 .p12 密码并保管好。若 Apple 页面无法创建证书，请由 Account Holder 或 Admin 操作。

   ~~~bash
   openssl x509 -inform DER -in distribution.cer -out distribution.pem
   openssl pkcs12 -export -legacy -inkey distribution.key -in distribution.pem -out distribution.p12
   ~~~

   上述命令使用 OpenSSL 3。如果 Windows 安装提示 legacy provider 加载失败，检查 Git 自带 OpenSSL 的模块路径。私钥、.p12 和相关密码仅在本机私密保存。

5. Profiles → ＋ → Distribution → App Store Connect（部分页面显示 App Store）。选刚注册的 App ID 和上一步的 Apple Distribution 证书，命名并下载描述文件，改名 journal.mobileprovision。
6. 在 App Store Connect → Apps → ＋ → New App 选择 iOS，填 App 名称、主要语言、同一 Bundle ID 和自定唯一 SKU。记录属于持有签名证书的团队。
7. 需要上传时，在 App Store Connect → Users and Access → Integrations → App Store Connect API 启用 API，创建团队密钥并授予 App Manager 角色。记录 Issuer ID、Key ID，立即下载只能下载一次的 AuthKey_…p8。

## 配置 GitHub 仓库

打开 Settings → Secrets and variables → Actions。在 Secrets 页点 New repository secret，在 Variables 页点 New repository variable。把下面两条 PowerShell 命令分别在文件所在目录运行，每次执行后立即把剪贴板内容粘入对应 Secret。

~~~powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path .\distribution.p12))) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path .\journal.mobileprovision))) | Set-Clipboard
~~~

| 名称 | 位置 | 用途、来源及格式 |
|---|---|---|
| BUNDLE_ID | Variable | 签名与归档，步骤 2 注册的完整显式标识符 |
| TEAM_ID | Variable | 开发者会员页面的 10 字符团队 ID |
| DIST_P12 | Secret | 第一个 PowerShell 命令生成的单行 Base64，包含分发证书及其私钥 |
| P12_PASSWORD | Secret | 步骤 4 的 .p12 导出密码原文 |
| APP_PROFILE | Secret | 第二个命令生成的描述文件单行 Base64 |
| ASC_KEY_ID | Variable | 上传用，步骤 7 的团队 API Key ID |
| ASC_ISSUER_ID | Variable | 上传用，同一团队的 Issuer ID，UUID 格式 |
| ASC_PRIVATE_KEY | Secret | 上传用，用文本编辑器打开步骤 7 的 .p8，粘贴完整多行 PEM，包括 BEGIN 和 END 行 |

## 导出、上传与安装

1. Actions → 发布我的时间线 → Run workflow → main。选「仅导出 IPA」只需前五项配置。选「导出 IPA 并上传 TestFlight」需要全部八项。点绿色 Run workflow，打开该次运行查看各步骤。发布串行执行，每次归档根据 UTC 当前时间生成构建号。
2. 导出成功后，在运行摘要底部 Artifacts 点击 Timeline-IPA-… 下载 ZIP 并解压取得签名 IPA。上传失败也可以下载已经保存的产物。App Store 分发签名的 IPA 通过 TestFlight 安装。
3. **Actions 上传成功**表示 Apple 已接收上传。到 App Store Connect → Apps → 你的 App → TestFlight 查看构建号。**Apple 处理完成**后才可选用该构建；如提示出口合规或测试资料待填，请据实补全。处理失败时查看 Apple 发给账号的邮件。
4. **测试员可安装**需要将构建分配给群组。本人已有该 App 的 App Store Connect 访问权限时，在 TestFlight → Internal Testing 建组，添加本人并添加构建。其他用户可在 External Testing 建组，填测试说明、添加构建并按 Apple 要求提交 Beta App Review，获准后邀请邮箱。
5. iPhone 从 App Store 安装 TestFlight，打开邀请邮件点 View in TestFlight，接受并点「安装」。确认版本和构建号与发布运行一致。

</details>

## 许可

**暂不开源。** © 2026 Ckxkx，保留所有权利。本项目目前未授予开源许可。如需复用代码、美术资源或再分发，请事先取得权利人的书面许可。
