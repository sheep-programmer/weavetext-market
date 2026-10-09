-- Independent adapter for WeaveText's documented speech API.
local plugin = {}
local chunks, size, active = {}, 0, false
local maximum = 32000 * 60

local function finishError(message)
    active, chunks, size = false, {}, 0
    host.asr.emitError(message)
    host.asr.emitEnd()
end

function plugin.isConfigured()
    local endpoint = host.config.get("endpoint") or ""
    return endpoint:match("^https://[^/%s]+/") ~= nil
end

function plugin.start()
    chunks, size, active = {}, 0, false
    if not plugin.isConfigured() then
        finishError("请先填写兼容的 HTTPS 识别接口")
        return false
    end
    active = true
    return true
end

function plugin.processAudioChunk(pcm)
    if not active then return end
    if size + #pcm > maximum then
        finishError("单次录音最多 60 秒，请分段输入")
        return
    end
    size = size + #pcm
    chunks[#chunks + 1] = pcm
end

function plugin.stop()
    if not active then return end
    active = false
    if size == 0 then
        chunks, size = {}, 0
        host.asr.emitEnd()
        return
    end
    local pcm = table.concat(chunks)
    chunks, size = {}, 0
    local headers = { ["Content-Type"] = "application/json" }
    local token = host.config.get("token") or ""
    if token ~= "" then headers["Authorization"] = "Bearer " .. token end
    local body = host.json.encode({
        audio = host.crypto.base64(pcm),
        encoding = "pcm_s16le", sample_rate = 16000, channels = 1,
        language = host.config.get("language") or "zh-CN"
    })
    local response = host.http.request("POST", host.config.get("endpoint"), headers, body, 30000)
    if not response or not response.ok then
        finishError("语音服务未完成识别，请检查接口或稍后重试")
        return
    end
    local decoded = host.json.decode(response.body or response.text or "")
    if type(decoded) ~= "table" or type(decoded.text) ~= "string" then
        finishError("接口响应应为包含 text 字符串的 JSON")
        return
    end
    if decoded.text ~= "" then host.asr.emitFinal(decoded.text) end
    host.asr.emitEnd()
end

function plugin.cancel()
    active, chunks, size = false, {}, 0
end

plugin.onUnload = plugin.cancel
return plugin
