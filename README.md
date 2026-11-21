# 生活提醒

一个给自己用的 iOS 提醒 App：随口记下想法，DeepSeek V4.1 Flash 自动拆成带时间的任务，阿里云百炼 Qwen-Audio-ASR 把语音转成文字，到点弹本地通知。

## 功能

- **今日**：下一件事环形倒计时、待办/逾期/完成/想法四宫格、纪念日横滑卡片、今日清单
- **任务**：进行中 / 今天 / 已完成 / 全部筛选，按逾期、今天、明天、以后分组，左滑删除
- **记录**：文字或按住说话 → 阿里云百炼异步转写 → DeepSeek 生成任务草稿 → 逐个加入
- **纪念日**：过去日期显示「已经 N 天」，未来日期显示倒计时，轻点翻面查看 / 删除
- **提醒**：本地通知，提前 0/5/10/15/30/60 分钟可调
- **设置**：App 内填写 DeepSeek Key、百炼 API Key、模型、可选业务空间 ID；深色模式、触感反馈开关

## 模型

- 文本：`deepseek-flash`（DeepSeek V4.1 Flash）
- 语音：`qwen-audio-3.1-asr-flash-filetrans`（DashScope 异步文件转写）

语音流程：录音（16k 单声道 WAV）→ 百炼临时存储上传凭证 → OSS 上传 → 提交异步转写任务 → 轮询 → 下载转写结果。

## 安装

GitHub Actions 在 `macos-15` 上自动构建未签名 IPA，Release 里下载后用 TrollStore 安装。最低支持 iOS 15.0，仅 iPhone 竖屏。

## 说明

- 所有数据保存在本机 Application Support，没有账号与云同步
- Key 保存在 UserDefaults，只留在本机
- 百炼临时文件 URL 有效期 48 小时，仅用于当次转写
