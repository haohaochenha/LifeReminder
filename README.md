# 生活提醒

一个给自己用的 iOS 小提醒 App：随口记下想法，接入 DeepSeek 自动拆成带时间的任务，到点弹本地通知，支持按住说话（阿里云智能语音交互 · 一句话识别）。

## 功能

- 今日：下一件事倒计时、今日清单、完成进度
- 任务：逾期 / 今天 / 明天 / 以后 分组，滑动与长按编辑
- 记录：文字或按住说话 → AI 生成任务草稿 → 可编辑后一键加入
- 提醒：本地通知，可设置提前量（0/5/10/15/30/60 分钟）
- 设置：App 内填写 DeepSeek Key、阿里云 AppKey / Token 或 AccessKey，仅存本机

## 安装

GitHub Actions 在 `macos-15` 上自动构建未签名 IPA，Release 里下载后用 TrollStore 安装。

## 说明

- 最低支持 iOS 15.0，仅 iPhone 竖屏
- 语音识别走阿里云 NLS `nls-gateway-cn-shanghai`，16k 单声道 PCM
- 所有数据保存在本机 Application Support，没有账号与云同步
