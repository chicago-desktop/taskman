-- The "Goroutines" widget on the desktop (FR-006 §9): how many goroutines the
-- runtime has now and how that changed over two minutes. Every 2 s one sample
-- by the same path Task Manager uses; a click opens Task Manager.
local app = require("app")
local sample = require("sample")

local definition: any = {interval = "2s"}
-- For the tests: a substitute `system`, like Task Manager's `definition.snapshot`.
definition.system = nil

local function take(model: any)
    sample.take(model, "goroutines", sample.count, definition.system)
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
    return sample.goroutines_tree(model)
end

return {main = app.main(definition), definition = definition}
