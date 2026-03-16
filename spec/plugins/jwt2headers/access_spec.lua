local helpers = require "spec.helpers"
local cjson = require "cjson"

describe("jwt2headers plugin:", function()
    local bp = helpers.get_db_utils("postgres", { "routes", "services", "plugins" }, { "jwt2headers" })

    local mock_jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJqb2huLmRvZUBleGFtcGxlLmNvbSIsInJvbGUiOiJhZG1pbiIsImdyb3VwcyI6WyJ1c2VycyIsImFkbWlucyJdfQ.sign"

    setup(function()
        local service = bp.services:insert {
            name = "test-service"
        }

        local route1 = bp.routes:insert {
            paths = { "/default" },
            service = { id = service.id }
        }

        local route2 = bp.routes:insert {
            paths = { "/custom" },
            service = { id = service.id }
        }

        bp.plugins:insert {
            name = "jwt2headers",
            service = { id = service.id },
            config = {
                claims_to_include = {"*"},
                claims_to_exclude = {},
                custom_headers = {},
                header_prefix = "x-"
            }
        }

        bp.plugins:insert {
            name = "jwt2headers",
            route = { id = route2.id },
            config = {
                claims_to_include = {"sub", "role"},
                claims_to_exclude = {"groups"},
                custom_headers = {
                    sub = "User-Email",
                    role = "User-Role"
                },
                header_prefix = "custom-"
            }
        }

        assert(helpers.start_kong({
            plugins = "bundled,jwt2headers",
            nginx_conf = "spec/fixtures/custom_nginx.template",
        }))
    end)

    teardown(function()
        helpers.stop_kong()
    end)

    describe("plugin functionality:", function()
        local proxy_client

        before_each(function()
            proxy_client = helpers.proxy_client()
        end)

        after_each(function()
            if proxy_client then
                proxy_client:close()
            end
        end)

        it("adds all headers with default config", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/default",
                headers = {
                    ["Authorization"] = "Bearer " .. mock_jwt
                }
            })

            local body = assert.res_status(200, res)
            local json = cjson.decode(body)
            assert.are.equal("john.doe@example.com", json.headers["x-sub"])
            assert.are.equal("admin", json.headers["x-role"])
            local groups = cjson.decode(json.headers["x-groups"])
            assert.same({ "users", "admins" }, groups)
        end)

        it("respects custom header configuration", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/custom",
                headers = {
                    ["Authorization"] = "Bearer " .. mock_jwt
                }
            })

            local body = assert.res_status(200, res)
            local json = cjson.decode(body)
            assert.are.equal("john.doe@example.com", json.headers["user-email"])
            assert.are.equal("admin", json.headers["user-role"])
            assert.falsy(json.headers["custom-groups"])
        end)

        it("handles missing authorization header", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/default"
            })

            local body = assert.res_status(401, res)
            assert.equal('{"message":"Missing or Invalid Authorization header"}', body)
            assert.falsy(res.headers["x-sub"])
        end)

        it("handles invalid JWT format", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/default",
                headers = {
                    ["Authorization"] = "Bearer invalid.token.format"
                }
            })

            local body = assert.res_status(401, res)
            assert.equal('{"message":"Invalid JWT token"}', body)
            assert.falsy(res.headers["x-sub"])
        end)

        it("processes array values correctly", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/default",
                headers = {
                    ["Authorization"] = "Bearer " .. mock_jwt
                }
            })

            local body = assert.res_status(200, res)
            local json = cjson.decode(body)
            assert.same('["users","admins"]', json.headers["x-groups"])
        end)

        it("processes Authorization header without Bearer prefix", function()
            local res = assert(proxy_client:send {
                method = "GET",
                path = "/default",
                headers = {
                    ["Host"] = "test.com",
                    ["Authorization"] = mock_jwt,
                }
            })

            local body = assert.res_status(200, res)
            local json = cjson.decode(body)

            assert.are.equal("john.doe@example.com", json.headers["x-sub"])
            assert.are.equal("admin", json.headers["x-role"])
        end)

    end)

    describe("Application scenarios:", function()
        it("can apply as global plugin", function()
            local ok, err = pcall(function()
                bp.plugins:insert {
                    name = "jwt2headers",
                    config = {
                        claims_to_include = {"*"}
                    }
                }
            end)
            assert.truthy(ok)
        end)

        it("can apply as service plugin", function()
            local service = bp.services:insert {
                name = "test-service-2"
            }
            local ok, err = pcall(function()
                bp.plugins:insert {
                    name = "jwt2headers",
                    service = { id = service.id },
                    config = {
                        claims_to_include = {"*"}
                    }
                }
            end)
            assert.truthy(ok)
        end)

        it("can apply as route plugin", function()
            local route = bp.routes:insert {
                name = "test-route",
                paths = { "/test" }
            }
            local ok, err = pcall(function()
                bp.plugins:insert {
                    name = "jwt2headers",
                    route = { id = route.id },
                    config = {
                        claims_to_include = {"*"}
                    }
                }
            end)
            assert.truthy(ok)
        end)

        it("cannot apply on consumer", function()
            local consumer = bp.consumers:insert {
                username = "test-consumer"
            }
            local ok, err = pcall(function()
                bp.plugins:insert {
                    name = "jwt2headers",
                    consumer = { id = consumer.id },
                    config = {
                        claims_to_include = {"*"}
                    }
                }
            end)
            assert.falsy(ok)
            assert.truthy(err:find("schema violation"))
        end)

        it("fails if header_prefix is empty", function()
            local ok, err = pcall(function()
                bp.plugins:insert {
                    name = "jwt2headers",
                    config = {
                        header_prefix = ""
                    }
                }
            end)
            assert.falsy(ok)
            assert.truthy(err:find("schema violation"))
        end)

    end)
end)
