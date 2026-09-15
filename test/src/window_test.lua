-- Task Manager's window entry: what the Start menu reads, what the compositor
-- asks before opening it, and the window's own policy.
--
-- Task Manager ends any runtime process, other people's desktops' among
-- them, under its entry's broad policy — whoever logged on. Under a
-- terminal.ssh host anyone with an account logs on, so the entry names
-- `meta.requires: chicago.admin` and the base's compositor asks the logged-on
-- person's scope before opening it. An entry without the field opens for
-- everyone, silently — the shell's admin_windows_test checked this while Task
-- Manager lived in the shell.
local test = require("test")
local registry = require("registry")
local images = require("images")

local function define_tests()
    test.describe("Task Manager window entry", function()
        test.it("is Task Manager in Settings with its own taskmgr picture, for administrators only", function()
            local entry, err = registry.get("chicago.taskman:window")
            test.is_nil(err, tostring(err))
            local record: any = entry
            local meta: any = record and type(record.meta) == "table" and record.meta or {}
            test.eq(table.concat({tostring(meta.type), tostring(meta.title), tostring(meta.group), tostring(meta.image),
                tostring(meta.pixel_render), tostring(meta.pixel_state)}, "|"),
                "tui_desktop.window|Task Manager|Settings|chicago.taskman:images/taskmgr|chicago.shell.sdk:render|chicago.taskman:window")
            test.eq(meta.requires, "chicago.admin", "Task Manager must name chicago.admin in meta.requires")
            for _, size in ipairs({32, 16}) do
                local picture, why = images.get("chicago.taskman:images/taskmgr", size)
                test.not_nil(picture, "taskmgr@" .. tostring(size) .. ": " .. tostring(why))
            end
        end)

        test.it("runs under its own policy, which reads the runtime and may end a process", function()
            local window: any = assert(registry.get("chicago.taskman:window"))
            local policies = (window.data and window.data.security and window.data.security.policies) or {}
            test.eq(table.concat(policies, ","), "chicago.taskman:window_scope")
            local scope: any = assert(registry.get("chicago.taskman:window_scope"))
            local policy: any = scope.data and scope.data.policy or {}
            test.eq(table.concat(policy.actions or {}, ","),
                "process.context,process.registry,process.send,process.terminate,system.read")
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
return {run = function(options) return run_cases(options) end}
