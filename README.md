# 锦瑟 Jinse
锦瑟无端五十弦，一弦一柱思华年。
时间线 App。

## 我的时间线

适用于 iOS 17 及以上的 iPhone。首次打开显示 2026 年 10 月的两条记录，海岸和咖啡馆配图是随工程分发的原创插画。点月份切换时间，点加号记下标题即可保存。日历圆点表示当天有记录。照片保存在应用私有目录。卸载应用会移除本机数据。

## 在网页查看测试

打开仓库的 Actions → iPhone CI。推送到 main 和 Pull Request 会运行共享 Timeline scheme。展开选择设备步骤可看到 Xcode、系统和 iPhone 型号。测试包含新增、过去日期排序、修改、删除、重开数据库、删除后不再生成示例和从首页新增记录。运行摘要下的 simulator-results 包含构建日志及生成的 xcresult。

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
