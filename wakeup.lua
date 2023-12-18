local _M = {}

function _M.scale_all_deployments_in_namespace()
    local namespace = "your-namespace" -- Replace with your namespace
    local http = require "resty.http"
    local httpc = http.new()

    -- Read the service account token
    local token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    local token_file = io.open(token_path, "r")
    if not token_file then
        ngx.log(ngx.ERR, "Failed to open service account token file: ", token_path)
        return ngx.say("Failed to open service account token file")
    end
    local token = token_file:read("*all")
    token_file:close()

    -- List all deployments in the namespace
    local list_url = "https://kubernetes.default.svc/api/v1/namespaces/" .. namespace .. "/deployments"
    local list_res, list_err = httpc:request_uri(list_url, {
        method = "GET",
        headers = {
            ["Authorization"] = "Bearer " .. token
        },
        ssl_verify = true
    })

    if not list_res then
        ngx.log(ngx.ERR, "Failed to list deployments: ", list_err)
        return ngx.say("Failed to list deployments")
    end

    local deployments = cjson.decode(list_res.body)
    if not deployments or not deployments.items then
        ngx.log(ngx.ERR, "Invalid response for deployments list")
        return ngx.say("Invalid response for deployments list")
    end

    -- Scale each deployment
    for _, deployment in ipairs(deployments.items) do
        local scale_url = "https://kubernetes.default.svc/apis/apps/v1/namespaces/" .. namespace .. "/deployments/" .. deployment.metadata.name .. "/scale"
        local scale_res, scale_err = httpc:request_uri(scale_url, {
            method = "PATCH",
            body = [[{"spec": {"replicas": 1}}],
            headers = {
                ["Authorization"] = "Bearer " .. token,
                ["Content-Type"] = "application/strategic-merge-patch+json"
            },
            ssl_verify = true
        })

        if not scale_res then
            ngx.log(ngx.ERR, "Failed to scale deployment: ", deployment.metadata.name, " Error: ", scale_err)
        else
            ngx.log(ngx.INFO, "Scaled deployment: ", deployment.metadata.name)
        end
    end

    -- Return the message to the client
    ngx.say("Page is loading")
end

return _M
