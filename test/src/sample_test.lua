-- The monitor widgets: the ring keeps 60 samples, the heap is counted in whole
-- megabytes from the same field Task Manager uses, a refusal is a label with
-- the reason rather than a zero, and both trees lay out inside the panel body
-- without overlaps — in cells and at two pixel cell sizes.
local test = require("test")
local sample = require("sample")
local ui = require("ui")
local gadget = require("gadget")
local errors = require("errors")

local MB = 1024 * 1024

-- A substitute `system` in the form `facts` reads: sections with functions.
local function runtime(heap_bytes: any, goroutines: any): any
    return {
        memory = {stats = function(): (any, any) return {heap_in_use = heap_bytes}, nil end},
        runtime = {goroutines = function(): (any, any) return goroutines, nil end},
    }
end

-- A refusal in the form the runtime gives it: an error with a kind.
local function refused(): any
    local err = errors.new({kind = errors.PERMISSION_DENIED, message = "system.read on memory"})
    return {
        memory = {stats = function(): (any, any) return nil, err end},
        runtime = {goroutines = function(): (any, any) return nil, err end},
    }
end

-- The first two plan items drawn on top of each other; nil — no overlaps.
local function overlap(plan: any): any
    for index, item in ipairs(plan.items) do
        for other = index + 1, #plan.items do
            local b = plan.items[other]
            local r = item.rect
            if not (r.x + r.w <= b.rect.x or b.rect.x + b.rect.w <= r.x
                or r.y + r.h <= b.rect.y or b.rect.y + b.rect.h <= r.y) then
                return tostring(item.node.kind) .. "/" .. tostring(b.node.kind)
            end
        end
    end
    return nil
end

local function kinds(plan: any): string
    local out = {}
    for _, item in ipairs(plan.items) do out[#out + 1] = tostring(item.node.kind) end
    return table.concat(out, ",")
end

-- The tree lays out inside the widget body: `width - 2` by `height - 2`, the
-- panel takes one cell on each side.
--
-- A stack clips its child to the remaining height, so an extra row on top does
-- not push the graph out of the body — it silently takes the row from the
-- graph. Hence the minimum check: the graph is no lower than
-- `gadget.ROWS.history`.
local function fits(tree: any, width: integer, height: integer, expected: string, name: string)
    test.is_nil(ui.problem(tree), name .. ": " .. tostring(ui.problem(tree)))
    for _, cell in ipairs({false, {w = 10, h = 20}, {w = 8, h = 16}}) do
        local where = name .. (cell and (" @" .. cell.w .. "x" .. cell.h) or " cells")
        local plan = ui.plan(tree, width, height, ui.interaction(), cell and {cell = cell} or nil)
        for _, item in ipairs(plan.items) do
            local r = item.rect
            test.is_true(r.w >= 1 and r.h >= 1 and r.x >= 1 and r.y >= 1
                and r.x + r.w - 1 <= width and r.y + r.h - 1 <= height,
                where .. ": " .. tostring(item.node.kind) .. " outside the body")
            if item.node.kind == "graph" then
                test.is_true(r.h >= gadget.ROWS.history,
                    where .. ": graph squeezed to " .. tostring(r.h) .. " rows")
            end
        end
        test.is_nil(overlap(plan), where)
        test.eq(kinds(plan), expected, where)
    end
end

local function full(name: string, convert: any, source: any): any
    local model = sample.model()
    for step = 1, sample.CAP do sample.take(model, name, convert, source(step)) end
    return model
end

local function define_tests()
    test.describe("Task Manager's desktop widgets", function()
        test.it("the ring keeps sixty samples, the newest on the right", function()
            local model = sample.model()
            for step = 1, 70 do
                sample.take(model, "goroutines", sample.count, runtime(0, step))
            end
            test.eq(#model.history, 60)
            test.eq(model.history[1], 11, "the old ones left on the left")
            test.eq(model.history[60], 70, "the newest on the right")
            test.eq(model.value, 70)
            test.is_nil(model.problem)
        end)

        test.it("the heap — in whole megabytes from heap_in_use, as in Task Manager", function()
            local model = sample.model()
            sample.take(model, "memory", sample.heap, runtime(312.4 * MB, 0))
            test.eq(model.value, 312)
            sample.take(model, "memory", sample.heap, runtime(312.6 * MB, 0))
            test.eq(model.value, 313)
            test.eq(#model.history, 2)
        end)

        test.it("a refusal — a label with the reason, not a zero, and it does not enter the ring", function()
            for _, case in ipairs({
                {name = "memory", convert = sample.heap, tree = sample.memory_tree},
                {name = "goroutines", convert = sample.count, tree = sample.goroutines_tree},
            }) do
                local model = sample.model()
                sample.take(model, case.name, case.convert, runtime(100 * MB, 40))
                sample.take(model, case.name, case.convert, refused())
                test.eq(#model.history, 1, case.name .. ": a refusal is not a sample")
                local tree: any = case.tree(model)
                test.eq(tree.kind, "label", case.name)
                test.is_true(tree.alert == true and tree.wrap == true, case.name .. ": an alert label with wrapping")
                test.is_true(tostring(tree.text):find("permission denied", 1, true) ~= nil,
                    case.name .. ": the reason is named: " .. tostring(tree.text))
                test.is_nil(ui.problem(tree), case.name)
                -- The next successful sample brings the widget back.
                sample.take(model, case.name, case.convert, runtime(100 * MB, 40))
                test.is_nil(model.problem, case.name)
            end
        end)

        test.it("memory lays out in an 18×6 body without overlaps: caption, value, gauge, graph", function()
            local model = full("memory", sample.heap, function(step: integer): any return runtime((250 + step) * MB, 0) end)
            local tree: any = sample.memory_tree(model)
            -- Only leaves are in the plan: containers lay out but are not drawn.
            -- The shell's meter is the caption and the value in one row over
            -- a gauge across the whole width (docs/sdk.md, "The kit").
            fits(tree, 18, 6, "label,label,gauge,graph", "memory")
            local meter: any = tree.children[1]
            test.eq(meter.children[2].value, 310)
            test.eq(meter.children[2].ceiling, 500, "a round ceiling by the ring's maximum")
            test.eq(tree.children[2].children[1].ceiling, 500, "one scale for the gauge and the graph")
        end)

        test.it("goroutines lay out in an 18×7 body without overlaps: value, caption, graph", function()
            local model = full("goroutines", sample.count, function(step: integer): any return runtime(0, 300 + step) end)
            local tree: any = sample.goroutines_tree(model)
            fits(tree, 18, 7, "label,label,graph", "goroutines")
            test.eq(tree.children[1].children[1].children[1].text, "360")
            test.eq(tree.children[1].children[1].children[2].text, "goroutines")
        end)
    end)
end

local original_tests = define_tests
local function configured_tests()
    original_tests()
    test.describe("widget-owned history setting", function()
        test.it("hides the graph on one model without changing another", function()
            local a, b = sample.model(), sample.model()
            a.show_history = false
            a.value, b.value = 42, 42
            test.eq(#sample.memory_tree(a).children, 1)
            test.eq(#sample.memory_tree(b).children, 2)
            test.eq(#sample.goroutines_tree(a).children, 1)
            test.eq(#sample.goroutines_tree(b).children, 2)
        end)
    end)
end
local run_cases = test.run_cases(configured_tests)
return {run = function(options) return run_cases(options) end}
