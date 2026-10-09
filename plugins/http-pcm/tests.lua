-- Run with WeaveText's marketcheck example; real JSON/base64 APIs, mocked IO.
local sdk = host
local values, sent, events = {}, {}, {}
host = {
  config = { get = function(key) return values[key] end },
  json = sdk.json, crypto = sdk.crypto,
  asr = {
    emitFinal = function(text) events[#events+1] = {kind="final",text=text} end,
    emitError = function(text) events[#events+1] = {kind="error",text=text} end,
    emitEnd = function() events[#events+1] = {kind="end"} end,
  },
  http = { request = function(method,url,headers,body,timeout)
    sent[#sent+1] = {method=method,url=url,headers=headers,body=body,timeout=timeout}
    return {ok=true,body=sdk.json.encode({text="测试结果"})}
  end }
}
local plugin = (function()
__PLUGIN_SOURCE__
end)()
return {run = function()
  assert(not plugin.isConfigured())
  assert(plugin.start()==false)
  assert(#sent==0 and events[#events].kind=="end")
  values.endpoint, values.language = "https://speech.example.test/transcribe", "zh-CN"
  events = {}
  assert(plugin.start())
  plugin.processAudioChunk("\0\1\2\3")
  plugin.stop()
  assert(#sent==1 and events[1].text=="测试结果" and events[2].kind=="end")
  local payload=sdk.json.decode(sent[1].body)
  assert(sdk.crypto.base64Decode(payload.audio)=="\0\1\2\3")
  assert(payload.sample_rate==16000 and payload.channels==1 and payload.encoding=="pcm_s16le")
  assert(sent[1].headers.Authorization==nil)
  plugin.start();plugin.processAudioChunk("x");plugin.cancel();plugin.stop()
  assert(#sent==1)
  events={};plugin.start();plugin.processAudioChunk(string.rep("x",32000*60+1));plugin.stop()
  assert(#sent==1 and events[1].kind=="error" and events[2].kind=="end")
  values.token="test-token";plugin.start();plugin.processAudioChunk("ab");plugin.stop()
  assert(sent[2].headers.Authorization=="Bearer test-token")
  assert(sent[2].timeout==30000)
  return {ok=true,checks=6}
end}
