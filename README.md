# 订阅一下 iOS 版

一个 WKWebView 套壳的订阅管理器。界面是单文件 HTML，外层是 SwiftUI 容器。

数据存在 App 的 `Documents/data.json`，会进入 iCloud / iTunes 备份，**换 iPhone 整机迁移时自动带过去**。

---

## 部署到 GitHub（编译出 ipa）

### 1. 建仓库

登录 [github.com](https://github.com) → 右上角 `+` → **New repository**

- Repository name：随便，比如 `subnook-ios`
- 选 **Public**（Actions 免费无限时长；Private 只有 2000 分钟/月，macOS 还按 10 倍扣）
- 不要勾 README（已经有了）
- 点 **Create repository**

### 2. 传文件

在新建的仓库页面点 **uploading an existing file**，把**这个文件夹里的所有内容**拖进去：

```
project.yml
Sources/
Resources/
.github/
.gitignore
README.md
```

**注意**：`.github` 是隐藏文件夹，Windows 资源管理器默认看不见。上传时直接在地址栏粘贴路径进去选中。

或者用 GitHub Desktop（推荐，能传隐藏文件）。

### 3. 编译

推上去后，点仓库顶部 **Actions** 标签 → 左侧 **Build iOS** → 右侧 **Run workflow** → 绿色按钮。

等 8–10 分钟。

### 4. 下载 ipa

编译完成后，点进那次运行记录，页面底部 **Artifacts** → 下载 `Subnook-unsigned-ipa`。

解压得到 `Subnook-unsigned.ipa`。

---

## 安装到 iPhone

签名方式（选一个）：

- **AltStore / SideStore**：免费，7 天续签一次
- **TrollStore**：iOS 14.0–16.6.1 且支持的设备可永久安装，不用续签
- **企业签名**：花钱买，最省事

装好后打开 App，数据存在 App 自己的 Documents 里。

---

## 数据在哪

```
App 沙盒/Documents/data.json      主数据
App 沙盒/Documents/backup/        每天一份快照，保留 14 天
```

**怎么看到这些文件**：

- iPhone 上：用「文件」App → 我的 iPhone → 订阅一下
- 电脑上：Finder/iTunes → 设备 → 文件共享 → 订阅一下

（`Info.plist` 里开了 `UIFileSharingEnabled`，所以能看到）

---

## 换手机怎么迁

**整机迁移**（iCloud 备份恢复 / 电脑备份恢复）：自动带走，什么都不用做。

**只装 App**：把 `data.json` 从旧手机导出，新手机放进同样位置。

---

## 全部文件说明

| 文件 | 作用 |
|---|---|
| `project.yml` | xcodegen 配置，用来生成 `.xcodeproj` |
| `Sources/WebShell.swift` | SwiftUI 入口 + WKWebView 容器 |
| `Sources/Store.swift` | 读写 `Documents/data.json`，原子写入 + 每日备份 |
| `Sources/BootInjector.swift` | 页面加载前注入已存数据 |
| `Resources/www/index.html` | 应用本体（界面 + 逻辑全在这里） |
| `Resources/Assets.xcassets/` | App 图标 |
| `.github/workflows/build.yml` | 云端编译脚本 |

---

## 已知问题

- **没做过真机测试**。代码是按标准写法写的，但第一次编译大概率会有配置报错，需要看 Actions 日志调。
- **图标是临时做的**（紫色 + ¥），要换直接替换 `AppIcon.appiconset/icon-1024.png`（1024×1024，不要自己画圆角）。
- **App 名字**在 `project.yml` 里的 `CFBundleDisplayName`，现在是「订阅一下」。
