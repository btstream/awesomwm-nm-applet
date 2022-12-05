local lgi = require("lgi")
local GClousure = lgi.GObject.Closure
local Gio = lgi.Gio
local GError = lgi.GLib.Error
local GVariant = lgi.GLib.Variant
local GVariantType = lgi.GLib.VariantType
local NM = lgi.NM

local inspect = require("inspect")

local M = {}

local function get_interface_info()
    local node_xml_file = io.open(
        "/usr/share/dbus-1/interfaces/org.freedesktop.NetworkManager.SecretAgent.xml",
        "r"
    )
    if not node_xml_file then return end
    local node_xml_content = node_xml_file:read("a")
    local node_info = Gio.DBusNodeInfo.new_for_xml(node_xml_content)
    if node_info then
        return node_info:lookup_interface(
            "org.freedesktop.NetworkManager.SecretAgent"
        )
    else
        return nil
    end
end

local function get_session_type()
    return os.getenv("LIBNM_USE_SESSION_BUS") == nil and Gio.BusType.SYSTEM
        or Gio.BusType.SESSION
end

local function get_connection_proxy(object_path)
    Gio.DBusProxy.new_for_bus_sync(
        get_session_type(),
        Gio.DBusProxyFlags.NONE,
        nil,
        "org.freedesktop.NetworkManager",
        object_path,
        "org.freedesktop.NetworkManager.Settings.Connection",
        nil
    )
end

local function get_secrets(
    connection,
    connection_path,
    settings_name,
    hints,
    flags,
    invocation
)
    print(inspect(connection.connection.uuid), hints, flags)
    for key, value in pairs(connection) do
        print(key, value)
    end
end

local function method_call(
    dbus_connection,
    sender,
    object_path,
    interface_name,
    method_name,
    parameters,
    invocation
)
    if method_name == "GetSecrets" then
        get_secrets(
            parameters[1], -- connection
            parameters[2], -- connection_path
            parameters[3], -- settings_name
            parameters[4], -- hints
            parameters[4], -- flags
            invocation
        )
    end
end

M.dbus_connection = Gio.bus_get_sync(get_session_type())

M.dbus_connection:register_object(
    "/org/freedesktop/NetworkManager/SecretAgent",
    get_interface_info(),
    GClousure(method_call)
)

-- registe to agent manager
M.dbus_connection:call_sync(
    "org.freedesktop.NetworkManager",
    "/org/freedesktop/NetworkManager/AgentManager",
    "org.freedesktop.NetworkManager.AgentManager",
    "RegisterWithCapabilities",
    GVariant("(su)", {
        "Awewomewm.nm-applet.agent",
        NM.SecretAgentCapabilities.NONE,
    }),
    nil,
    Gio.DBusCallFlags.NONE,
    -1,
    nil
)

local main_loop = lgi.GLib.MainLoop()
main_loop:run()
