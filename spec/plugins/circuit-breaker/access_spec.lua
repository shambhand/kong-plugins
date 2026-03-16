local helpers = require "spec.helpers"

describe("circuit-breaker plugin:", function()
    local bp = helpers.get_db_utils("postgres", { "services", "routes", "plugins" }, { "circuit-breaker" })
    local admin_client
    local proxy_client

    setup(function()

        local service = bp.services:insert {
            name = "test-service"
        }

        bp.routes:insert({
            paths = { "/request" },
            service = { id = service.id }
        })

        bp.routes:insert({
            paths = { "/status/500" },
            service = { id = service.id }
        })

        bp.plugins:insert {
            name = "circuit-breaker",
            service = { id = service.id },
            config = {
                window_time = 10,
                min_calls_in_window = 20,
                api_call_timeout_ms = 2000,
                failure_percent_threshold = 51,
                wait_duration_in_open_state = 15,
                wait_duration_in_half_open_state = 120,
                half_open_max_calls_in_window = 10,
                half_open_min_calls_in_window = 5,
                error_status_code = 599,
                excluded_apis = '{"GET_/kong-healthcheck": true}',
                set_logger_metrics_in_ctx = true,
            },
        }

        -- start Kong with your testing Kong configuration (defined in "spec.helpers")
        assert(helpers.start_kong({
            plugins = "bundled,circuit-breaker",
            nginx_conf = "spec/fixtures/custom_nginx.template",
        }))

        admin_client = helpers.admin_client()
    end)

    teardown(function()
        if admin_client then
            admin_client:close()
        end

        helpers.stop_kong()
    end)

    before_each(function()
        proxy_client = helpers.proxy_client()
    end)

    after_each(function()
        if proxy_client then
            proxy_client:close()
        end
    end)

    describe("Circuit breaker basic scenarios:", function()
        it("Successful request passes through when circuit is closed", function()
            local res = assert(proxy_client:send {
                method = 'GET',
                path = '/request'
            })
            assert.res_status(200, res)
        end)
    end)

    describe("Application scenarios:", function()

        it("Can apply as global plugin", function()
            local isSuccess, _ = pcall(function()
                bp.plugins:insert {
                    name = "circuit-breaker",
                    config = {
                        window_time = 10,
                        min_calls_in_window = 20,
                        api_call_timeout_ms = 2000,
                        failure_percent_threshold = 51,
                        wait_duration_in_open_state = 15,
                        wait_duration_in_half_open_state = 120,
                        half_open_max_calls_in_window = 10,
                        half_open_min_calls_in_window = 5,
                        error_status_code = 599,
                        excluded_apis = '{"GET_/kong-healthcheck": true}',
                    },
                }
            end)

            assert.truthy(isSuccess)
        end)

        it("Can apply as service plugin", function()
            local service = bp.services:insert {
                name = "dummy-service"
            }

            local isSuccess, _ = pcall(function()
                bp.plugins:insert {
                    name = "circuit-breaker",
                    service = { id = service.id },
                    config = {
                        window_time = 10,
                        min_calls_in_window = 20,
                        api_call_timeout_ms = 2000,
                        failure_percent_threshold = 51,
                        wait_duration_in_open_state = 15,
                        wait_duration_in_half_open_state = 120,
                        half_open_max_calls_in_window = 10,
                        half_open_min_calls_in_window = 5,
                        error_status_code = 599,
                        excluded_apis = '{"GET_/kong-healthcheck": true}',
                    },
                }
            end)

            assert.truthy(isSuccess)
        end)

        it("Can apply as route plugin", function()
            local route = bp.routes:insert {
                name = "dummy-route",
                paths = { "/dummy" },
            }
            local isSuccess, _ = pcall(function()
                bp.plugins:insert {
                    name = "circuit-breaker",
                    route = { id = route.id },
                    config = {
                        window_time = 10,
                        min_calls_in_window = 20,
                        api_call_timeout_ms = 2000,
                        failure_percent_threshold = 51,
                        wait_duration_in_open_state = 15,
                        wait_duration_in_half_open_state = 120,
                        half_open_max_calls_in_window = 10,
                        half_open_min_calls_in_window = 5,
                        error_status_code = 599,
                        excluded_apis = '{"GET_/kong-healthcheck": true}',
                    },
                }
            end)

            assert.truthy(isSuccess)
        end)
    end)
end)
