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
    if type(args) == "table" and args.show_history ~= nil and type(args.show_history) ~= "boolean" then
        model.problem, model.invalid_config = "show_history must be a boolean", true
        return model
    end
    model.show_history = type(args) ~= "table" or args.show_history ~= false
    take(model)
    return model
end

function definition.update(model: any, action: any, context: any): any
    if model.invalid_config or action.type ~= "tick" then return false end
    take(model)
    return nil
end

function definition.view(model: any, context: any): any
    return sample.goroutines_tree(model)
end

return {main = app.main(definition), definition = definition}
