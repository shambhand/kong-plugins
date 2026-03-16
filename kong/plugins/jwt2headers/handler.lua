local jwt_parser = require "kong.plugins.jwt.jwt_parser"
local cjson = require "cjson"

local Jwt2Headers = {
    PRIORITY = 1998,
    VERSION = "0.0.1",
}

local function extract_token(header)
    if not header then
        return nil
    end
    local bearer_prefix = "Bearer "
    if header:sub(1, #bearer_prefix):lower() == bearer_prefix:lower() then
        return header:sub(#bearer_prefix + 1)
    else
        return header
    end
end

local function contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local function should_include_claim(claim_name, config)
    if contains(config.claims_to_exclude, claim_name) then
        return false
    end

    if contains(config.claims_to_include, "*") then
        return true
    end

    return contains(config.claims_to_include, claim_name)
end

local function get_header_name(claim_name, config)
    if config.custom_headers[claim_name] then
        return config.custom_headers[claim_name]
    end

    return string.format("%s%s", config.header_prefix, string.lower(claim_name))
end

local function stringify_value(value)
    if type(value) == "table" then
        return cjson.encode(value)
    end
    return tostring(value)
end

function Jwt2Headers:access(conf)
    local auth_header = kong.request.get_header("Authorization")
    local token = extract_token(auth_header)
    if not auth_header or not token then
        return kong.response.exit(401, { message = "Missing or Invalid Authorization header" })
    end

    local jwt, err = jwt_parser:new(token)
    if err then
        kong.log.err("Failed to parse JWT: ", err)
        return kong.response.exit(401, { message = "Invalid JWT token" })
    end

    local claims = jwt.claims

    for claim_name, claim_value in pairs(claims) do
        if should_include_claim(claim_name, conf) then
            local header_name = get_header_name(claim_name, conf)
            local header_value = stringify_value(claim_value)
            kong.service.request.set_header(header_name, header_value)
        end
    end
end

return Jwt2Headers
