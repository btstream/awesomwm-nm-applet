local nm = require("lgi").NM
local client = nm.Client.new()
local devices = client:get_devices()

return {
    nm = nm,
    client = client,
    devices = devices,
}
