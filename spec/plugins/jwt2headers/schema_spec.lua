local schema_def = require "kong.plugins.jwt2headers.schema"
local v = require("spec.helpers").validate_plugin_config_schema

describe("jwt2headers schema validation:", function()

    it("succeeds with default configuration", function()
        local ok, err = v({}, schema_def)
        assert.truthy(ok)
        assert.falsy(err)
        assert.same({ "*" }, ok.config.claims_to_include)
        assert.same({ "iat", "exp", "jti", "ver", "auth_time" }, ok.config.claims_to_exclude)
        assert.same({}, ok.config.custom_headers)
        assert.equals("x-", ok.config.header_prefix)
    end)

    it("succeeds with valid custom configuration", function()
        local config = {
            claims_to_include = { "sub", "role" },
            claims_to_exclude = { "iat", "exp" },
            custom_headers = {
                sub = "X-User-Email",
                role = "X-User-Role"
            },
            header_prefix = "custom-"
        }
        local ok, err = v(config, schema_def)
        assert.truthy(ok)
        assert.falsy(err)
        assert.same(config.claims_to_include, ok.config.claims_to_include)
        assert.same(config.claims_to_exclude, ok.config.claims_to_exclude)
        assert.same(config.custom_headers, ok.config.custom_headers)
        assert.equals(config.header_prefix, ok.config.header_prefix)
    end)

    it("succeeds with wildcard include", function()
        local ok, err = v({
            claims_to_include = { "*" }
        }, schema_def)
        assert.truthy(ok)
        assert.falsy(err)
        assert.same({ "*" }, ok.config.claims_to_include)
    end)

    it("fails when header_prefix is empty", function()
        local config = {
            header_prefix = ""
        }
        local ok, err = v(config, schema_def)
        assert.falsy(ok)
        assert.truthy(err)
        assert.truthy(err.config.header_prefix)
        assert.equals("length must be at least 1", err.config.header_prefix)
    end)

    it("fails when custom_headers is not a map", function()
        local config = {
            custom_headers = "invalid"
        }
        local ok, err = v(config, schema_def)
        assert.falsy(ok)
        assert.truthy(err)
        assert.truthy(err.config.custom_headers)
    end)
end)
