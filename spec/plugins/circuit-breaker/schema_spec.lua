local schema_def = require "kong.plugins.circuit-breaker.schema"
local v = require("spec.helpers").validate_plugin_config_schema

describe("circuit-breaker schema validation:", function()
    it("Success with all defaults", function()
        local ok, err = v({}, schema_def)
        assert.truthy(ok)
        assert.falsy(err)
        assert.equals(20, ok.config.min_calls_in_window)
        assert.equals(10, ok.config.window_time)
        assert.equals(2000, ok.config.api_call_timeout_ms)
        assert.equals(51, ok.config.failure_percent_threshold)
        assert.equals(15, ok.config.wait_duration_in_open_state)
        assert.equals(120, ok.config.wait_duration_in_half_open_state)
        assert.equals(10, ok.config.half_open_max_calls_in_window)
        assert.equals(5, ok.config.half_open_min_calls_in_window)
        assert.equals(599, ok.config.error_status_code)
        assert.equals(true, ok.config.set_logger_metrics_in_ctx)
        assert.equals('{"GET_/kong-healthcheck": true}', ok.config.excluded_apis)
    end)

    it("Success with custom configuration values", function()
        local ok, err = v({
            window_time = 15,
            min_calls_in_window = 30,
            api_call_timeout_ms = 500,
            failure_percent_threshold = 60,
            wait_duration_in_open_state = 20,
            wait_duration_in_half_open_state = 180,
            half_open_max_calls_in_window = 15,
            half_open_min_calls_in_window = 8,
            error_status_code = 503,
            error_msg_override = "Service temporarily unavailable",
            response_header_override = "application/json",
            excluded_apis = '{"GET_/health": true, "GET_/ready": true}',
            set_logger_metrics_in_ctx = false,
        }, schema_def)
        assert.truthy(ok)
        assert.falsy(err)
        assert.equals(15, ok.config.window_time)
        assert.equals(30, ok.config.min_calls_in_window)
        assert.equals(500, ok.config.api_call_timeout_ms)
        assert.equals(60, ok.config.failure_percent_threshold)
        assert.equals(20, ok.config.wait_duration_in_open_state)
        assert.equals(180, ok.config.wait_duration_in_half_open_state)
        assert.equals(15, ok.config.half_open_max_calls_in_window)
        assert.equals(8, ok.config.half_open_min_calls_in_window)
        assert.equals(503, ok.config.error_status_code)
        assert.equals("Service temporarily unavailable", ok.config.error_msg_override)
        assert.equals("application/json", ok.config.response_header_override)
        assert.equals(false, ok.config.set_logger_metrics_in_ctx)
    end)

    it("Error with invalid excluded_apis JSON", function()
        local ok, err = v({
            excluded_apis = "not_valid_json",
        }, schema_def)
        assert.falsy(ok)
        assert.truthy(err)
    end)

    it("Error with min_calls_in_window less than or equal to 1", function()
        local ok, err = v({
            min_calls_in_window = 1,
        }, schema_def)
        assert.falsy(ok)
        assert.truthy(err)
    end)

    it("Error with window_time less than or equal to 0", function()
        local ok, err = v({
            window_time = 0,
        }, schema_def)
        assert.falsy(ok)
        assert.truthy(err)
    end)

    it("Error with api_call_timeout_ms less than or equal to 0", function()
        local ok, err = v({
            api_call_timeout_ms = 0,
        }, schema_def)
        assert.falsy(ok)
        assert.truthy(err)
    end)

    it("Error with failure_percent_threshold less than or equal to 0", function()
        local ok, err = v({
            failure_percent_threshold = 0,
        }, schema_def)
        assert.falsy(ok)
        assert.truthy(err)
    end)
end)
