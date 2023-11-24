local M = {}

-- Function copied and modified from arsham/indent-tools.nvim
local function in_indent(start_line, around)
    local cur_indent = vim.fn.indent(start_line)
    local total_lines = vim.api.nvim_buf_line_count(0)

    local first_line = start_line
    local first_non_empty_line = start_line
    for i = start_line, 0, -1 do
        if cur_indent == 0 and #vim.fn.getline(i) == 0 then
            -- If we are at column zero, we will stop at an empty line.
            break
        end
        if #vim.fn.getline(i) ~= 0 then
            local indent = vim.fn.indent(i)
            if indent < cur_indent then
                break
            end
            first_non_empty_line = i
        end
        first_line = i
    end

    local last_line = start_line
    local last_non_empty_line = start_line
    for i = start_line, total_lines, 1 do
        if cur_indent == 0 and #vim.fn.getline(i) == 0 then
            break
        end
        if #vim.fn.getline(i) ~= 0 then
            local indent = vim.fn.indent(i)
            if indent < cur_indent then
                break
            end
            last_non_empty_line = i
        end
        last_line = i
    end

    if not around then
        first_line = first_non_empty_line
        last_line = last_non_empty_line
    end

    local line_length = #vim.fn.getline(last_line)
    return {
        first_line = first_line,
        start_column = cur_indent,
        last_line = last_line,
        end_column = line_length,
    }
end

local function find_next_indent()
    local start_line = vim.api.nvim_win_get_cursor(0)[1]
    local cur_indent = vim.fn.indent(start_line)
    local total_lines = vim.api.nvim_buf_line_count(0)

    for i = start_line, total_lines, 1 do
        if #vim.fn.getline(i) ~= 0 then
            local indent = vim.fn.indent(i)
            if indent ~= cur_indent then
                return i
            end
        end
    end

    return total_lines
end

local function find_last_indent()
    local start_line = vim.api.nvim_win_get_cursor(0)[1]
    local cur_indent = vim.fn.indent(start_line)

    for i = start_line, 0, -1 do
        if #vim.fn.getline(i) ~= 0 then
            local indent = vim.fn.indent(i)
            if indent ~= cur_indent then
                return i
            end
        end
    end

    return 0
end

local function collect_objects(indent, first_line, total_lines, objects)
    local i = first_line + 1

    local function insert(last_line)
        local line_length = #vim.fn.getline(last_line - 1)

        table.insert(objects, {
            first_line = first_line,
            start_column = indent + 1,
            last_line = last_line - 1,
            end_column = line_length,
        })

        return last_line - 1
    end

    while i <= total_lines do
        local line_length = #vim.fn.getline(i)

        -- On the root scope, any empty line will terminate the object
        if line_length == 0 and indent == 0 then
            return insert(i)
        end

        if line_length > 0 then
            local next_indent = vim.fn.indent(i)

            if next_indent < indent then
                return insert(i)
            elseif next_indent > indent then
                i = collect_objects(next_indent, i, total_lines, objects)
            end
        end

        i = i + 1
    end

    return insert(i)
end

local function every_indent(around)
    local total_lines = vim.api.nvim_buf_line_count(0)
    local objects = {}
    local i = 0

    while i <= total_lines do
        local line_length = #vim.fn.getline(i)

        if line_length > 0 then
            local indentation = vim.fn.indent(i)
            i = collect_objects(indentation, i, total_lines, objects)
        end

        i = i + 1
    end

    return objects
end

local bindings = {
    {
        name = "indentation",
        modes = { "i", "a" },
        key = "i",
        visual_mode = "linewise",
        callback = function(mode, requested)
            if requested == "cursor" then
                local cur_line = vim.api.nvim_win_get_cursor(0)[1]
                return in_indent(cur_line, mode == "a")
            elseif requested == "next" then
                local start_line = find_next_indent()
                return in_indent(start_line, mode == "a")
            elseif requested == "last" then
                local start_line = find_last_indent()
                return in_indent(start_line, mode == "a")
            elseif requested == "every" then
                return every_indent(mode == "a")
            end
        end,
    },
}

M.setup = function( --[[ config ]])
    for _, binding in ipairs(bindings) do
        require("unified-text-objects").register_binding(binding)
    end
end

return M
