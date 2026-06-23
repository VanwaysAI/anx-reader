# Anx Reader - 项目说明

## 项目信息

- **仓库**: https://github.com/VanwaysAI/anx-reader (fork from Anxcye/anx-reader)
- **类型**: Flutter 电子书阅读器
- **默认分支**: `develop` ⚠️ 不是 main！

## ⚠️ 重要：分支说明

这个项目的**默认分支是 `develop`**，不是 `main`。

- `origin/HEAD -> origin/develop`
- GitHub Actions 的 `workflow_dispatch` 只会在默认分支上显示
- 推送代码到 GitHub 时，记得推到 `develop` 分支

## MiMo TTS 修改

已添加小米 MiMo TTS 后端支持：

### 修改的文件

| 文件 | 说明 |
|------|------|
| `lib/service/tts/mimo_tts_backend.dart` | 新增 MiMo TTS 服务提供者 |
| `lib/service/tts/tts_service.dart` | 注册 MiMo 到 TTS 服务枚举 |

### 技术说明

小米 MiMo TTS 不是标准 OpenAI TTS 格式：

- **端点**: `/v1/chat/completions` (不是 `/v1/audio/speech`)
- **请求格式**: 需要 `assistant` role 的 messages
- **返回格式**: JSON 响应（可能包含 base64 音频）

```json
{
  "model": "mimo-v2.5-tts",
  "messages": [
    {"role": "user", "content": "朗读指令"},
    {"role": "assistant", "content": "要朗读的文本"}
  ]
}
```

### 配置

在 Anx Reader TTS 设置中选择 "MiMo TTS"：

- **URL**: `https://token-plan-cn.xiaomimimo.com/v1/chat/completions`
- **API Key**: 你的 MiMo API Key
- **Model**: `mimo-v2.5-tts`

## GitHub Actions

已添加手动触发的 Android 编译 workflow：

- **文件**: `.github/workflows/build-apk-manual.yaml`
- **触发方式**: workflow_dispatch (手动触发)
- **分支**: develop (默认分支)

### 使用方法

1. 访问 https://github.com/VanwaysAI/anx-reader/actions
2. 点击 "Build Android APK"
3. 点击 "Run workflow"
4. 选择 `develop` 分支
5. 等待编译完成，下载 APK

## 编译环境

### 本地编译

需要安装：
- Flutter SDK (`brew install --cask flutter`)
- Android SDK
- Java 17

```bash
flutter pub get
flutter gen-l10n
flutter build apk --release
```

### GitHub Actions 编译

无需本地环境，直接在 GitHub 上触发即可。

## 常见问题

### Q: 为什么看不到 GitHub Actions workflow？

A: 确认你查看的是 `develop` 分支（默认分支），不是 `main`。`workflow_dispatch` 只在默认分支上显示。

### Q: MiMo TTS 报错怎么办？

A: 小米 TTS 的返回格式可能需要调试。查看错误信息，可能需要调整 `mimo_tts_backend.dart` 中的响应解析逻辑。

### Q: 如何更新上游代码？

A: 
```bash
git remote add upstream https://github.com/Anxcye/anx-reader.git
git fetch upstream
git merge upstream/develop
```

## 更新日志

### 2026-06-23 MiMo TTS 改进

1. **Voice 列表更新**：根据小米文档添加了预置音色
   - 中文：冰糖、茉莉、苏打、白桦
   - 英文：Mia、Chloe、Milo、Dean
   - 默认：mimo_default

2. **配置字段**：
   - Voice：预置音色选择
   - Instructions：语音风格指令（语速、情绪、音色等）

3. **请求格式修复**：
   - 使用 `audio.voice` 参数传递音色
   - user 消息用于风格控制
   - assistant 消息用于要朗读的文本

4. **UI 修复**：
   - 修复下拉菜单使用 `value` 而不是 `initialValue`
   - 解决切换 TTS 服务无响应的问题

### 2026-06-23 段落朗读模式

新增段落朗读模式，支持更自然的长文本朗读：

**配置选项：**
- **朗读模式**：逐句朗读（默认）/ 段落朗读
- **段落句子数**：2-10 句（默认 5 句）

**工作原理：**
1. 段落模式下，将多个句子合并成一个段落
2. 发送给 MiMo TTS API 获取完整段落音频
3. 播放时使用第一个句子的高亮位置
4. 更自然的语调，减少句子间的停顿

**使用方法：**
1. 在 TTS 设置中选择 "MiMo TTS"
2. 将 "朗读模式" 改为 "段落朗读"
3. 调整 "段落句子数"（推荐 3-5 句）
4. 开始朗读

**注意事项：**
- 段落模式仅支持 MiMo TTS
- 其他 TTS 服务仍使用逐句模式
- 段落太长可能影响响应速度
