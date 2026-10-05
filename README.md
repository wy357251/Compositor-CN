# Compositor-CN

Compositor 的简体中文分支。上游是 [robbietilton/Compositor](https://github.com/robbietilton/Compositor)——一款面向 Mac 的免费开源 Photoshop 替代品；本仓库在它的基础上加入了简体中文界面，内容基于上游 v1.4.5（build 40）。

Adobe Photoshop 太贵，而 GIMP 之类的工具又不够顺手，难以让人保持专注——这就是作者 Robbie Tilton 做 Compositor 的原因。目标是做一个功能完整的图像编辑器：他过去用 Photoshop 做合成与后期，所以 Compositor 也围绕这套工作流来设计，提供产出像素级成图所需的工具。因为开源，你可以直接拿到 Xcode 工程，按需添加、移除或修改任何功能。

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

译文存放在 `Compositor/Localizable.xcstrings`（Xcode String Catalog，389 个键），工程只在 `knownRegions` 里多了一行 `"zh-Hans"`，**没有改动任何 Swift 调用点**——这样与上游 `main` 持续同步时几乎不产生冲突。

覆盖范围目前是这样的：

- **已中文化**：菜单栏与各命令、工具属性栏、调整/滤镜面板的文案、大部分 tooltip 与无障碍标签。
- **暂时仍是英文**：图层面板的右键菜单（由 AppKit 的 `NSMenuItem(title:)` 直接构造，不走 `LocalizedStringKey`）、约 30 处带插值的动态文案、9 个错误类型的提示文字（如工程损坏、导出失败的报错）、以及从变量取值而非字面量的文本。
- 在 Xcode 里打开 `Localizable.xcstrings` 会自动抽取代码里尚未登记的键，补录的条目会以「未翻译」状态出现，填上译文即可生效。

术语对齐 Adobe Photoshop 简体中文版：`Drop Shadow` → 投影、`Content-Aware Fill` → 内容识别填充、`Copy Merged` → 合并拷贝、`Visualize Range` → 可视化范围。`Save` 译作「存储」而非 macOS 的「保存」，因为整个应用的交互都在模仿 Photoshop。

## 功能

### 图层

- 图层与图层组，支持不透明度与 Photoshop 的全部混合模式及其排列顺序——组的透明度会压暗组内一切
- 图层蒙版：可在画布任意位置（超出图层自身像素范围）绘制、填充、反相、模糊和羽化；可链接或取消链接，让蒙版独立变换
- 剪贴蒙版与组蒙版
- 调整图层：色相/饱和度、色阶、曲线、曝光、渐变映射、颗粒、黑白、色彩平衡、反相、高斯模糊、动感模糊与噪声
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
- 添加到选区、从选区减去、移动轮廓，或移动/复制选区内的像素
- 把图层的像素或蒙版载入选区
- 内容识别填充，还能把图像向画布之外延展

### 绘制与修图

- 画笔工具：可调大小、硬度、不透明度与平滑度，分绘制与擦除两种模式（B 与 E），Shift 画直线
- 修复画笔（内容识别）
- 仿制图章，对齐或不对齐，可取样单个图层或全部图层
- 模糊工具，可用于像素或蒙版
- 渐变工具与形状工具（矩形、圆角矩形、椭圆和直线），保持可编辑而不会被栅格化
- 文字工具（T）：可在可拖拽、可调整大小的段落框内直接进行多行编辑；字体、字号、颜色、对齐与间距都在工具属性栏；文字可变换，也可作为剪贴蒙版
- 吸管与完整的取色器

### 调整与滤镜

- Camera Raw 滤镜：光影、颜色、曲线、混色器、颜色分级、细节、光学与几何，面板位于画布旁
- 色阶（含自动色阶）、曲线、色相/饱和度、曝光、渐变映射、颗粒、黑白、色彩平衡与反相
- 高斯模糊与动感模糊，都能向外扩散到图层边缘之外
- 添加噪声、晕影、泛光 / 发光、色调对比、镜头校正与移除背景
- 实时预览；若有选区则只作用于选区

### 画布与文件

- 多标签页打开多个项目
- 标尺（⌘R）、从标尺拖出参考线、可调整间隔与细分的布局网格，以及可对齐到参考线、网格、图层和文档边界
- 裁剪带吸附，支持 3:4、9:16 等比例，Option 可对称裁剪；有选区时裁剪框从选区开始
- 画布大小、图像大小与裁边
- 缩小查看时清晰的高质量降采样，放大查看时显示像素网格
- 导入 JPEG、PNG、HEIC、TIFF、SVG、相机 RAW（先经过一步原始图像处理）以及 Photoshop 的 PSD 与 PSB（8 位 RGB，不支持 CMYK）。Photoshop 的组、蒙版、混合模式、填充矩形/椭圆和简单的横排文字会保持可编辑；其他矢量与竖排文字会转为像素。应用之前会先显示一份转换报告
- 大文档：内存预算随你的 Mac 容量调整；大到无法打开的 Photoshop 文件会把图层裁切到画布范围
- 导出带实时预览的 JPEG（⇧⌥⌘S）、合并拷贝
- 项目保存的同时可以继续工作
- 通篇采用 Photoshop 风格快捷键，可在「编辑 › 键盘快捷键」中自定义
- 像 Photoshop 那样拖动数字标签来擦取其值
- 自动更新（由原作者签名并公证；本分支的构建目前仍订阅上游的更新源，见下文）

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

Release 构建 + ad-hoc 签名 + `hdiutil` 造盘：不需要任何苹果账号，也不依赖 `create-dmg`（后者靠 Finder/AppleScript 排图标，在无头环境里不稳）。脚本还会检查 `zh-Hans.lproj` 确实进了包——中文丢了却发出一个能用的 DMG，是很难察觉的回归。

**接收方必须知道的一件事**：浏览器下载的文件会被打上 quarantine 属性，而这个包没有 Developer ID 签名、也没经过苹果公证，Gatekeeper 会拦住。装好后执行一次：

```sh
xattr -dr com.apple.quarantine "/Applications/Compositor.app"
```

或在 Finder 里右键 App → 「打开」。在放 DMG 链接的地方务必写上这句提示，否则多数人以为下载的文件坏了。

### 签名与公证

`scripts/release.sh` 是完整链路：archive → Developer ID 签名 → 公证并装订 → 打包成 `dist/Compositor-<version>.dmg`。它需要以下材料，且都不存放在仓库里：

- 登录钥匙串中的一张 **Developer ID Application** 证书
- 用 `xcrun notarytool store-credentials "compositor-notary" …` 保存的公证凭据
- [`create-dmg`](https://github.com/create-dmg/create-dmg)（`brew install create-dmg`）

脚本里的 `TEAM`、`IDENTITY`、`NOTARY_PROFILE` 仍是原作者的值，换成你自己的 Apple Developer Program 账号（付费 $99/年）后改用它，才能产出双击即装的包。`scripts/publish.sh` 的发布目标已指向本仓库（可用 `REPO=owner/name` 覆盖）。

### 自动更新

本分支不检查更新：`SUEnableAutomaticChecks` 置为 false，启动时不再调用 `startUpdater()`，`SUFeedURL` 指向本仓库，而仓库里的 `appcast.xml` 是一个空的 feed。这样中文构建不会被静默替换成上游英文版。菜单里的「检查更新…」会报「已是最新版本」。

将来若要建立自己的更新通道，需要生成自己的 EdDSA 密钥对、替换 `SUPublicEDKey`，并用 `scripts/publish.sh` 发布签名后的包。

## 许可

MIT — 见 [LICENSE](LICENSE)。上游版权归 Robbie Tilton 所有；本仓库的中文界面改动同样以 MIT 授权。
