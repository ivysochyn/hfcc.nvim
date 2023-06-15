local config = require("hfcc.config")
local fn = vim.fn
local json = vim.json
local utils = require("hfcc.utils")

local M = {}

local function build_inputs(before, after)
  local fim = config.get().fim
  if fim.enabled then
    return fim.prefix .. before .. fim.suffix .. after .. fim.middle
  else
    return before
  end
end

local function extract_generation(data)
  local decoded_json = json.decode(data[1])
  if decoded_json == nil then
    vim.notify("[HFcc] error getting response from API", vim.log.levels.ERROR)
    return ""
  end
  if decoded_json.error ~= nil then
    vim.notify("[HFcc] " .. decoded_json.error, vim.log.levels.ERROR)
    return ""
  end
  local raw_generated_text = decoded_json.generated_text
  if raw_generated_text == nil then
    vim.notify("[HFcc] Empty generated text", vim.log.levels.ERROR)
    return ""
  end
  return raw_generated_text
end

local function get_url()
    return "http://127.0.0.1:5000"
end

local function create_payload(request)
  local params = config.get().query_params
  local request_body = {
    inputs = build_inputs(request.before, request.after),
    parameters = {
      max_new_tokens = params.max_new_tokens,
      temperature = params.temperature,
      do_sample = params.temperature > 0,
      top_p = params.top_p,
      stop = { params.stop_token },
    }
  }
  local f = assert(io.open("/tmp/inputs.json", "w"))
  f:write(json.encode(request_body))
  f:close()
end

M.fetch_suggestion = function(request, callback)
  local query =
      'curl "' .. get_url() .. '" \z
      -X POST \z
      -H "Content-type: application/json" \z
      -d@/tmp/inputs.json'
  create_payload(request)
  local row, col = utils.get_cursor_pos()
  return fn.jobstart(query, {
    on_stdout = function(jobid, data, event)
      if data[1] ~= "" then
        callback(extract_generation(data), row, col)
      end
    end,
  })
end
return M
