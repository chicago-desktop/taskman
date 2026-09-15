-- Task Manager's four tabs on sample data, drawn by the shell's own renderer
-- into test/shots/taskman-<tab>.png — the look of the window, which the
-- layout checks in taskman_test do not see (a wrong colour, a caption a pixel
-- off). The same sample the shell's paint-png command drew while Task Manager
-- lived in the shell.
local test = require("test")
local ui = require("ui")
local render = require("render")
local rasters = require("rasters")
local fs = require("fs")
local gfx = require("gfx")
local taskman_window = require("taskman_window")

local CELL = {w = 10, h = 20}
local CLIENT = {width = 76, height = 24}
local MB = 1024 * 1024
local TABS = {"applications", "processes", "performance", "node"}

local function fonts(): any
    local dir = assert(fs.get("app:system_fonts"))
    return {face = assert(gfx.font(assert(dir:readfile("LiberationSans-Regular.ttf")), {size = 13, smooth = true})),
        mono = assert(gfx.font(assert(dir:readfile("LiberationMono-Regular.ttf")), {size = 13, smooth = true}))}
end

-- The sample: a workstation with four windows, 76 processes and 150 samples.
local function sample(): any
    local state: any = {tab = 3, selected = 0, offset = 0, heap_history = {}, goroutine_history = {},
        snapshot = {taken = 1788858300, goroutines = 428, cpu_count = 8, max_procs = 8,
            pid = "24680", hostname = "wippy-workstation", node_id = "local", node_role = "standalone",
            memory = {alloc = 286 * MB, heap_in_use = 312 * MB, heap_sys = 384 * MB, heap_released = 46 * MB, num_gc = 128},
            processes = {}, hosts = {{id = "app:processes", processes = 64}, {id = "wippy:processes", processes = 12}},
            members = {{id = "local"}}},
        windows = {{id = "w1", title = "My Computer", ready = true, image = "my_computer"},
            {id = "w2", title = "Notepad — notes.txt", ready = true, image = "text_document"},
            {id = "w3", title = "Bash", ready = true, image = "program"},
            {id = "w4", title = "Task Manager", ready = true, image = "system"}}}
    for index = 1, 150 do
        state.goroutine_history[index] = math.floor(360 + math.sin(index / 8) * 24 + math.sin(index / 3) * 14 + index / 3)
        state.heap_history[index] = (230 + (index % 45) * 1.8) * MB
    end
    for index = 1, 76 do
        state.snapshot.processes[index] = {pid = "local:process-" .. string.format("%04d", index),
            source = index == 1 and "windows.shell:shell" or "app.workers:worker_" .. string.format("%02d", index),
            state = index % 4 == 0 and "running" or "waiting", steps = index * 147, started = 1788850100}
    end
    return state
end

local function define_tests()
    test.describe("Task Manager shots", function()
        test.it("draws the four tabs on sample data into test/shots/taskman-<tab>.png", function()
            local state = sample()
            local face = fonts()
            local shots = assert(fs.get("app:shots"))
            for tab = 1, 4 do
                state.tab, state.selected_id = tab, tab == 1 and "w2" or (tab == 2 and "local:process-0002" or nil)
                local tree = taskman_window.definition.view(state, CLIENT)
                test.is_nil(ui.problem(tree), TABS[tab] .. ": " .. tostring(ui.problem(tree)))
                local store = rasters.store()
                store.begin()
                local placed, why = render.placement({id = "taskman-" .. TABS[tab], state_revision = tab,
                    content_state = {sdk = 1, revision = tab, ui = tree, interaction = ui.interaction()}},
                    {x = 1, y = 1, cols = CLIENT.width, rows = CLIENT.height}, CELL, face, store)
                test.not_nil(placed, TABS[tab] .. ": " .. tostring(why))
                local raster = gfx.raster(CLIENT.width * CELL.w, CLIENT.height * CELL.h)
                raster:fill("#008080")
                raster:blit(placed.raster :: gfx.Raster, 1, 1)
                local png = assert(raster:encode("png"))
                test.is_true(#png > 1000, TABS[tab] .. ": a real picture, not an empty one")
                assert(shots:writefile("taskman-" .. TABS[tab] .. ".png", png))
            end
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
return {run = function(options) return run_cases(options) end}
