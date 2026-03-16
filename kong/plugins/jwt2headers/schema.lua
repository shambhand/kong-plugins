local typedefs = require "kong.db.schema.typedefs"

local plugin_name = "jwt2headers"

local schema = {
    name = plugin_name,
    fields = {
        { consumer = typedefs.no_consumer },
        {
            config = {
                type = "record",
                fields = {
                    {
                        claims_to_include = {
                            type = "array",
                            elements = { type = "string" },
                            default = { "*" },
                            required = false,
                        },
                    },
                    {
                        claims_to_exclude = {
                            type = "array",
                            elements = { type = "string" },
                            default = { "iat", "exp", "jti", "ver", "auth_time" },
                            required = false,
                        },
                    },
                    {
                        custom_headers = {
                            type = "map",
                            keys = { type = "string" },
                            values = { type = "string" },
                            default = {},
                            required = false,
                        },
                    },
                    {
                        header_prefix = {
                            type = "string",
                            default = "x-",
                            required = false,
                            len_min = 1,
                        },
                    },
                },
                entity_checks = {
                },
            },
        },
    }
}

return schema
