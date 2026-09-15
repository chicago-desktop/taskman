-- What the monitor widgets share (FR-006 §9): a ring of the latest samples, a
-- round ceiling for the scale, one sample of a runtime figure and each
-- widget's tree.
--
-- One library for both widgets: memory and goroutines are read by one path and
-- drawn with one kit, and two parsings of one rule would drift apart on the
-- first field. The runtime is read through `chicago.shell.config:system`
-- with a substitute `system` for the tests, so the ring and the trees are
-- checked without a running application.
local facts = require("facts")
local charts = require("charts")
local gadget = require("gadget")

local sample = {}

-- How many samples a widget remembers: at a 2 s step, the last two minutes.
sample.CAP = 60

local MB = 1024 * 1024

function sample.model(): any
    return {value = nil, history = {}, problem = nil}
end

-- push(history, value) -> history: the new one on the right, everything older than CAP is dropped.
function sample.push(history: any, value: any): any
    local list: any = type(history) == "table" and history or {}
    list[#list + 1] = tonumber(value) or 0
    while #list > sample.CAP do table.remove(list :: {any}, 1) end
    return list
end

-- heap(memory) -> the heap in use, in whole megabytes. The same field Task
-- Manager uses (`heap_in_use`): "memory" must not mean different things in the
-- widget and in the window it opens.
function sample.heap(memory: any): integer?
    local bytes = type(memory) == "table" and tonumber(memory.heap_in_use) or nil
    if bytes == nil then return nil end
    return math.tointeger(math.floor(bytes / MB + 0.5))
end

function sample.count(value: any): integer?
    local number = tonumber(value)
    if number == nil then return nil end
    return math.tointeger(math.floor(number + 0.5))
end

-- take(model, name, convert, from?) — one sample into the ring.
--
-- A refusal — no `system.read` right, no such section in the runtime — becomes
-- the widget's text, not a zero: zero goroutines under a denial would look
-- healthy and lie. `from` is the substitute `system` for the tests.
function sample.take(model: any, name: string, convert: any, from: any?)
    local snap: any = facts.read({name}, from)
    local problems: any = type(snap.problems) == "table" and snap.problems or {}
    if problems[name] ~= nil then
        model.problem = tostring(problems[name])
        return
    end
    local value = convert(snap[name])
    if value == nil then
        model.problem = name .. ": the runtime gave no number"
        return
    end
    model.problem = nil
    model.value = value
    model.history = sample.push(model.history, value)
end

-- A round ceiling by the ring's maximum: one scale for the gauge and the graph.
function sample.ceiling(history: any): number
    return charts.ceiling_of(history)
end

-- A refusal is the widget's label with wrapping: the reason is longer than eighteen cells.
function sample.refusal(text: any): any
    return {kind = "label", alert = true, wrap = true, text = tostring(text)}
end

function sample.memory_tree(model: any): any
    if model.problem then return sample.refusal(model.problem) end
    local top = sample.ceiling(model.history)
    return gadget.stack{
        gadget.meter{caption = "Heap", value = model.value or 0, ceiling = top, unit = " MB"},
        gadget.history{values = model.history, ceiling = top, unit = " MB"},
    }
end

function sample.goroutines_tree(model: any): any
    if model.problem then return sample.refusal(model.problem) end
    return gadget.stack{
        gadget.stat{value = model.value or 0, caption = "goroutines"},
        gadget.history{values = model.history, ceiling = sample.ceiling(model.history)},
    }
end

return sample
