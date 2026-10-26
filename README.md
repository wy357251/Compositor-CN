# Compositor-CN

Compositor 的简体中文分支。上游是 [robbietilton/Compositor](https://github.com/robbietilton/Compositor)——一款面向 Mac 的免费开源图像编辑器，自称 "The Photoshop alternative for Mac"。本仓库在它的基础上加入简体中文界面，内容跟随上游 **v1.5.9**。

Adobe Photoshop 太贵，而 GIMP 之类的工具又不够顺手，难以让人保持专注——这是原作者 Robbie Tilton 做 Compositor 的原因。目标是做一个功能完整、完全免费开源的图像编辑器：他过去用 Photoshop 做合成与后期，所以 Compositor 围绕那套工作流设计，提供产出像素级成图所需的工具。因为开源，你可以直接拿到 Xcode 工程，按需添加、移除或修改任何功能。

## 安装

### 从源码构建（本仓库）

```sh
git clone git@github.com:wy357251/Compositor-CN.git
open Compositor.xcodeproj    # 运行 Compositor scheme
```

命令行构建：

```sh
xcodebuild -project Compositor.xcodeproj -scheme Compositor \
  -destination 'platform=macOS,arch=arm64' -configuration Release build
```

本仓库不提供签名公证过的安装包（那需要付费的苹果开发者账号），但可以从源码自行打包一个未签名 DMG，见下文[打包与分发](#打包与分发)。

想要开箱即用的版本，也可以装上游发行版：[robbietilton.com/compositor](https://robbietilton.com/compositor)，或 Homebrew：

```sh
brew install --cask robbietilton-compositor
```

上游发行版不含这里的中文界面。

## 中文界面

界面语言跟随系统的 preferred languages：当简体中文排在首位时，构建出的 App 自动以中文显示，无需任何设置。想单独为这个 App 指定语言：

```sh
defaults write com.wy357251.compositor AppleLanguages -array zh-Hans
```

译文存放在 `Compositor/Localizable.xcstrings`（Xcode String Catalog，947 个键），工程在 `knownRegions` 里注册了 `"zh-Hans"`。绝大部分界面靠 SwiftUI 的 `LocalizedStringKey` 自动生效，不需要改代码；只有少数地方加了改动，见下。

覆盖范围目前是这样的：

- **已中文化**：菜单栏与全部命令（含「滤镜」子菜单、「新建调整图层」子菜单）、编辑菜单里的撤销 / 重做动作名、图层面板的右键命令与效果行、各处下拉框的取值（单位、形状、抖动样式、镜头效果、散景形状、Camera Raw 分区等）、命令面板（⌘F）、工具属性栏、调整与滤镜面板的参数名与其 tooltip、画布大小的锚点（左上 / 居中…）与动态行数、图像大小对话框、导出对话框、参考线、**全部 11 个错误类型的提示文字**（工程损坏、导入导出失败、选区过于复杂等），以及大部分 tooltip 与 VoiceOver 标签。
- **无需翻译**：裁切比例（`1:1`、`4:3`、`16:9`）、色彩缩写（`RGB`、`HSL`）与只含数字单位的动态文案（`1,200 × 800 px`、`150%`、`40 ms · 25 fps`），两种语言写法相同。
- **故意保持英文**：图层的默认名（`Layer 1`、形状与滤镜产生的图层名）。这些会被写进 `.comp` 工程文件，属于文档内容而不是界面文字，本地化会让分支的工程与上游不一致。

有四类文字不是 SwiftUI 字面量，得靠代码改动接上目录：

1. **枚举名当标题用**。菜单与撤销标题原先显示枚举的 `rawValue`（`Gaussian Blur`、`Add Noise` 等），而 `AdjustmentKind` 的 `rawValue` 同时是写进工程文件的存档键，不能改。所以给 `FilterKind`、`AdjustmentKind`、`LayerEffectKind` 各加了一层只用于显示的 `displayName`，`rawValue` 原样保留。
2. **AppKit 构造的菜单**。图层面板右键菜单用 `NSMenuItem(title:)`，它收的是普通 `String`，不会自动查表，所以在构造处显式走 `localizedString(_:)`。
3. **撤销标题**。在 `EditorSession.beginEdit` 里统一查一次表，各处传入的英文动作名因此自动跟随界面语言；由名称拼出的标题（`Add %@`、`Edit %@ Adjustment`）走 `localized(_:_:)`。
4. **AppKit 的 tooltip 与 VoiceOver 标签**。`NSToolbar`/`NSButton` 的 `toolTip = "…"` 和 `setAccessibilityLabel("…")` 收的都是普通 `String`，SwiftUI 那套自动机制完全管不到，所以在赋值处走 `localizedString(_:)`。

还有第五类最容易漏：**面板自己的 helper 用 `String` 形参收英文字面量**。滤镜与 Camera Raw 面板把参数名和 tooltip 写成 `slider("Exposure", …, help: "Brightens…")`，`CanvasSizeSheet` 把九个锚点写进一个数组，渲染时都是 `Text(变量)` / `.help(变量)`——同一条 SwiftUI 规则，变量不查表，于是整片滑块标签在中文界面下仍是英文。这类只在 helper 内部改：进函数先 `let (title, help) = (localizedString(title), localizedString(help))`，函数体一行不动，200 多个调用点也不用动。`CameraRawSlider` 收到的 `help` 则在 `makeNSView` 里查表，因为那里直接写进 `toolTip`。少数例外保持原样：`LevelsSheet.field(name:)` 与 `NewCanvasSheet.dimension(title:)` 的名称同时用作无障碍标识符和比较条件，只在显示的两处查表；`X`、`Y`、`R`、`G`、`B`、`°`、`px` 这类符号两种语言写法相同，不入库。

带参数的文案统一用 `localized("Current: %@ × %@ pixels", 宽, 高)`：键写死在源码里，因此可以逐条断言解析结果，不依赖 Xcode 的自动抽取（命令行构建不会抽取，只有 GUI 里构建或手动执行 Extract 才会）。两个约定：占位符一律用 `%@`，`localized` 会把参数转成 `NSString`，因为把 `Int` 直接交给 `%@` 会崩溃；译文里若出现字面的百分号，必须写成 `%%`，否则会被当成格式说明符吃掉。

菜单里的 `Undo ` / `Redo ` 前缀用 `Text("Undo ") + Text(name)` 拼接，而不是字符串插值：SwiftUI 为插值生成的目录键格式无法在不开界面的情况下确认，猜错就是静默不生效，而拼接的两半都是确定的字面量键。

相应地，测试里对菜单标题与撤销名的断言写成 `localizedString("…")`，只关心动作身份、不依赖界面语言。

`CompositorTests/LocalizationTests.swift` 守住这两条规则本身：它读构建产物里编译好的 `en.lproj` / `zh-Hans.lproj` 表，要求每个含 `%@` 的键的译文占位符与键一一对应（非格式键不许凭空造出 `%@`），并把每个格式译文按 `localized` 的方式填一遍；再把画布大小、图像大小、新建、导出（逐个格式）、全部滤镜面板、逐个图层样式与调整面板真的塞进 `NSHostingView` 走一次布局。加这两层是因为曾经有两类缺陷在 818 个测试全绿、构建也通过的情况下漏过：译文里未转义的 `%` 被当成格式说明符吃掉，以及把 `Int` 直接交给 `%@` 让对话框一打开就崩溃。测试里另有一条反向对照（`theConversionCheckIsNotBlind`），确认占位符检查真的能抓到这两种写法。

在 Xcode 里打开 `Localizable.xcstrings` 会自动抽取代码里尚未登记的键，补录的条目以「未翻译」状态出现，填上译文即可生效。

术语对齐 Adobe Photoshop 简体中文版：`Drop Shadow` → 投影、`Content-Aware Fill` → 内容识别填充、`Copy Merged` → 合并拷贝、`Proof Colors` → 校样颜色、`Gamut Warning` → 色域警告。`Save` 译作「存储」而非 macOS 的「保存」，因为整个应用的交互都在模仿 Photoshop。

## 功能

### 图层

- 图层与图层组，支持不透明度与 Photoshop 的全部混合模式及其排列顺序——组的透明度会压暗组内一切
- 图层蒙版：可在画布任意位置（超出图层自身像素范围）绘制、填充、反相、模糊和羽化；可链接或取消链接，让蒙版独立变换
- 剪贴蒙版与组蒙版
- 调整图层：色相/饱和度、色阶、曲线、曝光、渐变映射、颗粒、黑白、色彩平衡、反相，以及可作为图层的滤镜：高斯模糊、动感模糊、渐进模糊、噪声、晕影、泛光 / 发光、RGB 分离、镜头效果与色调对比
- 图层效果：描边、投影、颜色叠加、内阴影、外发光、内发光，在 GPU 上渲染，随时可编辑
- 向下合并、合并图层与合并组（⌘E）
- 复制、就地重命名、拖拽排序与嵌套；Option 拖拽复制；图层面板有右键菜单
- 拷贝与粘贴整个图层或组（无选区时的 ⌘C/⌘V），可在同一文档或不同文档之间，也可以跨文档拖拽

### 变换

- 非破坏性的移动、缩放、旋转与翻转——无论把图像缩到多小，都保留原始分辨率
- 自由扭曲（⌘ 拖拽控制点），按住 Shift 可锁定到某一轴
- 同时变换多个图层或整个组
- 吸附到画布与图层的边缘、中心，并显示对齐参考线
- 精确输入位置、尺寸、缩放与角度，可用方向键逐步调整
- 翻转图层与翻转画布，均支持水平与垂直

### 选区

- 矩形与椭圆选框、自由绘制与多边形套索，以及 Magic 工具——魔棒按颜色选取，对象工具则追踪你点击的内容（Tab 切换）
- 选取主体，以及对任意选区的扩展、收缩与羽化
- 添加到选区、从选区减去、移动轮廓，或移动并复制选区内的像素
- 把图层的像素或蒙版载入选区
- 内容识别填充，还能把图像向画布之外延展

### 绘制与修图

- 画笔工具：可调大小、硬度、不透明度与平滑度，分绘制与擦除两种模式（B 与 E），Shift 画直线
- 数位板压感控制画笔的大小与不透明度
- 修复画笔（内容识别）
- 仿制图章，对齐或不对齐，可取样单个图层或全部图层
- 模糊工具，可用于像素或蒙版
- 渐变工具与形状工具（矩形、圆角矩形、椭圆和直线），保持可编辑而不会被栅格化
- 文字工具（T）：可在可拖拽、可调整大小的段落框内直接进行多行编辑；字体、字号、颜色、对齐与间距都在工具属性栏；文字可变换，也可作为剪贴蒙版
- 吸管与完整的取色器

### 调整与滤镜

- Camera Raw 滤镜：光影、颜色、曲线、混色器、颜色分级、细节、光学与几何，面板位于画布旁；每个分区都能从自己的标题栏复位为默认值
- 色阶（含自动色阶）、曲线、色相/饱和度、曝光、渐变映射、颗粒、黑白、色彩平衡与反相
- 高斯模糊与动感模糊，都能向外扩散到图层边缘之外
- 添加噪声、晕影、泛光 / 发光、抖动、扫描线、RGB 分离、镜头效果（变形镜头耀斑、星芒、雾化、棱镜，以及圆形 / 六边形 / 椭圆 / 猫眼光斑）、色调对比、镜头校正与移除背景
- 实时预览；若有选区则只作用于选区
- 再次滤镜（⌃F）：用同样的设置再跑一遍上一个滤镜

### 画布与文件

- 多标签页打开多个项目
- 搜索命令（⌘F）：像 Raycast 或 Obsidian 那样按名字找到每条菜单命令与工具，按 Return 执行
- 切换全屏（F）：画布单独铺满整块黑屏，所有面板收起；再按 F 或 Esc 恢复
- 标尺（⌘R）、从标尺拖出参考线、可调整间隔与细分的布局网格，以及可对齐到参考线、网格、图层和文档边界
- 裁剪带吸附，支持 3:4、9:16 等比例，Option 可对称裁剪；有选区时裁剪框从选区开始
- 画布大小、图像大小与裁边
- 窗口高度不够时，工具栏自动排成两列
- 导航器缩略图：300% 缩放起出现在画布角落，整体缩小显示文档并用方框标出当前视野，点击或拖动即可跳转（视图 › 导航器）
- 缩小查看时清晰的高质量降采样，放大查看时显示像素网格
- 导入 JPEG、PNG、HEIC、TIFF、WebP、SVG、PDF（每一页各自成一个图层，按 300 DPI 或适配画布）、动画 GIF（一个图层，其帧显示在画布下方的条带里，可播放、绘制、复制、删除与改时长）、相机 RAW（先经过一步原始图像处理）以及 Photoshop 的 PSD 与 PSB（8 位 RGB；不支持 CMYK）。每个 Photoshop 画板各自开一个标签页；图层组、蒙版、混合模式、填充矩形/椭圆和简单的横排文字保持可编辑；其他矢量与竖排文字转为像素。应用之前会先显示一份转换报告
- 大文档：内存预算随你的 Mac 容量调整；大到无法打开的 Photoshop 文件会把图层裁切到画布范围
- 导出 PNG（⇧⌘E）、导出 JPEG（⇧⌥⌘S），以及「导出为」（⇧⌥⌘W）支持 PNG、JPEG、按打印尺寸的单页 PDF，或在有 GIF 图层时导出动画 GIF，可缩放，带实时预览、JPEG 品质与目标体积；「导出为」里的通道包会把图层打包进 PNG 的红绿蓝与 Alpha 通道，用于游戏贴图，而 RGB 分离的「拆分到图层」能把图层还原成那四个；合并拷贝
- 项目保存的同时可以继续工作
- 通篇采用 Photoshop 风格快捷键，可在「编辑 › 键盘快捷键」中自定义
- 像 Photoshop 那样拖动数字标签来擦取其值
- 自动更新（由原作者签名并公证；本分支的构建不接收上游更新，见下文）

### 可与 AI 代理协作

- AI 代理和脚本可以直接创建、编辑项目：`.comp` 就是一个装着 PNG 图层和一份清单文件的文件夹，而打开中的项目会随写入实时更新。参见[编写 Compositor 项目](docs/writing-comp-files.md)

## 系统要求

- macOS 26.0 或更高，Apple silicon 的 Mac
- Xcode 26 或更高（从源码构建时）

## 打包与分发

### 未签名包（本仓库目前的做法）

```sh
./scripts/package-unsigned.sh      # → dist/Compositor-<version>-unsigned.dmg
```

Release 构建 + ad-hoc 签名 + `hdiutil` 造盘：不需要任何苹果账号，也不依赖 `create-dmg`（后者靠 Finder/AppleScript 排图标，在无头环境里不稳）。脚本还会断言 `zh-Hans.lproj` 确实进了包，并且主程序不带 hardened runtime——中文丢失或带着该标志都会发出一个能装但坏掉的 DMG，是很难察觉的回归。

**接收方必须知道的一件事**：浏览器下载的文件会被打上 quarantine 属性，而这个包没有 Developer ID 签名、也没经过苹果公证，Gatekeeper 会拦住。装好后执行一次：

```sh
xattr -dr com.apple.quarantine "/Applications/Compositor.app"
```

或在 系统设置 › 隐私与安全性 里点「仍要打开」，也可以在 Finder 里右键 App → 「打开」。在放 DMG 链接的地方务必写上这句提示，否则多数人以为下载的文件坏了。

发布交给 Actions：推一个 `v<版本>-CN` 的**附注标签**，`.github/workflows/release.yml` 就在 macos-26 上跑 `package-unsigned.sh`，把 DMG 挂起来核对编译后的 `zh-Hans.lproj/Localizable.strings` 条目与 `Localizable.xcstrings` 登记的键一一对应（源码是 JSON、发出去的是编译表，漏了哪个键不会有任何症状），然后用 `GITHUB_TOKEN` 建 Release 并上传。Release 正文取标签的注释，所以文案跟标签一起提交、不需要谁的 token：

```sh
git tag -a -F /tmp/release-notes.md v1.5.9-CN && git push origin v1.5.9-CN
```

### 签名与公证

`scripts/release.sh` 是完整链路：archive → Developer ID 签名 → 公证并装订 → 打包成 `dist/Compositor-<version>.dmg`。它需要以下材料，且都不存放在仓库里：

- 登录钥匙串中的一张 **Developer ID Application** 证书
- 用 `xcrun notarytool store-credentials "compositor-notary" …` 保存的公证凭据
- [`create-dmg`](https://github.com/create-dmg/create-dmg)（`brew install create-dmg`）

脚本里的 `TEAM`、`IDENTITY`、`NOTARY_PROFILE` 仍是原作者的值，换成你自己的 Apple Developer Program 账号（付费 $99/年）后改用它，才能产出双击即装的包。`scripts/publish.sh` 的发布目标已指向本仓库（可用 `REPO=owner/name` 覆盖）。

### 自动更新

本分支不接收上游更新：`SUFeedURL` 指向本仓库，而仓库里的 `appcast.xml` 是一个空的 feed，`SUEnableAutomaticChecks` 也已关闭。若沿用上游的订阅地址与公钥，中文构建会在后台把上游英文版当成合法更新装上，界面被悄悄替换。菜单里的「检查更新…」会报「已是最新版本」。

将来若要建立自己的更新通道，需要生成自己的 EdDSA 密钥对、替换 `SUPublicEDKey`，并用 `scripts/publish.sh` 发布签名后的包。

## 关于上游不接受翻译贡献

上游 README 的 Translations 一节写明：Compositor 目前只有英文，**不接受翻译 PR**，因为项目由一人维护，每个新字符串此后都要持续翻译，而作者无法审阅自己不懂的语言。因此本仓库的中文界面只能以独立分支的形式维护——这也是它把改动尽量集中在一个 String Catalog、并让测试不依赖界面语言的原因。

## 许可

MIT — 见 [LICENSE](LICENSE)。上游版权归 Robbie Tilton 所有；本仓库的中文界面改动同样以 MIT 授权。
