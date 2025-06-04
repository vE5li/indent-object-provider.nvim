local M = {}

-- Function copied and modified from arsham/indent-tools.nvim
local function in_indent(start_line, around)
    local cur_indent = vim.fn.indent(start_line)
    local total_lines = vim.api.nvim_buf_line_count(0)

    local first_line = start_line
    local first_non_empty_line = start_line
    for index = start_line, 1, -1 do
        if #vim.fn.getline(index) ~= 0 then
            local indent = vim.fn.indent(index)
            if indent < cur_indent then
                break
            end
            first_non_empty_line = index
        end
        first_line = index
    end

    local last_line = start_line
    local last_non_empty_line = start_line
    for index = start_line, total_lines, 1 do
        if #vim.fn.getline(index) ~= 0 then
            local indent = vim.fn.indent(index)
            if indent < cur_indent then
                break
            end
            last_non_empty_line = index
        end
        last_line = index
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

    for index = start_line, total_lines, 1 do
        if #vim.fn.getline(index) ~= 0 then
            local indent = vim.fn.indent(index)
            if indent ~= cur_indent then
                return index
            end
        end
    end

    return total_lines
end

local function find_last_indent()
    local start_line = vim.api.nvim_win_get_cursor(0)[1]
    local cur_indent = vim.fn.indent(start_line)

    for index = start_line, 1, -1 do
        if #vim.fn.getline(index) ~= 0 then
            local indent = vim.fn.indent(index)
            if indent ~= cur_indent then
                return index
            end
        end
    end

    return 0
end

local function collect_objects(indent, first_line, total_lines, objects)
    local index = first_line + 1

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

    while index <= total_lines do
        local line_length = #vim.fn.getline(index)

        if line_length > 0 then
            local next_indent = vim.fn.indent(index)

            if next_indent < indent then
                return insert(index)
            elseif next_indent > indent then
                index = collect_objects(next_indent, index, total_lines, objects)
            end
        end

        index = index + 1
    end

    return insert(index)
end

local function every_indent(around)
    local total_lines = vim.api.nvim_buf_line_count(0)
    local objects = {}

    local indentation = vim.fn.indent(1)
    collect_objects(indentation, 1, total_lines, objects)

    return objects
end

local bindings = {
    {
        name = "indentation",
        modes = { "i", "a" },
        key = "i",
        visual_mode = "linewise",
        callback = function(mode, requested)
            if requested == "closest" then
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
