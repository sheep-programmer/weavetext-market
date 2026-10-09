# 通用 HTTP PCM 语音适配器

独立编写的织文 Lua 适配器。它不是识别模型，需要用户部署或选择兼容接口；在录音结束后上传，非流式识别。
音频只发送到用户明确配置的 HTTPS 地址，不写入文件、不记录原文、不包含服务密钥。单次录音上限 60 秒。

请求为 POST，`Content-Type: application/json`：

```json
{"audio":"base64 PCM bytes","encoding":"pcm_s16le","sample_rate":16000,"channels":1,"language":"zh-CN"}
```

服务返回成功状态及 `{"text":"识别结果"}`。令牌非空时发送 `Authorization: Bearer <token>`。
未知响应、空录音、配置缺失和超长录音都有明确结束行为。

源码位于 `main.lua`，宿主协议见仓库 `docs/plugin-host.md`。打包可在本目录执行：
`zip ../../http-pcm.zip manifest.yaml main.lua README.md`

协议测试用真实 JSON/base64 编解码、模拟网络和音频事件。在织文主仓库执行：
`cargo run --manifest-path core/Cargo.toml -p weave-plugin --example marketcheck -- <市场仓库目录>`
