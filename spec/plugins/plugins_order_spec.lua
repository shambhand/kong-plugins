require "spec.helpers"
local conf_loader = require "kong.conf_loader"
local meta = require "kong.meta"

local fmt = string.format

local PLUGIN_ORDERS = {
    ["2"] = {
        "pre-function",
        "zipkin",
        "bot-detection",
        "cors",
        'jwt2headers',
        "session",
        "acme",
        "jwt",
        "oauth2",
        "key-auth",
        "ldap-auth",
        "basic-auth",
        "hmac-auth",
        "grpc-gateway",
        "ip-restriction",
        "request-size-limiting",
        "acl",
        "circuit-breaker",
        "rate-limiting",
        "response-ratelimiting",
        "request-transformer",
        "response-transformer",
        "aws-lambda",
        "azure-functions",
        "proxy-cache",
        "prometheus",
        "http-log",
        "statsd",
        "datadog",
        "file-log",
        "udp-log",
        "tcp-log",
        "loggly",
        "syslog",
        "grpc-web",
        "request-termination",
        "correlation-id",
        "post-function"
    },
    ["3"] = {
        "pre-function",
        "zipkin",
        "bot-detection",
        "cors",
        'jwt2headers',
        "session",
        "acme",
        "jwt",
        "oauth2",
        "key-auth",
        "ldap-auth",
        "basic-auth",
        "hmac-auth",
        "grpc-gateway",
        "ip-restriction",
        "request-size-limiting",
        "acl",
        "circuit-breaker",
        "rate-limiting",
        "response-ratelimiting",
        "request-transformer",
        "response-transformer",
        "ai-request-transformer",
        "ai-prompt-template",
        "ai-prompt-decorator",
        "ai-prompt-guard",
        "ai-proxy",
        "ai-response-transformer",
        "standard-webhooks",
        "aws-lambda",
        "azure-functions",
        "proxy-cache",
        "opentelemetry",
        "prometheus",
        "http-log",
        "statsd",
        "datadog",
        "file-log",
        "udp-log",
        "tcp-log",
        "loggly",
        "syslog",
        "grpc-web",
        "request-termination",
        "correlation-id",
        "post-function",
    }
}

describe("Kong Bundled and custom plugins", function()
    local plugins
    local kong_version

    lazy_setup(function()
        kong_version = tostring(select(1, meta._VERSION:match("^(%d+)")))
        local conf = assert(conf_loader(nil, {
            plugins = "bundled, jwt2headers, circuit-breaker",
        }))

        local kong_global = require "kong.global"
        _G.kong = kong_global.new()
        kong_global.init_pdk(kong, conf, nil)

        plugins = {}

        for plugin in pairs(conf.loaded_plugins) do
            local handler = require("kong.plugins." .. plugin .. ".handler")
            table.insert(plugins, {
                name    = plugin,
                handler = handler
            })
        end
    end)

    it("don't have identical `PRIORITY` fields", function()
        local priorities = {}

        for _, plugin in ipairs(plugins) do
            local priority = plugin.handler.PRIORITY
            assert.not_nil(priority)

            if priorities[priority] then
                assert.fail(fmt("plugins have the same priority: '%s' and '%s' (%d)",
                        priorities[priority], plugin.name, priority))
            end

            priorities[priority] = plugin.name
        end
    end)

    it("run in the correct order", function()
        local expected_order = PLUGIN_ORDERS[kong_version]
        assert.not_nil(expected_order, "Unsupported Kong version: " .. kong_version)

        table.sort(plugins, function(a, b)
            local priority_a = a.handler.PRIORITY or 0
            local priority_b = b.handler.PRIORITY or 0
            return priority_a > priority_b
        end)

        local sorted_plugins = {}
        for _, plugin in ipairs(plugins) do
            table.insert(sorted_plugins, plugin.name)
        end

        local actual_ordered_plugins = {}
        for _, plugin_name in ipairs(expected_order) do
            for _, sorted_plugin in ipairs(sorted_plugins) do
                if plugin_name == sorted_plugin then
                    table.insert(actual_ordered_plugins, plugin_name)
                    break
                end
            end
        end

        assert.same(actual_ordered_plugins, sorted_plugins)
    end)
end)
