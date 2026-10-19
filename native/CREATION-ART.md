# 历史水彩素材与当前阅读字体

> 2026-10-20：当前客户端已切换为用户交付的原生极简设计。下述水彩图片保留为历史素材，页面不再引用该背景；Sanju Poetry 字体继续用于生成句子的阅读。

使用内置 imagegen 工具生成的原创海底水彩背景，已复制进原生 App 的资源目录。没有使用电影截图、现有角色或原作素材。

- 图片：`Sanju/Assets.xcassets/CreationOcean.imageset/creation-ocean.png`
- 使用位置：`Sanju/CreationVisuals.swift` 的 `CreationOceanBackground`
- 页面布局与交互：`Sanju/CreationView.swift`
- 静态画面配合深色蒙层保证文字可读，不持续播放粒子或背景动画。

## 中文排版字体

标题与结果、句库的句子阅读使用随 App 打包的中文衬线字体 `Sanju/Fonts/SanjuPoetry-Regular.ttf`，约 10.1 MB，来自 [Google Fonts 的 Noto Serif SC](https://github.com/google/fonts/tree/main/ofl/notoserifsc) 的 400 字重裁剪版。它覆盖基本汉字、拉丁文字和常用标点；罕见字由系统字体回退显示。许可证为 [SIL OFL 1.1](https://github.com/google/fonts/blob/main/ofl/notoserifsc/OFL.txt)，完整许可文本一起打包在 `Sanju/Fonts/NotoSerifSC-OFL.txt`。裁剪字体已改名为 Sanju Poetry；可编辑输入仍使用系统字体。

原始字体 SHA-256：`050080d9255a86808f2945bffac582b31ef32bc36411ce29563b4961670c66f9`。用安装了 fonttools 的 Python 运行 `scripts/subset-poetry-font.py`，传入上游 `NotoSerifSC[wght].ttf` 即可重新生成。正常构建无需下载字体或安装裁剪工具。

## 三个页面的视觉分工

- 创作页与结果页沿用原创海底水彩，结果页用三种淡纸色卡片承载冷峻、浪漫、青春文案。
- 句库、收藏详情与版本历史采用浅纸色背景和淡水彩纹理，保留清晰的搜索、筛选和版本操作。
- 公共阅读组件、文风色和字体在 `Sanju/PoetryVisuals.swift`；页面行为仍由原有 AppStore 管理，没有变更句库数据格式。

## 生成提示词

```text
Use case: stylized-concept
Asset type: original portrait watercolor background illustration for a poetic iPhone writing app, 1024 x 1536 composition
Primary request: a dreamlike underwater watercolor anime painting, a luminous quiet sea made of flowing ink and water, evoking the emotional wonder of a hand-painted animated ocean. No characters.
Scene: deep turquoise and midnight teal ocean, diffuse turquoise sunlight filtering down from upper left; soft coral pink and apricot watercolor eddies and small luminous floating petals near the right edge and bottom. A graceful sweep of pigment like a sea current crosses the lower third. Delicate paper grain, wet-on-wet blooms, translucent layered gouache, painterly irregular edges, cinematic tender atmosphere.
Composition: full-bleed portrait; keep the upper left and central 60 percent calm, deep teal and low-detail for readable live interface text and controls over it; concentrate beautiful luminous coral/peach and mint details around the right edge and lower third. Sophisticated organic watercolor, rich but restrained. Not photorealistic, not a vector gradient.
Constraints: background artwork only; no user interface, no cards, no typography, no lettering, no logo, no watermark; original artwork with no existing film characters or scenes.
```
