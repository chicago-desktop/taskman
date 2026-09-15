-- The "Memory" widget on the desktop (FR-006 §9): the runtime's heap now — a
-- gauge against a round ceiling — and its history over two minutes. Every 2 s
-- one sample by the same path Task Manager uses
-- (`chicago.shell.config:system`); a click on the widget opens Task Manager.
local app = require("app")
local sample = require("sample")

local definition: any = {interval = "2s"}
-- For the tests: a substitute `system`, like Task Manager's `definition.snapshot`.
definition.system = nil

local function take(model: any)
    sample.take(model, "memory", sample.heap, definition.system)
end

function definition.init(args: any, context: any): any
    local model = sample.model()
    take(model)
    return model
end

function definition.update(model: any, action: any, context: any): any
    if action.type ~= "tick" then return false end
    take(model)
    return nil
end

function definition.view(model: any, context: any): any
    return sample.memory_tree(model)
end

return {main = app.main(definition), definition = definition}
