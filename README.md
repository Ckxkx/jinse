<p align="center"><img src="App/Assets.xcassets/AppIcon.appiconset/image.png" width="88" height="88" alt="锦瑟应用图标"></p>
<h1 align="center">锦瑟 · 我的时间线</h1>
<p align="center">锦瑟无端五十弦，一弦一柱思华年。</p>
<p align="center">用文字、照片和地点，记一本可以按月翻阅的生活手记。</p>
<p align="center"><a href="https://ckxkx.github.io/jinse/">打开网页版</a> · <a href="https://github.com/Ckxkx/jinse/actions/workflows/sidestore.yml">下载 iPhone 版</a> · <a href="https://github.com/Ckxkx/jinse/actions/workflows/sidestore.yml">构建 IPA</a></p>

## iPhone · 私人时间线 2.0

打开应用直接按时间倒序阅读。左侧显示时刻、日期和星期，右侧显示事件、状态、正文和媒体。点右下角加号记录，点状态标签直接更新；设置中可以恢复已删除的记录。全新安装从空白时间线开始。

| 操作 | 入口 |
| --- | --- |
| 写下或补记 | 右下角加号，填写标题或正文，选择日期、时刻、状态和附件 |
| 浏览媒体 | 单图或缩略图可点开，视频点按播放。编辑表单用上下箭头调整顺序 |
| 查找记录 | 顶部放大镜和状态筛选 |
| 备份与恢复 | 设置 → 导出完整备份（未加密）→ 存入文件或分享。导入时先校验，默认合并，替换前生成可恢复快照 |
| 加密同步 | 设置 → WebDAV 连接与加密口令 → 测试连接 → 保存配置 → 立即同步。自动同步在应用运行期间执行 |

**数据与隐私。** 旧版 SwiftData 记录和原始照片保留在设备上。首次转换时，应用写入完整快照并回读校验，再提交新版索引。旧版没有独立的创建和修改时间，迁移时使用原记录日期。新记录分别保存事件、创建和修改时间。

完整备份包含附件与删除状态，格式版本为 2。导出文件包含明文，请放在可信位置。HTTPS WebDAV 同步使用独立口令、随机盐、PBKDF2-HMAC-SHA256、HKDF 和 AES-GCM。网络分片上传完毕后才通过条件写入发布新清单。服务端需要支持强 ETag、If-Match、If-None-Match、GET、PUT、DELETE、PROPFIND 和 MKCOL。设置页列出同时修改的版本。账号材料通过设备钥匙串保存，备份不含这些材料。请妥善保存独立加密口令。

## 下载未签名 IPA

打开 [SideStore 工作流](https://github.com/Ckxkx/jinse/actions/workflows/sidestore.yml)，选择最近成功的运行，在 **Artifacts** 下载 `Timeline-2.0-运行编号-unsigned`。解压 ZIP 后得到 `Timeline-unsigned.ipa`。自用侧载可以在 SideStore 的 My Apps 中点加号选择该文件。

需要自行打包时，在同一工作流选择 **Run workflow → main**。GitHub 托管的 macOS runner 编译 iphoneos Release，打包后解压检查应用路径、Info.plist、标识符、版本、构建号和主程序的真机平台及执行权限。

[iPhone CI](https://github.com/Ckxkx/jinse/actions/workflows/ci.yml) 运行模拟器测试并上传 xcresult。网页版仍可通过 [GitHub Pages](https://huichen.dev/jinse/) 使用，浏览器数据独立存储。

## 许可

**暂不开源。** © 2026 Ckxkx，保留所有权利。本项目目前未授予开源许可。如需复用代码、美术资源或再分发，请事先取得权利人的书面许可。
