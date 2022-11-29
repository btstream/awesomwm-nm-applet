local lgi = require("lgi")
local GVariant = lgi.GLib.Variant
local NM = lgi.NM
local naughty = require("naughty")

local SimpleSecretAgent = lgi.package("SimpleSecretAgent")
SimpleSecretAgent:class("SimpleAgent", NM.SecretAgentOld)

function SimpleSecretAgent.SimpleAgent:do_get_secrets(
    connection,
    connection_path,
    settings_name,
    hints,
    flags,
    callback
)
    naughty.notify({
        text = settings_name,
    })
end
function SimpleSecretAgent.SimpleAgent:do_cancel_get_secrets(
    connection_path,
    settings_name
)
end
function SimpleSecretAgent.SimpleAgent:do_save_secrets(
    connection,
    connection_path,
    callback
)
end
function SimpleSecretAgent.SimpleAgent:do_delete_secrets(
    connection,
    connection_path,
    callback
)
end

_G.nm_applet_agent = SimpleSecretAgent.SimpleAgent({
    identifier = "Awesomewm.nm.secretagent",
    capabilities = NM.SecretAgentCapabilities.NONE,
})

_G.nm_applet_agent:init(nil, nil)
