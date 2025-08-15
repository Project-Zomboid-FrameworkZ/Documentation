#!/usr/bin/env lua

--[[
DocZ - Lua Documentation Generator
A lightweight documentation generator that parses Doxygen-style comments in Lua files
and generates HTML documentation.

Features:
- Recursively scans directories for .lua files
- Parses Doxygen-style comments (--! and ---)
- Supports @brief, @class, @module, @namespace, @param, @return, @field, @note, @see tags
- Generates HTML output with navigation and styling
- Detects functions, methods, tables, and modules
- Cross-references and links between documentation

Usage:
lua DocZ.lua -i <input_dir> -o <output_dir> [-t <title>] [-h]

Author: DocZ Generator
]]

local DocZ = {}
DocZ.version = "1.0.0"

-- Default configuration
local config = {
    input_dir = nil,
    output_dir = nil,
    title = "Lua API Reference",
    recursive = true,
    include_undocumented = true,
    html_template = nil
}

-- Parsed documentation data
local documentation = {
    modules = {},
    classes = {},
    functions = {},
    files = {},
    index = {}
}

-- Utility functions
local utils = {}

function utils.escape_html(str)
    if not str then return "" end
    str = tostring(str)
    if str then
        str = str:gsub("&", "&amp;")
        str = str:gsub("<", "&lt;")
        str = str:gsub(">", "&gt;")
        str = str:gsub('"', "&quot;")
        str = str:gsub("'", "&#39;")
    end
    return str or ""
end

function utils.format_type_with_icons(type_str)
    -- Format type string with icons positioned before each individual type
    if not type_str or type_str == "" then
        return "❓ unknown"
    end
    
    -- Handle union types by formatting each part with its icon
    if type_str:find("|") then
        local formatted_types = {}
        for single_type in type_str:gmatch("([^|]+)") do
            single_type = single_type:match("^%s*(.-)%s*$") -- trim whitespace
            -- Remove leading backslash if present (e.g., \object -> object)
            local clean_type = single_type:gsub("^\\", "")
            local icon = utils.get_single_type_icon(clean_type)
            table.insert(formatted_types, icon .. " " .. clean_type)
        end
        return table.concat(formatted_types, " | ")
    end
    
    -- Single type - remove leading backslash if present
    local clean_type = type_str:gsub("^\\", "")
    local icon = utils.get_single_type_icon(clean_type)
    return icon .. " " .. clean_type
end

function utils.clean_type_text(type_str)
    -- Clean up type string for display by removing backslashes
    if not type_str or type_str == "" then
        return "unknown"
    end
    
    -- Handle union types by cleaning each part
    if type_str:find("|") then
        local clean_types = {}
        for single_type in type_str:gmatch("([^|]+)") do
            single_type = single_type:match("^%s*(.-)%s*$") -- trim whitespace
            -- Remove leading backslash if present (e.g., \object -> object)
            single_type = single_type:gsub("^\\", "")
            table.insert(clean_types, single_type)
        end
        return table.concat(clean_types, "|")
    end
    
    -- Remove leading backslash if present (e.g., \object -> object)
    return type_str:gsub("^\\", "")
end

function utils.get_type_icon(type_str)
    -- Get appropriate emoji icon for data types
    if not type_str or type_str == "" then
        return "❓"
    end
    
    -- Handle union types (e.g., string|nil, number|boolean) by showing individual icons
    if type_str:find("|") then
        local icons = {}
        for single_type in type_str:gmatch("([^|]+)") do
            single_type = single_type:match("^%s*(.-)%s*$") -- trim whitespace
            -- Remove leading backslash if present (e.g., \object -> object)
            single_type = single_type:gsub("^\\", "")
            table.insert(icons, utils.get_single_type_icon(single_type))
        end
        return table.concat(icons, " ")
    end
    
    -- Remove leading backslash if present (e.g., \object -> object)
    type_str = type_str:gsub("^\\", "")
    
    return utils.get_single_type_icon(type_str)
end

function utils.get_single_type_icon(type_str)
    -- Enhanced optional type detection - Check this FIRST before any other type checks
    -- Check for various optional patterns: type?, type|nil, type | nil
    local is_optional = false
    local base_type = type_str
    
    -- Pattern 1: type? (e.g., string?, number?, MyClass?, table?)
    if type_str:find("%?$") then
        is_optional = true
        base_type = type_str:gsub("%?$", "")
    -- Pattern 2: type|nil or type | nil (union with nil)
    elseif type_str:find("|%s*nil") or type_str:find("nil%s*|") then
        is_optional = true
        -- Extract the non-nil type from the union
        base_type = type_str:gsub("%s*|%s*nil", ""):gsub("nil%s*|%s*", "")
    -- Pattern 3: Check if ? appears anywhere in the type (for complex types like table<string>?)
    elseif type_str:find("%?") then
        is_optional = true
        base_type = type_str:gsub("%?", "")
    end
    
    -- If this is an optional type, return the optional icon immediately
    if is_optional then
        return "❔"
    end
    
    -- Handle array/table types (after optional check)
    if base_type:find("%[%]") or base_type:find("^table") or base_type:find("^array") then
        return "📋"
    end
    
    -- Handle generic types (after optional parsing to get clean base type)
    if base_type:find("<%w+>") then
        return "🔧"
    end
    
    -- Convert to lowercase for matching
    local lower_type = base_type:lower()
    
    -- Basic data types
    if lower_type == "string" then
        return "📝"
    elseif lower_type == "number" or lower_type == "integer" or lower_type == "float" then
        return "🔢"
    elseif lower_type == "boolean" or lower_type == "bool" then
        return "✅"
    elseif lower_type == "function" or lower_type == "callback" then
        return "⚡"
    elseif lower_type == "nil" or lower_type == "null" then
        return "🚫"
    elseif lower_type == "object" or lower_type == "userdata" then
        return "📦"
    elseif lower_type == "thread" then
        return "🧵"
    elseif lower_type == "any" then
        return "🌟"
    elseif lower_type == "void" then
        return "⭕"
    elseif lower_type == "unknown" then
        return "❓"
    else
        -- Custom types or class names
        return "🏷️"
    end
end

function utils.normalize_optional_type(type_str)
    -- Normalize optional type representations for consistent handling
    -- Converts type|nil to type? format for display consistency
    if not type_str or type_str == "" then
        return type_str
    end
    
    -- Handle union with nil: convert "type|nil" or "nil|type" to "type?"
    if type_str:find("|%s*nil") then
        local base_type = type_str:gsub("%s*|%s*nil", "")
        return base_type .. "?"
    elseif type_str:find("nil%s*|") then
        local base_type = type_str:gsub("nil%s*|%s*", "")
        return base_type .. "?"
    end
    
    -- Return unchanged if no normalization needed
    return type_str
end

function utils.is_optional_type(type_str)
    -- Check if a type is optional using any supported syntax
    if not type_str or type_str == "" then
        return false
    end
    
    -- Pattern 1: type?
    if type_str:find("%?") then
        return true
    end
    
    -- Pattern 2: type|nil or nil|type
    if type_str:find("|%s*nil") or type_str:find("nil%s*|") then
        return true
    end
    
    return false
end

function utils.get_base_type(type_str)
    -- Extract the base type from an optional type
    if not type_str or type_str == "" then
        return type_str
    end
    
    -- Remove ? suffix
    local base_type = type_str:gsub("%?$", "")
    
    -- Remove nil from union
    base_type = base_type:gsub("%s*|%s*nil", ""):gsub("nil%s*|%s*", "")
    
    return base_type
end

function utils.format_param_name_with_optional(param_name, param_type)
    -- Format parameter name with optional indicator
    -- Instead of showing "param?" we show "param (optional)"
    if utils.is_optional_type(param_type) then
        return param_name .. " <span class=\"optional-indicator\">(optional)</span>"
    else
        return param_name
    end
end

function utils.format_type_without_optional_suffix(type_str)
    -- Remove the ? suffix from type for cleaner display when using (optional) text
    if not type_str or type_str == "" then
        return type_str
    end
    
    -- Remove ? suffix but keep the base type
    local clean_type = type_str:gsub("%?$", "")
    
    -- For union with nil, convert to just the base type
    clean_type = clean_type:gsub("%s*|%s*nil", ""):gsub("nil%s*|%s*", "")
    
    return clean_type
end

function utils.trim(str)
    if not str then return "" end
    return str:match("^%s*(.-)%s*$")
end

function utils.split(str, delimiter)
    local result = {}
    local pattern = "[^" .. delimiter .. "]+"
    for match in str:gmatch(pattern) do
        table.insert(result, match)
    end
    return result
end

function utils.starts_with(str, prefix)
    return str:sub(1, #prefix) == prefix
end

function utils.ends_with(str, suffix)
    return str:sub(-#suffix) == suffix
end

function utils.file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

function utils.mkdir_p(path)
    local sep = package.config:sub(1,1) -- Get directory separator
    local dirs = utils.split(path, sep)
    local current = ""
    
    for i, dir in ipairs(dirs) do
        if i == 1 and sep == "\\" and dir:match("^%a:$") then
            current = dir .. sep
        else
            current = current .. dir
            if not utils.file_exists(current) then
                os.execute("mkdir \"" .. current .. "\"")
            end
            current = current .. sep
        end
    end
end

function utils.get_files_recursive(dir, extension, files)
    files = files or {}
    local command
    
    if package.config:sub(1,1) == "\\" then -- Windows
        -- Use cmd.exe explicitly for proper directory listing
        command = 'cmd /c dir "' .. dir .. '" /b /s 2>nul'
    else -- Unix-like
        command = 'find "' .. dir .. '" -name "*.' .. extension .. '" 2>/dev/null'
    end
    
    local handle = io.popen(command)
    if handle then
        for line in handle:lines() do
            line = utils.trim(line)
            if line ~= "" and utils.ends_with(line:lower(), "." .. extension:lower()) then
                table.insert(files, line)
            end
        end
        handle:close()
    end
    
    return files
end

-- Simple syntax highlighter
local function highlight_code(code, language)
    language = language or "lua"
    
    if language == "lua" then
        local result = {}
        local pos = 1
        local len = #code
        
        local keywords = {
            ["function"] = true, ["local"] = true, ["end"] = true, ["if"] = true,
            ["then"] = true, ["else"] = true, ["elseif"] = true, ["for"] = true,
            ["while"] = true, ["do"] = true, ["repeat"] = true, ["until"] = true,
            ["break"] = true, ["return"] = true, ["nil"] = true, ["true"] = true,
            ["false"] = true, ["and"] = true, ["or"] = true, ["not"] = true, ["in"] = true
        }
        
        while pos <= len do
            local char = code:sub(pos, pos)
            local remaining = code:sub(pos)
            local matched = false
            
            -- Preserve whitespace and newlines exactly
            if char:match("%s") then
                table.insert(result, char)
                pos = pos + 1
                matched = true
            
            -- Check for strings (double quotes) - handle escape sequences
            elseif char == '"' then
                local str_content = {}
                table.insert(str_content, char)
                pos = pos + 1
                local escaped = false
                
                while pos <= len do
                    local str_char = code:sub(pos, pos)
                    table.insert(str_content, str_char)
                    
                    if escaped then
                        escaped = false
                    elseif str_char == '\\' then
                        escaped = true
                    elseif str_char == '"' then
                        pos = pos + 1
                        break
                    end
                    pos = pos + 1
                end
                
                table.insert(result, '<span class="token string">' .. utils.escape_html(table.concat(str_content)) .. '</span>')
                matched = true
                
            -- Check for strings (single quotes)
            elseif char == "'" then
                local str_content = {}
                table.insert(str_content, char)
                pos = pos + 1
                local escaped = false
                
                while pos <= len do
                    local str_char = code:sub(pos, pos)
                    table.insert(str_content, str_char)
                    
                    if escaped then
                        escaped = false
                    elseif str_char == '\\' then
                        escaped = true
                    elseif str_char == "'" then
                        pos = pos + 1
                        break
                    end
                    pos = pos + 1
                end
                
                table.insert(result, '<span class="token string">' .. utils.escape_html(table.concat(str_content)) .. '</span>')
                matched = true
                
            -- Check for long strings [[...]]
            elseif remaining:match("^%[%[") then
                local str_end = code:find("%]%]", pos + 2)
                if str_end then
                    local str_content = code:sub(pos, str_end + 1)
                    table.insert(result, '<span class="token string">' .. utils.escape_html(str_content) .. '</span>')
                    pos = str_end + 2
                    matched = true
                end
                
            -- Check for comments
            elseif remaining:match("^%-%-") then
                local line_end = code:find("[\n\r]", pos) or len + 1
                local comment_content = code:sub(pos, line_end - 1)
                table.insert(result, '<span class="token comment">' .. utils.escape_html(comment_content) .. '</span>')
                pos = line_end
                matched = true
                
            -- Check for numbers
            elseif char:match("%d") or (char == "." and remaining:match("^%.%d")) then
                local num_match = remaining:match("^(%d+%.?%d*)")
                if not num_match then
                    num_match = remaining:match("^(%.%d+)")
                end
                if num_match then
                    table.insert(result, '<span class="token number">' .. utils.escape_html(num_match) .. '</span>')
                    pos = pos + #num_match
                    matched = true
                end
                
            -- Check for multi-character operators
            elseif remaining:match("^(==|~=|<=|>=|%.%.%.?|%:%:)") then
                local op_match = remaining:match("^(==|~=|<=|>=|%.%.%.?|%:%:)")
                table.insert(result, '<span class="token operator">' .. utils.escape_html(op_match) .. '</span>')
                pos = pos + #op_match
                matched = true
                
            -- Check for single-character operators
            elseif char:match("[+%-%*/%%=<>~#^]") then
                table.insert(result, '<span class="token operator">' .. utils.escape_html(char) .. '</span>')
                pos = pos + 1
                matched = true
                
            -- Check for punctuation
            elseif char:match("[%[%]{}();,]") then
                table.insert(result, '<span class="token punctuation">' .. utils.escape_html(char) .. '</span>')
                pos = pos + 1
                matched = true
                
            -- Check for identifiers (variables, functions, properties)
            elseif char:match("[%a_]") then
                local identifier = remaining:match("^([%w_][%w%d_]*)")
                if identifier then
                    local next_char_pos = pos + #identifier
                    local next_chars = code:sub(next_char_pos, next_char_pos + 2)
                    
                    if keywords[identifier] then
                        -- It's a keyword
                        table.insert(result, '<span class="token keyword">' .. utils.escape_html(identifier) .. '</span>')
                    elseif next_chars:match("^%s*%(") then
                        -- It's a function call
                        table.insert(result, '<span class="token function">' .. utils.escape_html(identifier) .. '</span>')
                    elseif code:sub(pos-1, pos-1):match("[%.:]") then
                        -- It's a property or method
                        table.insert(result, '<span class="token property">' .. utils.escape_html(identifier) .. '</span>')
                    else
                        -- It's a variable
                        table.insert(result, '<span class="token variable">' .. utils.escape_html(identifier) .. '</span>')
                    end
                    pos = pos + #identifier
                    matched = true
                end
                
            -- Check for dots and colons (property access)
            elseif char:match("[%.:]") then
                table.insert(result, '<span class="token punctuation">' .. utils.escape_html(char) .. '</span>')
                pos = pos + 1
                matched = true
            end
            
            -- If nothing matched, just add the character
            if not matched then
                table.insert(result, utils.escape_html(char))
                pos = pos + 1
            end
        end
        
        return table.concat(result)
    else
        -- For other languages, just escape HTML
        return utils.escape_html(code)
    end
end

-- Documentation parsing functions
local parser = {}

function parser.parse_comment_block(lines, start_line)
    local comment_block = {
        brief = "",
        description = "",
        class = nil,
        module = nil,
        namespace = nil,
        library = nil,
        core = nil,
        page = nil,
        sections = {},
        params = {},
        returns = {},
        fields = {},
        notes = {},
        see_also = {},
        tags = {},
        line_start = start_line,
        line_end = start_line
    }
    
    local current_description = {}
    local current_section = nil
    local current_code_block = nil
    local i = start_line
    
    while i <= #lines do
        local line = lines[i]
        local trimmed = utils.trim(line)
        
        -- Check if this is a documentation comment
        if not (utils.starts_with(trimmed, "--!") or utils.starts_with(trimmed, "---")) then
            break
        end
        
        comment_block.line_end = i
        
        -- Remove comment markers, preserving original indentation for code blocks
        local content = trimmed:gsub("^%-%-[!%-]%s*", "")
        local content_with_indent = line:gsub("^%s*%-%-[!%-]", "")
        
        -- Parse tags
        local tag_match = content:match("^[@\\](%w+)%s*(.*)")
        if tag_match then
            local tag = tag_match
            local value = utils.trim(content:match("^[@\\]%w+%s*(.*)") or "")
            
            if tag == "brief" then
                comment_block.brief = value
            elseif tag == "class" then
                comment_block.class = value
            elseif tag == "module" then
                comment_block.module = value
            elseif tag == "namespace" then
                comment_block.namespace = value
            elseif tag == "library" then
                comment_block.library = value
            elseif tag == "core" then
                comment_block.core = value
            elseif tag == "page" then
                comment_block.page = value
            elseif tag == "section" then
                -- Parse section tag: \section section_id Section Title
                local section_id, section_title = value:match("^(%w+)%s+(.*)")
                if section_id and section_title then
                    local new_section = {
                        id = section_id,
                        title = section_title,
                        content = {}
                    }
                    table.insert(comment_block.sections, new_section)
                    current_section = new_section
                end
            elseif tag == "code" then
                -- Start a code block with optional language
                current_code_block = {
                    language = value ~= "" and value or "lua",
                    lines = {}
                }
            elseif tag == "endcode" then
                -- End a code block and add it to current section or description
                if current_code_block then
                    local code_content = table.concat(current_code_block.lines, "\n")
                    local highlighted_code = highlight_code(code_content, current_code_block.language)
                    local code_html = string.format('<pre><code class="language-%s">%s</code></pre>', 
                        current_code_block.language, 
                        highlighted_code)
                    
                    if current_section then
                        table.insert(current_section.content, code_html)
                    else
                        table.insert(current_description, code_html)
                    end
                    current_code_block = nil
                end
            elseif tag == "param" then
                -- Enhanced param parsing to support union types and complex type definitions
                local param_pattern = "^[@\\]param%s+[@\\]?(%w+)%s+[@\\]?([%w%|%[%]%.%_%?%<%>%,\\]+)%s+(.*)"
                local param_name, param_type, param_desc = content:match(param_pattern)
                if not param_name then
                    param_pattern = "^[@\\]param%s+(%w+)%s+(.*)"
                    param_name, param_desc = content:match(param_pattern)
                    param_type = "unknown"
                end
                if param_name then
                    -- Clean up the type string (remove extra whitespace)
                    if param_type then
                        param_type = param_type:gsub("%s+", "")
                        -- Normalize optional type representation for consistency
                        param_type = utils.normalize_optional_type(param_type)
                    end
                    table.insert(comment_block.params, {
                        name = param_name,
                        type = param_type or "unknown",
                        description = param_desc or ""
                    })
                end
            elseif tag == "paramType" then
                -- Support for \paramType tag for complex return type definitions
                local param_type_pattern = "^[@\\]paramType%s+(%w+)%s+([%w%|%[%]%.%_%?%<%>%,\\]+)%s*(.*)"
                local param_name, param_type, param_desc = content:match(param_type_pattern)
                if param_name and param_type then
                    -- Clean up the type string
                    param_type = param_type:gsub("%s+", "")
                    -- Normalize optional type representation for consistency
                    param_type = utils.normalize_optional_type(param_type)
                    -- Find existing param entry or create new one
                    local existing_param = nil
                    for _, param in ipairs(comment_block.params) do
                        if param.name == param_name then
                            existing_param = param
                            break
                        end
                    end
                    if existing_param then
                        existing_param.type = param_type
                        if param_desc and param_desc ~= "" then
                            existing_param.description = param_desc
                        end
                    else
                        table.insert(comment_block.params, {
                            name = param_name,
                            type = param_type,
                            description = param_desc or ""
                        })
                    end
                end
            elseif tag == "return" then
                -- Enhanced return parsing to support multiple return values and union types
                -- Format 1: @return type1,type2,type3 description
                -- Format 2: @return type description (supports union types like string|nil)
                -- Format 3: @return description (type = unknown)
                
                -- Try to parse multiple return types separated by commas
                local multi_return_pattern = "^[@\\]return%s+[@\\]?([%w,_%.%[%]%|%?%<%>\\]+)%s+(.*)"
                local types_str, return_desc = content:match(multi_return_pattern)
                
                if types_str and types_str:find(",") then
                    -- Multiple return types found
                    local types = {}
                    for type_str in types_str:gmatch("([^,]+)") do
                        local cleaned_type = type_str:match("^%s*(.-)%s*$") -- trim whitespace
                        table.insert(types, cleaned_type)
                    end
                    
                    -- Create separate return entries for each type
                    for i, return_type in ipairs(types) do
                        -- Normalize optional type representation for consistency
                        return_type = utils.normalize_optional_type(return_type)
                        local desc = return_desc or ""
                        if #types > 1 then
                            desc = string.format("Return value %d: %s", i, desc)
                        end
                        table.insert(comment_block.returns, {
                            type = return_type or "unknown",
                            description = desc
                        })
                    end
                else
                    -- Single return type (enhanced to support union types)
                    local return_pattern = "^[@\\]return%s+[@\\]?([%w%|%[%]%.%_%?%<%>%,\\]+)%s+(.*)"
                    local return_type, return_desc = content:match(return_pattern)
                    if not return_type then
                        return_pattern = "^[@\\]return%s+(.*)"
                        return_desc = content:match(return_pattern)
                        return_type = "unknown"
                    else
                        -- Clean up the type string
                        return_type = return_type:gsub("%s+", "")
                        -- Normalize optional type representation for consistency
                        return_type = utils.normalize_optional_type(return_type)
                    end
                    table.insert(comment_block.returns, {
                        type = return_type or "unknown",
                        description = return_desc or ""
                    })
                end
            elseif tag == "field" then
                local field_pattern = "^[@\\]field%s+(%w+)%s+[@\\]?([%w%|%[%]%.%_%?%<%>%,\\]+)%s+(.*)"
                local field_name, field_type, field_desc = content:match(field_pattern)
                if not field_name then
                    field_pattern = "^[@\\]field%s+(%w+)%s+(.*)"
                    field_name, field_desc = content:match(field_pattern)
                    field_type = "unknown"
                end
                if field_name then
                    -- Clean up and normalize the field type
                    if field_type then
                        field_type = field_type:gsub("%s+", "")
                        field_type = utils.normalize_optional_type(field_type)
                    end
                    table.insert(comment_block.fields, {
                        name = field_name,
                        type = field_type or "unknown",
                        description = field_desc or ""
                    })
                end
            elseif tag == "note" then
                table.insert(comment_block.notes, value)
            elseif tag == "see" then
                table.insert(comment_block.see_also, value)
            else
                comment_block.tags[tag] = value
            end
        else
            -- Regular description content
            if content ~= "" or (current_code_block and content_with_indent ~= "") then
                if current_code_block then
                    -- Add content to the current code block with preserved indentation
                    table.insert(current_code_block.lines, content_with_indent)
                elseif current_section then
                    -- Add content to the current section
                    table.insert(current_section.content, content)
                else
                    -- Add content to general description
                    table.insert(current_description, content)
                end
            end
        end
        
        i = i + 1
    end
    
    if #current_description > 0 then
        comment_block.description = table.concat(current_description, " ")
    end
    
    return comment_block, i - 1
end

function parser.parse_function_signature(line)
    local func_pattern = "function%s+([%w%.%:]+)%s*%(([^)]*)%)"
    local name, params = line:match(func_pattern)
    
    if not name then
        -- Try alternative patterns
        func_pattern = "([%w%.%:]+)%s*=%s*function%s*%(([^)]*)%)"
        name, params = line:match(func_pattern)
    end
    
    if name then
        local param_list = {}
        if params and params ~= "" then
            for param in params:gmatch("([^,]+)") do
                table.insert(param_list, utils.trim(param))
            end
        end
        
        return {
            name = name,
            params = param_list,
            is_method = name:find(":") ~= nil
        }
    end
    
    return nil
end

function parser.parse_field_assignment(line, lines, current_index)
    -- Only parse field assignments at top level (not inside functions or deep indentation)
    local indent = line:match("^(%s*)")
    if #indent > 4 then  -- Skip heavily indented lines (likely inside functions)
        return nil
    end
    
    -- Pattern for field assignments like: MyTable.field = value or MyTable.field = "string"
    local patterns = {
        "([%w%.]+%.%w+)%s*=%s*(.-)%s*$", -- MyTable.field = value (capture everything to end of line)
        "([%w%.]+%[%s*['\"]%w+['\"]%s*%])%s*=%s*(.-)%s*$", -- MyTable["field"] = value
    }
    
    for _, pattern in ipairs(patterns) do
        local name, value = line:match(pattern)
        if name then
            value = utils.trim(value)
            
            -- Remove inline comments (-- at the end)
            value = value:gsub("%s*%-%-.*$", "")
            value = utils.trim(value)
            
            -- Skip assignments that are too complex (likely function calls)
            if #value > 200 then
                return nil
            end
            
            -- Check for multi-line table assignments
            if value:match("^{") and not value:match("}$") and lines and current_index then
                -- Read additional lines until we find the closing brace
                local brace_count = 1
                local i = current_index + 1
                local max_lines = 10  -- Limit multi-line parsing
                while i <= #lines and brace_count > 0 and (i - current_index) < max_lines do
                    local next_line = lines[i]
                    value = value .. " " .. utils.trim(next_line)
                    
                    -- Count braces to find the end
                    local open_braces = select(2, next_line:gsub("{", ""))
                    local close_braces = select(2, next_line:gsub("}", ""))
                    brace_count = brace_count + open_braces - close_braces
                    
                    i = i + 1
                end
            end
            
            -- Infer type from value
            local field_type = "unknown"
            
            if value:match("^['\"].*['\"]$") then
                field_type = "string"
            elseif value:match("^%d+$") then
                field_type = "number"
            elseif value:match("^%d*%.%d+$") then
                field_type = "number"
            elseif value == "true" or value == "false" then
                field_type = "boolean"
            elseif value:match("^{.*}$") then
                field_type = "table"
            elseif value:match("^function") then
                field_type = "function"
            end
            
            return {
                name = name,
                type = field_type,
                value = value,
                inferred = true,  -- This will be set to false if documentation is found
                undocumented = true  -- This will be set to false if documentation is found
            }
        end
    end
    
    return nil
end

function parser.parse_table_assignment(line)
    local table_pattern = "([%w%.]+)%s*=%s*{}"
    local name = line:match(table_pattern)
    
    if name then
        return {
            name = name,
            type = "table"
        }
    end
    
    return nil
end

function parser.parse_file(filepath)
    local file = io.open(filepath, "r")
    if not file then
        print("Warning: Could not open file " .. filepath)
        return nil
    end
    
    local lines = {}
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()
    
    local file_doc = {
        path = filepath,
        functions = {},
        tables = {},
        classes = {},
        modules = {},
        libraries = {},
        cores = {},
        comments = {},
        fields = {},
        pages = {}
    }
    
    local i = 1
    while i <= #lines do
        local line = lines[i]
        local trimmed = utils.trim(line)
        
        -- Check for documentation comments
        if utils.starts_with(trimmed, "--!") or utils.starts_with(trimmed, "---") then
            local comment_block, end_line = parser.parse_comment_block(lines, i)
            table.insert(file_doc.comments, comment_block)
            
            -- Check for page tag (pages don't need associated code)
            if comment_block.page then
                local page_info = {
                    name = comment_block.page,
                    documentation = comment_block,
                    line = i
                }
                table.insert(file_doc.pages, page_info)
            end
            
            -- Look for associated code on the next non-empty line
            local next_line_idx = end_line + 1
            while next_line_idx <= #lines and utils.trim(lines[next_line_idx]) == "" do
                next_line_idx = next_line_idx + 1
            end
            
            if next_line_idx <= #lines then
                local next_line = lines[next_line_idx]
                local func_sig = parser.parse_function_signature(next_line)
                local table_assign = parser.parse_table_assignment(next_line)
                local field_assign = parser.parse_field_assignment(next_line, lines, next_line_idx)
                
                if func_sig then
                    func_sig.documentation = comment_block
                    func_sig.line = next_line_idx
                    table.insert(file_doc.functions, func_sig)
                elseif table_assign then
                    table_assign.documentation = comment_block
                    table_assign.line = next_line_idx
                    table.insert(file_doc.tables, table_assign)
                    
                    -- Also treat documented table assignments as fields for documentation purposes
                    if comment_block.brief or (comment_block.fields and #comment_block.fields > 0) then
                        -- Convert table assignment to field format
                        local field_obj = {
                            name = table_assign.name,
                            type = "table",
                            value = "{}",
                            documentation = comment_block,
                            line = next_line_idx,
                            inferred = false,
                            undocumented = false
                        }
                        
                        -- Apply same field documentation logic as field assignments
                        local field_doc_found = false
                        
                        -- Check for \field tag matching the field name
                        if comment_block.fields and #comment_block.fields > 0 then
                            for _, field_info in ipairs(comment_block.fields) do
                                local field_matches = false
                                
                                if field_info.name == field_obj.name then
                                    field_matches = true
                                elseif field_obj.name:match("%." .. field_info.name .. "$") then
                                    field_matches = true
                                else
                                    local last_component = field_obj.name:match("%.([^%.]+)$")
                                    if last_component and last_component == field_info.name then
                                        field_matches = true
                                    end
                                end
                                
                                if field_matches then
                                    field_obj.description = field_info.description
                                    field_obj.type = field_info.type
                                    field_doc_found = true
                                    break
                                end
                            end
                        end
                        
                        -- Fall back to \brief tag if no \field tag matched
                        if not field_doc_found and comment_block.brief then
                            field_obj.description = comment_block.brief
                        end
                        
                        table.insert(file_doc.fields, field_obj)
                    end
                elseif field_assign then
                    field_assign.documentation = comment_block
                    field_assign.line = next_line_idx
                    
                    -- Check for field documentation in order of preference:
                    -- 1. \field tag matching the field name
                    -- 2. \brief tag (fallback for general descriptions)
                    local field_doc_found = false
                    
                    -- First, check if we have a \field tag that matches this field assignment
                    if comment_block.fields and #comment_block.fields > 0 then
                        for _, field_info in ipairs(comment_block.fields) do
                            -- Try multiple matching strategies:
                            -- 1. Exact match: field_info.name == field_assign.name
                            -- 2. End match: field_assign.name ends with field_info.name (e.g., "FrameworkZ.Foundation" ends with "Foundation")
                            -- 3. Last component match: last part of field_assign.name matches field_info.name
                            local field_matches = false
                            
                            if field_info.name == field_assign.name then
                                -- Exact match
                                field_matches = true
                            elseif field_assign.name:match("%." .. field_info.name .. "$") then
                                -- End match (e.g., "FrameworkZ.Foundation" ends with ".Foundation")
                                field_matches = true
                            else
                                -- Last component match (extract last part after final dot)
                                local last_component = field_assign.name:match("%.([^%.]+)$")
                                if last_component and last_component == field_info.name then
                                    field_matches = true
                                end
                            end
                            
                            if field_matches then
                                field_assign.description = field_info.description
                                field_assign.type = field_info.type
                                field_assign.inferred = false
                                field_assign.undocumented = false
                                field_doc_found = true
                                break
                            end
                        end
                    end
                    
                    -- If no \field tag matched, fall back to \brief tag
                    if not field_doc_found and comment_block.brief then
                        field_assign.description = comment_block.brief
                        field_assign.inferred = false
                        field_assign.undocumented = false
                        -- Keep the initial value that was parsed
                        -- field_assign.value is already set by parse_field_assignment
                    end
                    
                    table.insert(file_doc.fields, field_assign)
                end
                
                -- Handle explicit field documentation (from \field tags) only if they weren't connected to assignments
                if comment_block.fields and #comment_block.fields > 0 then
                    for _, field_info in ipairs(comment_block.fields) do
                        -- Only add standalone field documentation if no field assignment was found with this name
                        local assignment_found = false
                        for _, existing_field in ipairs(file_doc.fields) do
                            if existing_field.name == field_info.name and existing_field.line == next_line_idx then
                                assignment_found = true
                                break
                            end
                        end
                        
                        if not assignment_found then
                            table.insert(file_doc.fields, {
                                name = field_info.name,
                                type = field_info.type,
                                description = field_info.description,
                                documentation = comment_block,
                                line = next_line_idx,
                                inferred = false,
                                undocumented = false
                            })
                        end
                    end
                end
                
                -- Handle class/module/library declarations
                if comment_block.class then
                    local class_info = {
                        name = comment_block.class,
                        documentation = comment_block,
                        line = next_line_idx,
                        functions = {},
                        fields = comment_block.fields or {}
                    }
                    table.insert(file_doc.classes, class_info)
                end
                
                if comment_block.module then
                    local module_info = {
                        name = comment_block.module,
                        documentation = comment_block,
                        line = next_line_idx,
                        functions = {},
                        tables = {}
                    }
                    table.insert(file_doc.modules, module_info)
                end
                
                -- Check for library tag
                if comment_block.library then
                    local library_info = {
                        name = comment_block.library,
                        documentation = comment_block,
                        line = next_line_idx,
                        functions = {},
                        tables = {}
                    }
                    table.insert(file_doc.libraries, library_info)
                end
                
                -- Check for core tag
                if comment_block.core then
                    local core_info = {
                        name = comment_block.core,
                        documentation = comment_block,
                        line = next_line_idx,
                        functions = {},
                        tables = {}
                    }
                    table.insert(file_doc.cores, core_info)
                end
            end
            
            i = end_line + 1
        else
            -- Look for undocumented code patterns
            local func_sig = parser.parse_function_signature(trimmed)
            local table_assign = parser.parse_table_assignment(trimmed)
            local field_assign = parser.parse_field_assignment(trimmed, lines, i)
            
            if func_sig then
                -- Check if this function is already documented
                local already_documented = false
                for _, existing_func in ipairs(file_doc.functions) do
                    if existing_func.name == func_sig.name then
                        already_documented = true
                        break
                    end
                end
                
                if not already_documented then
                    func_sig.line = i
                    func_sig.undocumented = true
                    table.insert(file_doc.functions, func_sig)
                end
            elseif table_assign then
                -- Check if this table is already documented
                local already_documented = false
                for _, existing_table in ipairs(file_doc.tables) do
                    if existing_table.name == table_assign.name then
                        already_documented = true
                        break
                    end
                end
                
                if not already_documented then
                    table_assign.line = i
                    table_assign.undocumented = true
                    table.insert(file_doc.tables, table_assign)
                end
            elseif field_assign then
                -- Check if this field is already documented
                local already_documented = false
                for _, existing_field in ipairs(file_doc.fields) do
                    if existing_field.name == field_assign.name then
                        already_documented = true
                        break
                    end
                end
                
                if not already_documented then
                    field_assign.line = i
                    field_assign.undocumented = true
                    table.insert(file_doc.fields, field_assign)
                end
            end
            
            i = i + 1
        end
    end
    
    return file_doc
end

-- Sorting utility
local function sort_alphabetically(items, key)
    if not key then
        key = "name"
    end
    table.sort(items, function(a, b)
        local a_name = a[key] or ""
        local b_name = b[key] or ""
        return a_name:lower() < b_name:lower()
    end)
    return items
end

-- HTML generation functions
local html_generator = {}

function html_generator.get_css()
    return [[
<style>
:root {
    --primary-color: #2c3e50;
    --secondary-color: #3498db;
    --accent-color: #e74c3c;
    --success-color: #27ae60;
    --warning-color: #f39c12;
    --info-color: #17a2b8;
    --light-bg: #f8f9fa;
    --border-color: #e9ecef;
    --text-color: #333;
    --text-muted: #6c757d;
    --sidebar-width: clamp(250px, 20vw, 350px);
    --toc-width: clamp(200px, 15vw, 300px);
}

* {
    box-sizing: border-box;
}

body {
    font-family: 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', sans-serif;
    line-height: 1.6;
    margin: 0;
    padding: 0;
    background-color: #f5f7fa;
    color: var(--text-color);
    font-size: 14px;
}

.layout {
    display: flex;
    min-height: 100vh;
    width: 100%;
    overflow-x: hidden;
}

.sidebar {
    width: var(--sidebar-width);
    min-width: var(--sidebar-width);
    background: linear-gradient(135deg, var(--primary-color) 0%, #34495e 100%);
    color: white;
    padding: 0;
    position: fixed;
    left: 0;
    top: 0;
    height: 100vh;
    overflow-y: auto;
    box-shadow: 2px 0 10px rgba(0,0,0,0.1);
    z-index: 1000;
}
    top: 0;
}

.sidebar-header {
    padding: 1.5rem;
    border-bottom: 1px solid rgba(255,255,255,0.1);
}

.sidebar-header h1 {
    margin: 0;
    font-size: 1.4rem;
    font-weight: 600;
}

.sidebar-header .subtitle {
    margin: 0.5rem 0 0 0;
    opacity: 0.8;
    font-size: 0.85rem;
}

.sidebar-nav {
    padding: 1rem 0;
}

.nav-section {
    margin-bottom: 1.5rem;
}

.nav-section-title {
    padding: 0.5rem 1.5rem;
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: rgba(255,255,255,0.7);
    margin-bottom: 0.5rem;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: space-between;
    transition: all 0.2s ease;
    user-select: none;
}

.nav-section-title:hover {
    color: rgba(255,255,255,0.9);
    background-color: rgba(255,255,255,0.05);
}

.nav-section-title .collapse-icon {
    font-size: 0.8rem;
    transition: transform 0.2s ease;
}

.nav-section.collapsed .collapse-icon {
    transform: rotate(-90deg);
}

.nav-section.collapsed .nav-links {
    display: none;
}

.nav-links {
    list-style: none;
    margin: 0;
    padding: 0;
}

.nav-links li {
    margin: 0;
}

.nav-links a {
    display: flex;
    align-items: center;
    color: rgba(255,255,255,0.9);
    text-decoration: none;
    padding: 0.75rem 1.5rem;
    transition: all 0.2s ease;
    border-left: 3px solid transparent;
    font-size: 0.9rem;
    word-wrap: break-word;
    overflow-wrap: break-word;
    hyphens: auto;
}

.nav-links a .nav-icon {
    margin-right: 0.5rem;
    flex-shrink: 0;
    font-size: 0.8rem;
}

.nav-links a .nav-text {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
}

.nav-links a:hover {
    background-color: rgba(255,255,255,0.1);
    border-left-color: var(--secondary-color);
    color: white;
}

.nav-links a.active {
    background-color: rgba(52, 152, 219, 0.2);
    border-left-color: var(--secondary-color);
    color: white;
}

.main-content {
    flex: 1;
    margin-left: var(--sidebar-width);
    margin-right: var(--toc-width);
    background-color: white;
    min-width: 0;
    overflow-x: hidden;
}

.content-header {
    background: linear-gradient(135deg, white 0%, var(--light-bg) 100%);
    padding: 2rem;
    border-bottom: 1px solid var(--border-color);
}

.content-header h1 {
    margin: 0;
    font-size: 2.2rem;
    color: var(--primary-color);
    font-weight: 300;
}

.content-header .breadcrumb {
    margin-top: 0.5rem;
    color: var(--text-muted);
    font-size: 0.9rem;
}

.content-header .breadcrumb a {
    color: var(--secondary-color);
    text-decoration: none;
}

.content-header .breadcrumb a:hover {
    text-decoration: underline;
}

.content {
    padding: 2rem;
    width: 100%;
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
}

.class-overview {
    background: linear-gradient(135deg, var(--light-bg) 0%, white 100%);
    border: 1px solid var(--border-color);
    border-radius: 8px;
    padding: 2rem;
    margin-bottom: 2rem;
    box-shadow: 0 2px 8px rgba(0,0,0,0.05);
}

.class-overview h2 {
    margin-top: 0;
    color: var(--primary-color);
    font-size: 1.8rem;
    font-weight: 400;
}

.class-meta {
    display: flex;
    gap: 1rem;
    margin: 1rem 0;
    flex-wrap: wrap;
}

.meta-badge {
    background-color: var(--secondary-color);
    color: white;
    padding: 0.25rem 0.75rem;
    border-radius: 15px;
    font-size: 0.8rem;
    font-weight: 500;
}

.meta-badge.module {
    background-color: var(--success-color);
}

.meta-badge.namespace {
    background-color: var(--warning-color);
}

.section {
    margin-bottom: 3rem;
}

.section-header {
    display: flex;
    align-items: center;
    margin-bottom: 1.5rem;
    padding-bottom: 0.5rem;
    border-bottom: 2px solid var(--border-color);
}

.section-header h3 {
    margin: 0;
    font-size: 1.4rem;
    color: var(--primary-color);
    font-weight: 500;
}

.section-content {
    color: var(--text-muted);
    line-height: 1.7;
    margin-bottom: 1rem;
}

/* Enhanced page section styling */
.section-content h4 {
    color: var(--primary-color);
    margin: 1.5rem 0 0.75rem 0;
    font-size: 1.1rem;
    font-weight: 600;
}

.section-content h5 {
    color: var(--secondary-color);
    margin: 1rem 0 0.5rem 0;
    font-size: 1rem;
    font-weight: 500;
}

.section-content ul, .section-content ol {
    margin: 1rem 0;
    padding-left: 2rem;
}

.section-content li {
    margin: 0.5rem 0;
}

.section-content blockquote {
    background-color: var(--light-bg);
    border-left: 4px solid var(--secondary-color);
    margin: 1rem 0;
    padding: 1rem 1.5rem;
    font-style: italic;
    color: var(--text-muted);
}

.section-header .section-count {
    margin-left: auto;
    background-color: var(--secondary-color);
    color: white;
    padding: 0.25rem 0.75rem;
    border-radius: 12px;
    font-size: 0.8rem;
    font-weight: 500;
}

.function-card, .method-card {
    background: white;
    border: 1px solid var(--border-color);
    border-radius: 8px;
    margin-bottom: 1.5rem;
    overflow: hidden;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
    transition: box-shadow 0.2s ease;
}

.function-card:hover, .method-card:hover {
    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.function-header {
    background: linear-gradient(135deg, var(--light-bg) 0%, #f1f3f4 100%);
    padding: 1rem 1.5rem;
    border-bottom: 1px solid var(--border-color);
    display: flex;
    align-items: flex-start;
    justify-content: flex-start;
    flex-wrap: nowrap;
    gap: 1rem;
    min-height: fit-content;
}

.function-signature {
    font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
    font-size: 1rem;
    color: var(--primary-color);
    font-weight: 600;
    margin: 0;
    word-break: break-all;
    flex: 0 1 auto;
    min-width: 0;
    margin-right: auto;
}

.function-badges {
    display: flex;
    gap: 0.5rem;
    align-items: flex-start;
    flex: 0 0 auto;
    flex-wrap: wrap;
    justify-content: flex-start;
    min-width: fit-content;
    width: auto;
}

.function-type {
    display: inline-block;
    background-color: var(--secondary-color);
    color: white;
    padding: 0.2rem 0.6rem;
    border-radius: 12px;
    font-size: 0.75rem;
    font-weight: 500;
    vertical-align: middle;
    white-space: nowrap;
    width: fit-content;
    min-width: fit-content;
    max-width: fit-content;
    flex: none;
    box-sizing: border-box;
}

.function-type.method {
    background-color: var(--accent-color);
}

.function-type.undocumented {
    background-color: var(--warning-color);
}

.function-body {
    padding: 1.5rem;
}

.function-brief {
    font-size: 1.1rem;
    color: var(--text-color);
    margin-bottom: 1rem;
    font-weight: 500;
}

.function-description {
    color: var(--text-muted);
    margin-bottom: 1.5rem;
    line-height: 1.7;
}

.parameters-section, .returns-section {
    margin: 1.5rem 0;
}

.parameters-section h4, .returns-section h4 {
    color: var(--primary-color);
    margin-bottom: 1rem;
    font-size: 1.1rem;
    font-weight: 600;
}

.param-grid, .return-grid {
    display: grid;
    gap: 0.75rem;
}

.param-item, .return-item {
    background-color: var(--light-bg);
    padding: 1rem;
    border-radius: 6px;
    border-left: 4px solid var(--secondary-color);
}

.param-header, .return-header {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    margin-bottom: 0.5rem;
}

.param-name, .return-type {
    font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
    font-weight: 600;
    color: var(--accent-color);
    font-size: 0.9rem;
}

.optional-indicator {
    font-family: 'Segoe UI', 'Roboto', sans-serif;
    font-weight: 400;
    color: #999;
    font-size: 0.8rem;
    font-style: italic;
}

.param-type {
    font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
    color: var(--success-color);
    font-size: 0.85rem;
    background-color: rgba(39, 174, 96, 0.1);
    padding: 0.2rem 0.5rem;
    border-radius: 4px;
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
}

.return-type {
    font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
    color: var(--info-color);
    font-size: 0.85rem;
    background-color: rgba(52, 152, 219, 0.1);
    padding: 0.2rem 0.5rem;
    border-radius: 4px;
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
}

.type-icon {
    font-size: 0.9rem;
    opacity: 0.8;
}

.param-description, .return-description {
    color: var(--text-muted);
    font-size: 0.9rem;
    line-height: 1.5;
}

.notes-section, .see-also-section {
    margin: 1.5rem 0;
    padding: 1rem;
    border-radius: 6px;
}

.notes-section {
    background-color: #fff3cd;
    border-left: 4px solid var(--warning-color);
}

.see-also-section {
    background-color: #d1ecf1;
    border-left: 4px solid var(--info-color);
}

.notes-section h4, .see-also-section h4 {
    margin-top: 0;
    margin-bottom: 0.75rem;
    font-size: 1rem;
    font-weight: 600;
}

.notes-section h4 {
    color: #856404;
}

.see-also-section h4 {
    color: #0c5460;
}

.toc {
    background: linear-gradient(135deg, var(--light-bg) 0%, white 100%);
    border: 1px solid var(--border-color);
    border-radius: 8px;
    padding: 1.5rem;
    margin-bottom: 2rem;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
}

.toc h3 {
    margin-top: 0;
    margin-bottom: 1rem;
    color: var(--primary-color);
    font-size: 1.3rem;
    font-weight: 500;
}

.toc-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 1rem;
}

.toc-section {
    background-color: white;
    padding: 1rem;
    border-radius: 6px;
    border: 1px solid var(--border-color);
}

.toc-section h4 {
    margin-top: 0;
    margin-bottom: 0.75rem;
    color: var(--primary-color);
    font-size: 1rem;
}

.toc-section ul {
    list-style: none;
    padding: 0;
    margin: 0;
}

.toc-section li {
    margin: 0.25rem 0;
}

.toc-section a {
    color: var(--secondary-color);
    text-decoration: none;
    font-size: 0.9rem;
    display: block;
    padding: 0.25rem 0;
    border-radius: 3px;
    transition: all 0.2s ease;
}

.toc-section a:hover {
    background-color: var(--light-bg);
    padding-left: 0.5rem;
}

.file-path {
    font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
    background-color: var(--light-bg);
    padding: 0.3rem 0.6rem;
    border-radius: 4px;
    font-size: 0.85rem;
    color: var(--text-muted);
    display: inline-block;
}

.undocumented {
    opacity: 0.6;
    font-style: italic;
}

.undocumented:not(.function-type)::after {
    content: " (undocumented)";
    color: var(--warning-color);
    font-size: 0.8rem;
}

pre {
    background-color: #1e1e1e;
    border: 1px solid #333;
    border-radius: 6px;
    padding: 1.5rem;
    overflow-x: auto;
    font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
    font-size: 0.9rem;
    line-height: 1.5;
    white-space: pre;
    tab-size: 4;
    color: #d4d4d4;
}

/* Syntax highlighting for code blocks - VS Code Dark Theme */
.token.keyword { color: #569cd6; font-weight: normal; }
.token.string { color: #ce9178; }
.token.comment { color: #6a9955; font-style: italic; }
.token.number { color: #b5cea8; }
.token.function { color: #dcdcaa; font-weight: normal; }
.token.operator { color: #d4d4d4; }
.token.punctuation { color: #d4d4d4; }
.token.variable { color: #9cdcfe; }
.token.property { color: #9cdcfe; }

/* Language-specific overrides for Lua */
.language-lua .token.keyword { color: #569cd6; }
.language-lua .token.string { color: #ce9178; }
.language-lua .token.comment { color: #6a9955; font-style: italic; }
.language-lua .token.number { color: #b5cea8; }
.language-lua .token.function { color: #dcdcaa; }
.language-lua .token.operator { color: #d4d4d4; }
.language-lua .token.punctuation { color: #d4d4d4; }
.language-lua .token.variable { color: #9cdcfe; }

.language-javascript .token.keyword { color: #569cd6; }
.language-javascript .token.string { color: #ce9178; }
.language-javascript .token.comment { color: #6a9955; font-style: italic; }
.language-javascript .token.number { color: #b5cea8; }
.language-javascript .token.function { color: #dcdcaa; }
.language-javascript .token.operator { color: #d4d4d4; }

.language-html .token.tag { color: #569cd6; }
.language-html .token.attr-name { color: #9cdcfe; }
.language-html .token.attr-value { color: #ce9178; }
.language-html .token.punctuation { color: #d4d4d4; }

.language-css .token.property { color: #9cdcfe; }
.language-css .token.selector { color: #d7ba7d; }
.language-css .token.string { color: #ce9178; }
.language-css .token.number { color: #b5cea8; }

code {
    background-color: var(--light-bg);
    padding: 0.2rem 0.4rem;
    border-radius: 3px;
    font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
    font-size: 0.9rem;
    color: var(--accent-color);
}

/* Code block in pre elements should not have background */
pre code {
    background: none;
    padding: 0;
}

.stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
    margin: 2rem 0;
}

.stat-card {
    background: linear-gradient(135deg, white 0%, var(--light-bg) 100%);
    padding: 1.5rem;
    border-radius: 8px;
    border: 1px solid var(--border-color);
    text-align: center;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
}

.stat-number {
    font-size: 2rem;
    font-weight: 600;
    color: var(--secondary-color);
    display: block;
}

.stat-label {
    color: var(--text-muted);
    font-size: 0.9rem;
    margin-top: 0.5rem;
}

@media (max-width: 768px) {
    .sidebar {
        transform: translateX(-100%);
        transition: transform 0.3s ease;
    }
    
    .sidebar.open {
        transform: translateX(0);
    }
    
    .main-content {
        margin-left: 0;
    }
    
    .content {
        padding: 1rem;
    }
    
    .content-header {
        padding: 1rem;
    }
    
    .toc-grid {
        grid-template-columns: 1fr;
    }
    
    .stats-grid {
        grid-template-columns: repeat(2, 1fr);
    }
}

.search-box {
    margin: 1rem 1.5rem;
    position: relative;
}

.search-input {
    width: 100%;
    padding: 0.75rem;
    border: 1px solid rgba(255,255,255,0.2);
    background-color: rgba(255,255,255,0.1);
    color: white;
    border-radius: 6px;
    font-size: 0.9rem;
}

.search-input::placeholder {
    color: rgba(255,255,255,0.7);
}

.search-input:focus {
    outline: none;
    border-color: var(--secondary-color);
    background-color: rgba(255,255,255,0.15);
}

/* Smooth scrolling */
html {
    scroll-behavior: smooth;
}

/* Clickable stat cards */
.stat-card.clickable {
    cursor: pointer;
    transition: transform 0.2s ease, box-shadow 0.2s ease;
}

.stat-card.clickable:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
}

.stat-card.clickable:active {
    transform: translateY(0);
}

/* Right sidebar table of contents */
#toc-container {
    position: fixed;
    top: 20px;
    right: 20px;
    width: calc(var(--toc-width) - 40px);
    height: calc(100vh - 40px);
    overflow-y: auto;
    overflow-x: hidden;
    padding: 0;
    box-sizing: border-box;
    z-index: 100;
}

.page-toc {
    width: 100%;
    height: fit-content;
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(10px);
    border: 1px solid var(--border-color);
    border-radius: 8px;
    padding: 1rem;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    position: sticky;
    top: 20px;
}

.page-toc h4 {
    margin: 0 0 0.75rem 0;
    font-size: 0.9rem;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    font-weight: 600;
}

.page-toc ul {
    list-style: none;
    margin: 0;
    padding: 0;
}

.page-toc li {
    margin: 0;
    padding: 0;
}

.page-toc a {
    display: block;
    padding: 0.4rem 0.75rem;
    color: var(--text-color);
    text-decoration: none;
    font-size: 0.85rem;
    border-radius: 4px;
    transition: all 0.2s ease;
    border-left: 3px solid transparent;
}

.page-toc a:hover {
    background-color: rgba(52, 152, 219, 0.1);
    color: var(--info-color);
    border-left-color: rgba(52, 152, 219, 0.3);
}

.page-toc a.active {
    background-color: rgba(52, 152, 219, 0.15);
    color: var(--info-color);
    border-left-color: #e74c3c;
    font-weight: 500;
}

.page-toc .toc-count {
    float: right;
    background: var(--light-bg);
    color: var(--text-muted);
    font-size: 0.75rem;
    padding: 0.1rem 0.4rem;
    border-radius: 10px;
    margin-left: 0.5rem;
}

.page-toc a.active .toc-count {
    background: rgba(231, 76, 60, 0.2);
    color: var(--info-color);
}

.page-toc .toc-sub-items {
    margin-left: 1rem;
    margin-top: 0.25rem;
    border-left: 2px solid rgba(52, 152, 219, 0.2);
    padding-left: 0.5rem;
}

.page-toc .toc-sub-items li {
    margin: 0;
}

.page-toc .toc-sub-items a {
    padding: 0.2rem 0.5rem;
    font-size: 0.8rem;
    color: var(--text-muted);
    border-left: none;
}

.page-toc .toc-sub-items a:hover {
    color: var(--info-color);
    background-color: rgba(52, 152, 219, 0.05);
}

.page-toc .toc-sub-items a.active {
    background-color: rgba(52, 152, 219, 0.1);
    color: var(--info-color);
    font-weight: 500;
}

/* Responsive breakpoints */
@media (max-width: 1400px) {
    :root {
        --sidebar-width: clamp(220px, 18vw, 280px);
        --toc-width: clamp(180px, 12vw, 250px);
    }
}

@media (max-width: 1200px) {
    :root {
        --sidebar-width: clamp(200px, 20vw, 260px);
    }
    
    .main-content {
        margin-right: 0;
    }
    
    #toc-container {
        display: none;
    }
}

@media (max-width: 768px) {
    .sidebar {
        display: none;
    }
    
    .main-content {
        margin-left: 0;
        margin-right: 0;
    }
    
    .content {
        padding: 1rem;
    }
    
    .content-header {
        padding: 1rem;
    }
    
    .content-header h1 {
        font-size: 1.8rem;
    }
}

@media (min-width: 1600px) {
    :root {
        --sidebar-width: min(20vw, 450px);
        --toc-width: min(22vw, 400px);
        --content-max-width: min(65vw, 1400px);
    }
}
</style>
]]
end

function html_generator.generate_html_header(title, subtitle, navigation_items, current_page)
    navigation_items = navigation_items or {}
    current_page = current_page or ""
    
    local nav_html = {}
    
    -- Overview section
    table.insert(nav_html, '<div class="nav-section" data-section="overview">')
    table.insert(nav_html, '<div class="nav-section-title" onclick="toggleNavSection(this)">Overview<span class="collapse-icon">▼</span></div>')
    table.insert(nav_html, '<ul class="nav-links">')
    table.insert(nav_html, string.format('<li><a href="index.html"%s><span class="nav-icon">🏠</span><span class="nav-text">Home</span></a></li>', 
        current_page == "index" and ' class="active"' or ''))
    table.insert(nav_html, string.format('<li><a href="all-functions.html"%s><span class="nav-icon">📋</span><span class="nav-text">All Functions</span></a></li>', 
        current_page == "all-functions" and ' class="active"' or ''))
    table.insert(nav_html, '</ul>')
    table.insert(nav_html, '</div>')
    
    -- Pages section (for custom tagged pages)
    if navigation_items.pages and #navigation_items.pages > 0 then
        table.insert(nav_html, '<div class="nav-section collapsed" data-section="pages">')
        table.insert(nav_html, '<div class="nav-section-title" onclick="toggleNavSection(this)">Pages<span class="collapse-icon">▼</span></div>')
        table.insert(nav_html, '<ul class="nav-links">')
        for _, page in ipairs(navigation_items.pages) do
            local page_file = page.name:gsub("%.", "_"):gsub("%s+", "_"):lower() .. "_page.html"
            local page_name = page.name
            local is_current = current_page == page_name
            table.insert(nav_html, string.format('<li><a href="%s"%s><span class="nav-icon">📄</span><span class="nav-text">%s</span></a></li>', 
                page_file, 
                is_current and ' class="active"' or '', 
                utils.escape_html(page_name)))
        end
        table.insert(nav_html, '</ul>')
        table.insert(nav_html, '</div>')
    end
    
    -- Cores section
    if navigation_items.cores and #navigation_items.cores > 0 then
        table.insert(nav_html, '<div class="nav-section collapsed" data-section="cores">')
        table.insert(nav_html, '<div class="nav-section-title" onclick="toggleNavSection(this)">Core Systems<span class="collapse-icon">▼</span></div>')
        table.insert(nav_html, '<ul class="nav-links">')
        for _, core in ipairs(navigation_items.cores) do
            local core_file = core.name:gsub("%.", "_") .. "_core.html"
            local is_active = current_page == core_file and ' class="active"' or ''
            table.insert(nav_html, string.format('<li><a href="%s"%s><span class="nav-icon">⚡</span><span class="nav-text">%s</span></a></li>', 
                core_file, is_active, utils.escape_html(core.name)))
        end
        table.insert(nav_html, '</ul>')
        table.insert(nav_html, '</div>')
    end
    
    -- Classes section
    if navigation_items.classes and #navigation_items.classes > 0 then
        table.insert(nav_html, '<div class="nav-section collapsed" data-section="classes">')
        table.insert(nav_html, '<div class="nav-section-title" onclick="toggleNavSection(this)">Classes<span class="collapse-icon">▼</span></div>')
        table.insert(nav_html, '<ul class="nav-links">')
        for _, class in ipairs(navigation_items.classes) do
            local class_file = class.name:gsub("%.", "_") .. ".html"
            local is_active = current_page == class_file and ' class="active"' or ''
            table.insert(nav_html, string.format('<li><a href="%s"%s><span class="nav-icon">📦</span><span class="nav-text">%s</span></a></li>', 
                class_file, is_active, utils.escape_html(class.name)))
        end
        table.insert(nav_html, '</ul>')
        table.insert(nav_html, '</div>')
    end
    
    -- Libraries section
    if navigation_items.libraries and #navigation_items.libraries > 0 then
        table.insert(nav_html, '<div class="nav-section collapsed" data-section="libraries">')
        table.insert(nav_html, '<div class="nav-section-title" onclick="toggleNavSection(this)">Libraries<span class="collapse-icon">▼</span></div>')
        table.insert(nav_html, '<ul class="nav-links">')
        for _, library in ipairs(navigation_items.libraries) do
            local library_file = library.name:gsub("%.", "_") .. "_library.html"
            local is_active = current_page == library_file and ' class="active"' or ''
            table.insert(nav_html, string.format('<li><a href="%s"%s><span class="nav-icon">📚</span><span class="nav-text">%s</span></a></li>', 
                library_file, is_active, utils.escape_html(library.name)))
        end
        table.insert(nav_html, '</ul>')
        table.insert(nav_html, '</div>')
    end
    
    -- Modules section
    if navigation_items.modules and #navigation_items.modules > 0 then
        table.insert(nav_html, '<div class="nav-section collapsed" data-section="modules">')
        table.insert(nav_html, '<div class="nav-section-title" onclick="toggleNavSection(this)">Modules<span class="collapse-icon">▼</span></div>')
        table.insert(nav_html, '<ul class="nav-links">')
        for _, module in ipairs(navigation_items.modules) do
            local module_file = module.name:gsub("%.", "_") .. "_module.html"
            local is_active = current_page == module_file and ' class="active"' or ''
            table.insert(nav_html, string.format('<li><a href="%s"%s><span class="nav-icon">🔧</span><span class="nav-text">%s</span></a></li>', 
                module_file, is_active, utils.escape_html(module.name)))
        end
        table.insert(nav_html, '</ul>')
        table.insert(nav_html, '</div>')
    end
    
    return string.format([[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>%s</title>
    %s
</head>
<body>
    <div class="layout">
        <div class="sidebar">
            <div class="sidebar-header">
                <h1>%s</h1>
                <p class="subtitle">%s</p>
            </div>
            <div class="search-box">
                <input type="text" class="search-input" placeholder="Search documentation..." id="searchInput">
            </div>
            <div class="sidebar-nav">
                %s
            </div>
        </div>
        <div class="main-content">
            <div class="content-header">
                <h1>%s</h1>
                <div class="breadcrumb">
                    <a href="index.html">Home</a> / %s
                </div>
            </div>
            <div class="content">
]], 
    utils.escape_html(title), 
    html_generator.get_css(), 
    utils.escape_html(title), 
    utils.escape_html(subtitle or "Generated documentation"),
    table.concat(nav_html, '\n'),
    utils.escape_html(title),
    utils.escape_html(subtitle or "Documentation")
)
end

function html_generator.generate_html_footer()
    return string.format([[
            </div>
        </div>
    </div>
    <div id="toc-container"></div>
    <script>
    // Simple search functionality
    document.getElementById('searchInput').addEventListener('input', function(e) {
        const searchTerm = e.target.value.toLowerCase();
        const navLinks = document.querySelectorAll('.nav-links a');
        
        navLinks.forEach(link => {
            const text = link.textContent.toLowerCase();
            const listItem = link.parentElement;
            
            if (text.includes(searchTerm)) {
                listItem.style.display = '';
            } else {
                listItem.style.display = 'none';
            }
        });
    });
    
    // Sidebar collapse functionality
    function toggleNavSection(titleElement) {
        const section = titleElement.parentElement;
        const sectionName = section.getAttribute('data-section');
        const isCollapsed = section.classList.contains('collapsed');
        
        if (isCollapsed) {
            section.classList.remove('collapsed');
            localStorage.setItem('nav-section-' + sectionName, 'expanded');
        } else {
            section.classList.add('collapsed');
            localStorage.setItem('nav-section-' + sectionName, 'collapsed');
        }
    }
    
    // Restore sidebar states from localStorage
    function restoreSidebarStates() {
        document.querySelectorAll('.nav-section[data-section]').forEach(section => {
            const sectionName = section.getAttribute('data-section');
            const savedState = localStorage.getItem('nav-section-' + sectionName);
            
            if (savedState === 'expanded') {
                section.classList.remove('collapsed');
            } else if (savedState === 'collapsed') {
                section.classList.add('collapsed');
            }
            // If no saved state and section has active item, expand it
            else if (section.querySelector('.nav-links a.active')) {
                section.classList.remove('collapsed');
                localStorage.setItem('nav-section-' + sectionName, 'expanded');
            }
        });
    }
    
    // Initialize sidebar states when page loads
    document.addEventListener('DOMContentLoaded', restoreSidebarStates);
    
    // Add smooth scrolling
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
    
    // Add clickable functionality to stat cards
    document.querySelectorAll('.stat-card.clickable').forEach(card => {
        card.addEventListener('click', function() {
            const targetSection = this.getAttribute('data-target');
            if (targetSection) {
                const target = document.querySelector(targetSection);
                if (target) {
                    target.scrollIntoView({
                        behavior: 'smooth',
                        block: 'start'
                    });
                }
            }
        });
    });
    
    // Table of Contents scroll spy
    function initTOCScrollSpy() {
        const toc = document.getElementById('page-toc');
        const tocContainer = document.getElementById('toc-container');
        
        // Move TOC to the grid container if both exist
        if (toc && tocContainer) {
            tocContainer.appendChild(toc);
        }
        
        if (!toc) return;
        
        const sections = Array.from(document.querySelectorAll('[id*="-section"], .class-overview, .stats-grid, .function-card, .method-card, .param-item')).filter(el => el.id);
        const tocLinks = Array.from(toc.querySelectorAll('a[data-section], .toc-sub-items a'));
        
        if (sections.length === 0 || tocLinks.length === 0) return;
        
        function updateActiveTOC() {
            let currentSection = null;
            const scrollPos = window.scrollY + 150; // Offset for header
            
            // Find the current section
            for (let i = sections.length - 1; i >= 0; i--) {
                const section = sections[i];
                if (section.offsetTop <= scrollPos) {
                    currentSection = section.id;
                    break;
                }
            }
            
            // Update TOC active states
            let activeLink = null;
            tocLinks.forEach(link => {
                const isActive = (link.getAttribute('data-section') === currentSection) || 
                                (link.getAttribute('href') === `#${currentSection}`);
                link.classList.toggle('active', isActive);
                
                if (isActive) {
                    activeLink = link;
                }
                
                // If it's a sub-item that's active, also activate the parent section
                if (isActive && link.closest('.toc-sub-items')) {
                    const parentLi = link.closest('.toc-sub-items').parentElement;
                    const parentSection = parentLi?.querySelector('a[data-section]');
                    if (parentSection) {
                        parentSection.classList.add('active');
                    }
                }
            });
            
            // Auto-scroll TOC to keep active item in view
            if (activeLink) {
                const tocContainer = document.getElementById('toc-container');
                if (tocContainer) {
                    const containerRect = tocContainer.getBoundingClientRect();
                    const linkRect = activeLink.getBoundingClientRect();
                    
                    // Check if the active link is out of view
                    if (linkRect.top < containerRect.top || linkRect.bottom > containerRect.bottom) {
                        const offsetTop = activeLink.offsetTop - tocContainer.offsetTop;
                        tocContainer.scrollTo({
                            top: offsetTop - containerRect.height / 2,
                            behavior: 'smooth'
                        });
                    }
                }
            }
        }
        
        // Update on scroll
        let ticking = false;
        function onScroll() {
            if (!ticking) {
                requestAnimationFrame(() => {
                    updateActiveTOC();
                    ticking = false;
                });
                ticking = true;
            }
        }
        
        window.addEventListener('scroll', onScroll);
        updateActiveTOC(); // Initial call
        
        // Smooth scroll on TOC click
        tocLinks.forEach(link => {
            link.addEventListener('click', function(e) {
                e.preventDefault();
                const targetId = this.getAttribute('data-section');
                const target = document.getElementById(targetId);
                if (target) {
                    const offset = 120; // Account for sticky header
                    const targetPos = target.offsetTop - offset;
                    window.scrollTo({
                        top: targetPos,
                        behavior: 'smooth'
                    });
                }
            });
        });
    }
    
    // Initialize TOC when page loads
    document.addEventListener('DOMContentLoaded', initTOCScrollSpy);
    </script>
</body>
</html>
]], DocZ.version)
end

function html_generator.generate_page_toc(sections)
    if not sections or #sections == 0 then
        return ""
    end
    
    local toc_html = {}
    table.insert(toc_html, '<div class="page-toc" id="page-toc">')
    table.insert(toc_html, '<h4>📋 On This Page</h4>')
    table.insert(toc_html, '<ul>')
    
    for _, section in ipairs(sections) do
        local count_badge = ""
        if section.count and section.count > 0 then
            count_badge = string.format('<span class="toc-count">%d</span>', section.count)
        end
        table.insert(toc_html, string.format(
            '<li><a href="#%s" data-section="%s">%s%s</a>',
            section.id,
            section.id,
            utils.escape_html(section.title),
            count_badge
        ))
        
        -- Add sub-items if they exist
        if section.items and #section.items > 0 then
            table.insert(toc_html, '<ul class="toc-sub-items">')
            for _, item in ipairs(section.items) do
                table.insert(toc_html, string.format(
                    '<li><a href="#%s" data-section="%s">%s</a></li>',
                    item.id,
                    item.id,
                    utils.escape_html(item.title)
                ))
            end
            table.insert(toc_html, '</ul>')
        end
        
        table.insert(toc_html, '</li>')
    end
    
    table.insert(toc_html, '</ul>')
    table.insert(toc_html, '</div>')
    return table.concat(toc_html, '\n')
end

function html_generator.generate_function_html(func)
    local html = {}
    local is_method = func.is_method or func.name:find(":") ~= nil
    local card_class = is_method and "method-card" or "function-card"
    
    table.insert(html, string.format('<div class="%s" id="%s">', card_class, utils.escape_html(func.name:gsub(":", "_"):gsub("%.", "_"))))
    
    -- Function header
    table.insert(html, '<div class="function-header">')
    local signature = func.name .. "(" .. table.concat(func.params or {}, ", ") .. ")"
    table.insert(html, string.format('<h3 class="function-signature">%s</h3>', utils.escape_html(signature)))
    
    -- Function badges
    table.insert(html, '<div class="function-badges">')
    local function_type = is_method and "method" or "function"
    table.insert(html, string.format('<span class="function-type %s">%s</span>', function_type, function_type))
    
    if func.undocumented then
        table.insert(html, '<span class="function-type undocumented">undocumented</span>')
    end
    table.insert(html, '</div>')
    
    table.insert(html, '</div>')
    
    -- Function body
    table.insert(html, '<div class="function-body">')
    
    if func.documentation then
        local doc = func.documentation
        
        if doc.brief and doc.brief ~= "" then
            table.insert(html, string.format('<div class="function-brief">%s</div>', utils.escape_html(doc.brief)))
        end
        
        if doc.description and doc.description ~= "" then
            table.insert(html, string.format('<div class="function-description">%s</div>', utils.escape_html(doc.description)))
        end
        
        -- Parameters section
        if doc.params and #doc.params > 0 then
            table.insert(html, '<div class="parameters-section">')
            table.insert(html, '<h4>Parameters</h4>')
            table.insert(html, '<div class="param-grid">')
            for _, param in ipairs(doc.params) do
                table.insert(html, '<div class="param-item">')
                table.insert(html, '<div class="param-header">')
                table.insert(html, string.format('<span class="param-name">%s</span>', 
                    utils.format_param_name_with_optional(param.name, param.type)))
                table.insert(html, string.format('<span class="param-type">%s</span>', 
                    utils.escape_html(utils.format_type_with_icons(utils.format_type_without_optional_suffix(param.type)))))
                table.insert(html, '</div>')
                if param.description and param.description ~= "" then
                    table.insert(html, string.format('<div class="param-description">%s</div>', utils.escape_html(param.description)))
                end
                table.insert(html, '</div>')
            end
            table.insert(html, '</div>')
            table.insert(html, '</div>')
        end
        
        -- Returns section
        if doc.returns and #doc.returns > 0 then
            table.insert(html, '<div class="returns-section">')
            table.insert(html, '<h4>Returns</h4>')
            table.insert(html, '<div class="return-grid">')
            for _, ret in ipairs(doc.returns) do
                table.insert(html, '<div class="return-item">')
                table.insert(html, '<div class="return-header">')
                table.insert(html, string.format('<span class="return-type">%s</span>', 
                    utils.escape_html(utils.format_type_with_icons(ret.type))))
                table.insert(html, '</div>')
                if ret.description and ret.description ~= "" then
                    table.insert(html, string.format('<div class="return-description">%s</div>', utils.escape_html(ret.description)))
                end
                table.insert(html, '</div>')
            end
            table.insert(html, '</div>')
            table.insert(html, '</div>')
        end
        
        -- Notes section
        if doc.notes and #doc.notes > 0 then
            table.insert(html, '<div class="notes-section">')
            table.insert(html, '<h4>📝 Notes</h4>')
            for _, note in ipairs(doc.notes) do
                table.insert(html, string.format('<p>%s</p>', utils.escape_html(note)))
            end
            table.insert(html, '</div>')
        end
        
        -- See also section
        if doc.see_also and #doc.see_also > 0 then
            table.insert(html, '<div class="see-also-section">')
            table.insert(html, '<h4>🔗 See Also</h4>')
            table.insert(html, '<ul>')
            for _, see in ipairs(doc.see_also) do
                table.insert(html, string.format('<li>%s</li>', utils.escape_html(see)))
            end
            table.insert(html, '</ul>')
            table.insert(html, '</div>')
        end
    else
        table.insert(html, '<div class="function-description undocumented">No documentation available</div>')
        
        -- For undocumented functions, try to infer some info
        if func.params and #func.params > 0 then
            table.insert(html, '<div class="parameters-section">')
            table.insert(html, '<h4>Parameters <span style="font-style: italic; font-weight: normal; color: var(--warning-color);">(inferred)</span></h4>')
            table.insert(html, '<div class="param-grid">')
            for _, param in ipairs(func.params) do
                table.insert(html, '<div class="param-item">')
                table.insert(html, '<div class="param-header">')
                table.insert(html, string.format('<span class="param-name">%s</span>', utils.escape_html(param)))
                table.insert(html, '<span class="param-type"><span class="type-icon">❓</span> unknown</span>')
                table.insert(html, '</div>')
                table.insert(html, '<div class="param-description">Parameter inferred from function signature</div>')
                table.insert(html, '</div>')
            end
            table.insert(html, '</div>')
            table.insert(html, '</div>')
        end
        
        -- Try to infer return value based on function name patterns
        local inferred_return = nil
        local func_lower = func.name:lower()
        if func_lower:find("get") or func_lower:find("find") or func_lower:find("calculate") then
            inferred_return = "unknown"
        elseif func_lower:find("is") or func_lower:find("has") or func_lower:find("can") or func_lower:find("check") then
            inferred_return = "boolean"
        elseif func_lower:find("set") or func_lower:find("add") or func_lower:find("remove") or func_lower:find("delete") or func_lower:find("init") then
            inferred_return = "void"
        elseif func_lower:find("create") or func_lower:find("new") or func_lower:find("make") then
            inferred_return = "object"
        end
        
        if inferred_return then
            table.insert(html, '<div class="returns-section">')
            table.insert(html, '<h4>Returns <span style="font-style: italic; font-weight: normal; color: var(--warning-color);">(inferred)</span></h4>')
            table.insert(html, '<div class="return-grid">')
            table.insert(html, '<div class="return-item">')
            table.insert(html, '<div class="return-header">')
            table.insert(html, string.format('<span class="return-type">%s</span>', 
                utils.escape_html(utils.format_type_with_icons(inferred_return))))
            table.insert(html, '</div>')
            table.insert(html, '<div class="return-description">Return type inferred from function name pattern</div>')
            table.insert(html, '</div>')
            table.insert(html, '</div>')
            table.insert(html, '</div>')
        end
    end
    
    table.insert(html, '</div>') -- function-body
    table.insert(html, '</div>') -- function-card
    return table.concat(html, '\n')
end

function html_generator.generate_library_page(library, all_functions, navigation_items, title)
    local html = {}
    local library_file = library.name:gsub("%.", "_") .. "_library.html"
    
    table.insert(html, html_generator.generate_html_header(title .. " - " .. library.name, library.name .. " Library", navigation_items, library_file))
    
    -- Library overview
    table.insert(html, '<div class="class-overview" id="class-overview">')
    table.insert(html, string.format('<h2>%s</h2>', utils.escape_html(library.name)))
    
    -- Meta information
    table.insert(html, '<div class="class-meta">')
    table.insert(html, '<span class="meta-badge">library</span>')
    if library.documentation then
        if library.documentation.module then
            table.insert(html, string.format('<span class="meta-badge module">module: %s</span>', utils.escape_html(library.documentation.module)))
        end
        if library.documentation.namespace then
            table.insert(html, string.format('<span class="meta-badge namespace">namespace: %s</span>', utils.escape_html(library.documentation.namespace)))
        end
    end
    table.insert(html, '</div>')
    
    -- Library description
    if library.documentation then
        if library.documentation.brief and library.documentation.brief ~= "" then
            table.insert(html, string.format('<p class="function-brief">%s</p>', utils.escape_html(library.documentation.brief)))
        end
        if library.documentation.description and library.documentation.description ~= "" then
            table.insert(html, string.format('<p class="function-description">%s</p>', utils.escape_html(library.documentation.description)))
        end
    end
    table.insert(html, '</div>')
    
    -- Find all functions that belong to this library
    local library_functions = {}
    local library_methods = {}
    
    for _, func in ipairs(all_functions) do
        if func.name:find(library.name, 1, true) == 1 then
            if func.name:find(":") then
                table.insert(library_methods, func)
            else
                table.insert(library_functions, func)
            end
        end
    end
    
    -- Generate statistics
    local all_library_fields = {}
    if library.fields then
        for _, field in ipairs(library.fields) do
            table.insert(all_library_fields, field)
        end
    end
    if library.detected_fields then
        for _, field in ipairs(library.detected_fields) do
            table.insert(all_library_fields, field)
        end
    end
    
    -- Sort alphabetically
    sort_alphabetically(all_library_fields)
    sort_alphabetically(library_methods)
    sort_alphabetically(library_functions)
    
    table.insert(html, '<div class="stats-grid" id="stats-grid">')
    table.insert(html, '<div class="stat-card clickable" data-target="#functions-section">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', #library_functions))
    table.insert(html, '<div class="stat-label">Functions</div>')
    table.insert(html, '</div>')
    table.insert(html, '<div class="stat-card clickable" data-target="#methods-section">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', #library_methods))
    table.insert(html, '<div class="stat-label">Methods</div>')
    table.insert(html, '</div>')
    table.insert(html, '<div class="stat-card clickable" data-target="#fields-section">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', #all_library_fields))
    table.insert(html, '<div class="stat-label">Fields</div>')
    table.insert(html, '</div>')
    table.insert(html, '</div>')
    
    -- Build table of contents sections
    local toc_sections = {
        {id = "class-overview", title = "Overview", count = nil},
        {id = "stats-grid", title = "Statistics", count = nil}
    }
    
    if #all_library_fields > 0 then
        local field_items = {}
        for _, field in ipairs(all_library_fields) do
            table.insert(field_items, {
                id = field.name:gsub(":", "_"):gsub("%.", "_"),
                title = field.name
            })
        end
        table.insert(toc_sections, {id = "fields-section", title = "Fields", count = #all_library_fields, items = field_items})
    end
    if #library_methods > 0 then
        local method_items = {}
        for _, method in ipairs(library_methods) do
            table.insert(method_items, {
                id = method.name:gsub(":", "_"):gsub("%.", "_"),
                title = method.name
            })
        end
        table.insert(toc_sections, {id = "methods-section", title = "Methods", count = #library_methods, items = method_items})
    end
    if #library_functions > 0 then
        local function_items = {}
        for _, func in ipairs(library_functions) do
            table.insert(function_items, {
                id = func.name:gsub(":", "_"):gsub("%.", "_"),
                title = func.name
            })
        end
        table.insert(toc_sections, {id = "functions-section", title = "Functions", count = #library_functions, items = function_items})
    end
    
    -- Add table of contents
    table.insert(html, html_generator.generate_page_toc(toc_sections))
    
    -- Fields section
    if #all_library_fields > 0 then
        table.insert(html, '<div class="section" id="fields-section">')
        table.insert(html, '<div class="section-header">')
        table.insert(html, '<h3>Fields</h3>')
        table.insert(html, string.format('<span class="section-count">%d</span>', #all_library_fields))
        table.insert(html, '</div>')
        
        for _, field in ipairs(all_library_fields) do
            local field_id = field.name:gsub(":", "_"):gsub("%.", "_")
            table.insert(html, string.format('<div class="param-item" id="%s">', field_id))
            table.insert(html, '<div class="param-header">')
            table.insert(html, string.format('<span class="param-name">%s</span>', 
                utils.format_param_name_with_optional(field.name, field.type)))
            table.insert(html, string.format('<span class="param-type">%s</span>', 
                utils.escape_html(utils.format_type_with_icons(utils.format_type_without_optional_suffix(field.type)))))
            if field.undocumented or field.inferred then
                table.insert(html, '<span class="function-type undocumented">inferred</span>')
            end
            table.insert(html, '</div>')
            if field.description and field.description ~= "" then
                table.insert(html, string.format('<div class="param-description">%s</div>', utils.escape_html(field.description)))
            end
            if field.value then
                table.insert(html, string.format('<div class="param-description">Initial value: <code>%s</code></div>', utils.escape_html(field.value)))
            end
            table.insert(html, '</div>')
        end
        table.insert(html, '</div>')
    end
    
    -- Methods section
    if #library_methods > 0 then
        table.insert(html, '<div class="section" id="methods-section">')
        table.insert(html, '<div class="section-header">')
        table.insert(html, '<h3>Methods</h3>')
        table.insert(html, string.format('<span class="section-count">%d</span>', #library_methods))
        table.insert(html, '</div>')
        
        for _, method in ipairs(library_methods) do
            table.insert(html, html_generator.generate_function_html(method))
        end
        table.insert(html, '</div>')
    end
    
    -- Functions section
    if #library_functions > 0 then
        table.insert(html, '<div class="section" id="functions-section">')
        table.insert(html, '<div class="section-header">')
        table.insert(html, '<h3>Functions</h3>')
        table.insert(html, string.format('<span class="section-count">%d</span>', #library_functions))
        table.insert(html, '</div>')
        
        for _, func in ipairs(library_functions) do
            table.insert(html, html_generator.generate_function_html(func))
        end
        table.insert(html, '</div>')
    end
    
    table.insert(html, html_generator.generate_html_footer())
    return table.concat(html, '\n')
end

function html_generator.generate_module_page(module, all_functions, navigation_items, title)
    local html = {}
    local module_file = module.name:gsub("%.", "_") .. "_module.html"
    
    table.insert(html, html_generator.generate_html_header(title .. " - " .. module.name, module.name .. " Module", navigation_items, module_file))
    
    -- Module overview
    table.insert(html, '<div class="class-overview" id="class-overview">')
    table.insert(html, string.format('<h2>%s</h2>', utils.escape_html(module.name)))
    
    -- Meta information
    table.insert(html, '<div class="class-meta">')
    table.insert(html, '<span class="meta-badge">module</span>')
    if module.documentation then
        if module.documentation.namespace then
            table.insert(html, string.format('<span class="meta-badge namespace">namespace: %s</span>', utils.escape_html(module.documentation.namespace)))
        end
    end
    table.insert(html, '</div>')
    
    -- Module description
    if module.documentation then
        if module.documentation.brief and module.documentation.brief ~= "" then
            table.insert(html, string.format('<p class="function-brief">%s</p>', utils.escape_html(module.documentation.brief)))
        end
        if module.documentation.description and module.documentation.description ~= "" then
            table.insert(html, string.format('<p class="function-description">%s</p>', utils.escape_html(module.documentation.description)))
        end
    end
    table.insert(html, '</div>')
    
    -- Find all functions that belong to this module
    local module_functions = {}
    local module_methods = {}
    
    for _, func in ipairs(all_functions) do
        if func.name:find(module.name, 1, true) == 1 then
            if func.name:find(":") then
                table.insert(module_methods, func)
            else
                table.insert(module_functions, func)
            end
        end
    end
    
    -- Generate statistics
    local all_module_fields = {}
    if module.fields then
        for _, field in ipairs(module.fields) do
            table.insert(all_module_fields, field)
        end
    end
    if module.detected_fields then
        for _, field in ipairs(module.detected_fields) do
            table.insert(all_module_fields, field)
        end
    end
    
    -- Sort alphabetically
    sort_alphabetically(all_module_fields)
    sort_alphabetically(module_methods)
    sort_alphabetically(module_functions)
    
    table.insert(html, '<div class="stats-grid" id="stats-grid">')
    table.insert(html, '<div class="stat-card clickable" data-target="#functions-section">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', #module_functions))
    table.insert(html, '<div class="stat-label">Functions</div>')
    table.insert(html, '</div>')
    table.insert(html, '<div class="stat-card clickable" data-target="#methods-section">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', #module_methods))
    table.insert(html, '<div class="stat-label">Methods</div>')
    table.insert(html, '</div>')
    table.insert(html, '<div class="stat-card clickable" data-target="#fields-section">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', #all_module_fields))
    table.insert(html, '<div class="stat-label">Fields</div>')
    table.insert(html, '</div>')
    table.insert(html, '</div>')
    
    -- Build table of contents sections
    local toc_sections = {
        {id = "class-overview", title = "Overview", count = nil},
        {id = "stats-grid", title = "Statistics", count = nil}
    }
    
    if #all_module_fields > 0 then
        local field_items = {}
        for _, field in ipairs(all_module_fields) do
            table.insert(field_items, {
                id = field.name:gsub(":", "_"):gsub("%.", "_"),
                title = field.name
            })
        end
        table.insert(toc_sections, {id = "fields-section", title = "Fields", count = #all_module_fields, items = field_items})
    end
    if #module_methods > 0 then
        local method_items = {}
        for _, method in ipairs(module_methods) do
            table.insert(method_items, {
                id = method.name:gsub(":", "_"):gsub("%.", "_"),
                title = method.name
            })
        end
        table.insert(toc_sections, {id = "methods-section", title = "Methods", count = #module_methods, items = method_items})
    end
    if #module_functions > 0 then
        local function_items = {}
        for _, func in ipairs(module_functions) do
            table.insert(function_items, {
                id = func.name:gsub(":", "_"):gsub("%.", "_"),
                title = func.name
            })
        end
        table.insert(toc_sections, {id = "functions-section", title = "Functions", count = #module_functions, items = function_items})
    end
    
    -- Add table of contents
    table.insert(html, html_generator.generate_page_toc(toc_sections))
    
    -- Fields section
    if #all_module_fields > 0 then
        table.insert(html, '<div class="section" id="fields-section">')
        table.insert(html, '<div class="section-header">')
        table.insert(html, '<h3>Fields</h3>')
        table.insert(html, string.format('<span class="section-count">%d</span>', #all_module_fields))
        table.insert(html, '</div>')
        
        for _, field in ipairs(all_module_fields) do
            local field_id = field.name:gsub(":", "_"):gsub("%.", "_")
            table.insert(html, string.format('<div class="param-item" id="%s">', field_id))
            table.insert(html, '<div class="param-header">')
            table.insert(html, string.format('<span class="param-name">%s</span>', 
                utils.format_param_name_with_optional(field.name, field.type)))
            table.insert(html, string.format('<span class="param-type">%s</span>', 
                utils.escape_html(utils.format_type_with_icons(utils.format_type_without_optional_suffix(field.type)))))
            if field.undocumented or field.inferred then
                table.insert(html, '<span class="function-type undocumented">inferred</span>')
            end
            table.insert(html, '</div>')
            if field.description and field.description ~= "" then
                table.insert(html, string.format('<div class="param-description">%s</div>', utils.escape_html(field.description)))
            end
            if field.value then
                table.insert(html, string.format('<div class="param-description">Initial value: <code>%s</code></div>', utils.escape_html(field.value)))
            end
            table.insert(html, '</div>')
        end
        table.insert(html, '</div>')
    end
    
    -- Methods section
    if #module_methods > 0 then
        table.insert(html, '<div class="section" id="methods-section">')
        table.insert(html, '<div class="section-header">')
        table.insert(html, '<h3>Methods</h3>')
        table.insert(html, string.format('<span class="section-count">%d</span>', #module_methods))
        table.insert(html, '</div>')
        
        for _, method in ipairs(module_methods) do
            table.insert(html, html_generator.generate_function_html(method))
        end
        table.insert(html, '</div>')
    end
    
    -- Functions section
    if #module_functions > 0 then
        table.insert(html, '<div class="section" id="functions-section">')
        table.insert(html, '<div class="section-header">')
        table.insert(html, '<h3>Functions</h3>')
        table.insert(html, string.format('<span class="section-count">%d</span>', #module_functions))
        table.insert(html, '</div>')
        
        for _, func in ipairs(module_functions) do
            table.insert(html, html_generator.generate_function_html(func))
        end
        table.insert(html, '</div>')
    end
    
    table.insert(html, html_generator.generate_html_footer())
    return table.concat(html, '\n')
end

function html_generator.generate_core_page(core, all_functions, navigation_items, title)
    local html = {}
    local core_file = core.name:gsub("%.", "_") .. "_core.html"
    
    table.insert(html, html_generator.generate_html_header(title .. " - " .. core.name, core.name .. " Core", navigation_items, core_file))
    
    -- Core overview
    table.insert(html, '<div class="class-overview" id="class-overview">')
    table.insert(html, string.format('<h2>%s</h2>', utils.escape_html(core.name)))
    
    -- Meta information
    table.insert(html, '<div class="class-meta">')
    table.insert(html, '<span class="meta-badge">core</span>')
    if core.documentation then
        if core.documentation.namespace then
            table.insert(html, string.format('<span class="meta-badge namespace">namespace: %s</span>', utils.escape_html(core.documentation.namespace)))
        end
    end
    table.insert(html, '</div>')
    
    -- Core description
    if core.documentation then
        if core.documentation.brief and core.documentation.brief ~= "" then
            table.insert(html, string.format('<p class="function-brief">%s</p>', utils.escape_html(core.documentation.brief)))
        end
        if core.documentation.description and core.documentation.description ~= "" then
            table.insert(html, string.format('<p class="function-description">%s</p>', utils.escape_html(core.documentation.description)))
        end
    end
    table.insert(html, '</div>')
    
    -- Find all functions that belong to this core
    local core_functions = {}
    local core_methods = {}
    
    for _, func in ipairs(all_functions) do
        if func.name:find(core.name, 1, true) == 1 then
            if func.name:find(":") then
                table.insert(core_methods, func)
            else
                table.insert(core_functions, func)
            end
        end
    end
    
    -- Generate statistics
    local all_core_fields = {}
    if core.fields then
        for _, field in ipairs(core.fields) do
            table.insert(all_core_fields, field)
        end
    end
    if core.detected_fields then
        for _, field in ipairs(core.detected_fields) do
            table.insert(all_core_fields, field)
        end
    end
    
    -- Sort alphabetically
    sort_alphabetically(all_core_fields)
    sort_alphabetically(core_methods)
    sort_alphabetically(core_functions)
    
    table.insert(html, '<div class="stats-grid" id="stats-grid">')
    table.insert(html, '<div class="stat-card clickable" data-target="#functions-section">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', #core_functions))
    table.insert(html, '<div class="stat-label">Functions</div>')
    table.insert(html, '</div>')
    table.insert(html, '<div class="stat-card clickable" data-target="#methods-section">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', #core_methods))
    table.insert(html, '<div class="stat-label">Methods</div>')
    table.insert(html, '</div>')
    table.insert(html, '<div class="stat-card clickable" data-target="#fields-section">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', #all_core_fields))
    table.insert(html, '<div class="stat-label">Fields</div>')
    table.insert(html, '</div>')
    table.insert(html, '</div>')
    
    -- Build table of contents sections
    local toc_sections = {
        {id = "class-overview", title = "Overview", count = nil},
        {id = "stats-grid", title = "Statistics", count = nil}
    }
    
    if #all_core_fields > 0 then
        local field_items = {}
        for _, field in ipairs(all_core_fields) do
            table.insert(field_items, {
                id = field.name:gsub(":", "_"):gsub("%.", "_"),
                title = field.name
            })
        end
        table.insert(toc_sections, {id = "fields-section", title = "Fields", count = #all_core_fields, items = field_items})
    end
    if #core_methods > 0 then
        local method_items = {}
        for _, method in ipairs(core_methods) do
            table.insert(method_items, {
                id = method.name:gsub(":", "_"):gsub("%.", "_"),
                title = method.name
            })
        end
        table.insert(toc_sections, {id = "methods-section", title = "Methods", count = #core_methods, items = method_items})
    end
    if #core_functions > 0 then
        local function_items = {}
        for _, func in ipairs(core_functions) do
            table.insert(function_items, {
                id = func.name:gsub(":", "_"):gsub("%.", "_"),
                title = func.name
            })
        end
        table.insert(toc_sections, {id = "functions-section", title = "Functions", count = #core_functions, items = function_items})
    end
    
    -- Add table of contents
    table.insert(html, html_generator.generate_page_toc(toc_sections))
    
    -- Fields section
    if #all_core_fields > 0 then
        table.insert(html, '<div class="section" id="fields-section">')
        table.insert(html, '<div class="section-header">')
        table.insert(html, '<h3>Fields</h3>')
        table.insert(html, string.format('<span class="section-count">%d</span>', #all_core_fields))
        table.insert(html, '</div>')
        
        for _, field in ipairs(all_core_fields) do
            local field_id = field.name:gsub(":", "_"):gsub("%.", "_")
            table.insert(html, string.format('<div class="param-item" id="%s">', field_id))
            table.insert(html, '<div class="param-header">')
            table.insert(html, string.format('<span class="param-name">%s</span>', 
                utils.format_param_name_with_optional(field.name, field.type)))
            table.insert(html, string.format('<span class="param-type">%s</span>', 
                utils.escape_html(utils.format_type_with_icons(utils.format_type_without_optional_suffix(field.type)))))
            if field.undocumented or field.inferred then
                table.insert(html, '<span class="function-type undocumented">inferred</span>')
            end
            table.insert(html, '</div>')
            if field.description and field.description ~= "" then
                table.insert(html, string.format('<div class="param-description">%s</div>', utils.escape_html(field.description)))
            end
            if field.value then
                table.insert(html, string.format('<div class="param-description">Initial value: <code>%s</code></div>', utils.escape_html(field.value)))
            end
            table.insert(html, '</div>')
        end
        table.insert(html, '</div>')
    end
    
    -- Methods section
    if #core_methods > 0 then
        table.insert(html, '<div class="section" id="methods-section">')
        table.insert(html, '<div class="section-header">')
        table.insert(html, '<h3>Methods</h3>')
        table.insert(html, string.format('<span class="section-count">%d</span>', #core_methods))
        table.insert(html, '</div>')
        
        for _, method in ipairs(core_methods) do
            table.insert(html, html_generator.generate_function_html(method))
        end
        table.insert(html, '</div>')
    end
    
    -- Functions section
    if #core_functions > 0 then
        table.insert(html, '<div class="section" id="functions-section">')
        table.insert(html, '<div class="section-header">')
        table.insert(html, '<h3>Functions</h3>')
        table.insert(html, string.format('<span class="section-count">%d</span>', #core_functions))
        table.insert(html, '</div>')
        
        for _, func in ipairs(core_functions) do
            table.insert(html, html_generator.generate_function_html(func))
        end
        table.insert(html, '</div>')
    end
    
    table.insert(html, html_generator.generate_html_footer())
    return table.concat(html, '\n')
end

function html_generator.generate_class_page(class, all_functions, navigation_items, title)
    local html = {}
    local class_file = class.name:gsub("%.", "_") .. ".html"
    
    table.insert(html, html_generator.generate_html_header(title .. " - " .. class.name, class.name .. " Class", navigation_items, class_file))
    
    -- Class overview
    table.insert(html, '<div class="class-overview" id="class-overview">')
    table.insert(html, string.format('<h2>%s</h2>', utils.escape_html(class.name)))
    
    -- Meta information
    table.insert(html, '<div class="class-meta">')
    table.insert(html, '<span class="meta-badge">class</span>')
    if class.documentation then
        if class.documentation.module then
            table.insert(html, string.format('<span class="meta-badge module">module: %s</span>', utils.escape_html(class.documentation.module)))
        end
        if class.documentation.namespace then
            table.insert(html, string.format('<span class="meta-badge namespace">namespace: %s</span>', utils.escape_html(class.documentation.namespace)))
        end
    end
    table.insert(html, '</div>')
    
    -- Class description
    if class.documentation then
        if class.documentation.brief and class.documentation.brief ~= "" then
            table.insert(html, string.format('<p class="function-brief">%s</p>', utils.escape_html(class.documentation.brief)))
        end
        if class.documentation.description and class.documentation.description ~= "" then
            table.insert(html, string.format('<p class="function-description">%s</p>', utils.escape_html(class.documentation.description)))
        end
    end
    table.insert(html, '</div>')
    
    -- Find all functions that belong to this class
    local class_functions = {}
    local class_methods = {}
    
    for _, func in ipairs(all_functions) do
        if func.name:find(class.name, 1, true) == 1 then
            if func.name:find(":") then
                table.insert(class_methods, func)
            else
                table.insert(class_functions, func)
            end
        end
    end
    
    -- Generate statistics
    table.insert(html, '<div class="stats-grid" id="stats-grid">')
    table.insert(html, '<div class="stat-card clickable" data-target="#functions-section">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', #class_functions))
    table.insert(html, '<div class="stat-label">Functions</div>')
    table.insert(html, '</div>')
    table.insert(html, '<div class="stat-card clickable" data-target="#methods-section">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', #class_methods))
    table.insert(html, '<div class="stat-label">Methods</div>')
    table.insert(html, '</div>')
    table.insert(html, '<div class="stat-card clickable" data-target="#fields-section">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', (class.fields and #class.fields or 0) + (class.detected_fields and #class.detected_fields or 0)))
    table.insert(html, '<div class="stat-label">Fields</div>')
    table.insert(html, '</div>')
    table.insert(html, '</div>')
    
    -- Fields section (combine documented and detected fields)
    local all_class_fields = {}
    if class.fields then
        for _, field in ipairs(class.fields) do
            table.insert(all_class_fields, field)
        end
    end
    if class.detected_fields then
        for _, field in ipairs(class.detected_fields) do
            table.insert(all_class_fields, field)
        end
    end
    
    -- Sort alphabetically
    sort_alphabetically(all_class_fields)
    sort_alphabetically(class_methods)
    sort_alphabetically(class_functions)
    
    -- Build table of contents sections
    local toc_sections = {
        {id = "class-overview", title = "Overview", count = nil},
        {id = "stats-grid", title = "Statistics", count = nil}
    }
    
    if #all_class_fields > 0 then
        local field_items = {}
        for _, field in ipairs(all_class_fields) do
            table.insert(field_items, {
                id = field.name:gsub(":", "_"):gsub("%.", "_"),
                title = field.name
            })
        end
        table.insert(toc_sections, {
            id = "fields-section", 
            title = "Fields", 
            count = #all_class_fields,
            items = field_items
        })
    end
    
    if #class_methods > 0 then
        local method_items = {}
        for _, method in ipairs(class_methods) do
            table.insert(method_items, {
                id = method.name:gsub(":", "_"),
                title = method.name
            })
        end
        table.insert(toc_sections, {
            id = "methods-section", 
            title = "Methods", 
            count = #class_methods,
            items = method_items
        })
    end
    
    if #class_functions > 0 then
        local function_items = {}
        for _, func in ipairs(class_functions) do
            table.insert(function_items, {
                id = func.name:gsub(":", "_"),
                title = func.name
            })
        end
        table.insert(toc_sections, {
            id = "functions-section", 
            title = "Functions", 
            count = #class_functions,
            items = function_items
        })
    end
    
    -- Add table of contents
    table.insert(html, html_generator.generate_page_toc(toc_sections))
    
    if #all_class_fields > 0 then
        table.insert(html, '<div class="section" id="fields-section">')
        table.insert(html, '<div class="section-header">')
        table.insert(html, '<h3>Fields</h3>')
        table.insert(html, string.format('<span class="section-count">%d</span>', #all_class_fields))
        table.insert(html, '</div>')
        
        for _, field in ipairs(all_class_fields) do
            table.insert(html, '<div class="param-item">')
            table.insert(html, '<div class="param-header">')
            table.insert(html, string.format('<span class="param-name">%s</span>', 
                utils.format_param_name_with_optional(field.name, field.type)))
            table.insert(html, string.format('<span class="param-type">%s</span>', 
                utils.escape_html(utils.format_type_with_icons(utils.format_type_without_optional_suffix(field.type)))))
            if field.undocumented or field.inferred then
                table.insert(html, '<span class="function-type undocumented">inferred</span>')
            end
            table.insert(html, '</div>')
            if field.description and field.description ~= "" then
                table.insert(html, string.format('<div class="param-description">%s</div>', utils.escape_html(field.description)))
            end
            if field.value then
                table.insert(html, string.format('<div class="param-description">Initial value: <code>%s</code></div>', utils.escape_html(field.value)))
            end
            table.insert(html, '</div>')
        end
        table.insert(html, '</div>')
    end
    
    -- Methods section
    if #class_methods > 0 then
        table.insert(html, '<div class="section" id="methods-section">')
        table.insert(html, '<div class="section-header">')
        table.insert(html, '<h3>Methods</h3>')
        table.insert(html, string.format('<span class="section-count">%d</span>', #class_methods))
        table.insert(html, '</div>')
        
        for _, method in ipairs(class_methods) do
            table.insert(html, html_generator.generate_function_html(method))
        end
        table.insert(html, '</div>')
    end
    
    -- Functions section
    if #class_functions > 0 then
        table.insert(html, '<div class="section" id="functions-section">')
        table.insert(html, '<div class="section-header">')
        table.insert(html, '<h3>Functions</h3>')
        table.insert(html, string.format('<span class="section-count">%d</span>', #class_functions))
        table.insert(html, '</div>')
        
        for _, func in ipairs(class_functions) do
            table.insert(html, html_generator.generate_function_html(func))
        end
        table.insert(html, '</div>')
    end
    
    table.insert(html, html_generator.generate_html_footer())
    return table.concat(html, '\n')
end

function html_generator.generate_page_html(page, navigation_items, title)
    local html = {}
    local page_file = page.name:gsub("%.", "_"):gsub("%s+", "_"):lower() .. "_page.html"
    
    table.insert(html, html_generator.generate_html_header(title .. " - " .. page.name, page.name, navigation_items, page_file))
    
    -- Build table of contents for page sections
    local toc_sections = {
        {id = "page-overview", title = "Overview", count = nil}
    }
    
    if page.documentation and page.documentation.sections and #page.documentation.sections > 0 then
        for _, section in ipairs(page.documentation.sections) do
            table.insert(toc_sections, {
                id = "section-" .. section.id,
                title = section.title,
                count = nil
            })
        end
    end
    
    -- Generate TOC
    table.insert(html, html_generator.generate_page_toc(toc_sections))
    
    -- Page overview
    table.insert(html, '<div class="class-overview" id="page-overview">')
    table.insert(html, string.format('<h2>%s</h2>', utils.escape_html(page.name)))
    
    -- Meta information
    table.insert(html, '<div class="class-meta">')
    table.insert(html, '<span class="meta-badge">page</span>')
    if page.documentation then
        if page.documentation.namespace then
            table.insert(html, string.format('<span class="meta-badge namespace">namespace: %s</span>', utils.escape_html(page.documentation.namespace)))
        end
    end
    table.insert(html, '</div>')
    
    -- Page description
    if page.documentation then
        if page.documentation.brief and page.documentation.brief ~= "" then
            table.insert(html, string.format('<p class="function-brief">%s</p>', utils.escape_html(page.documentation.brief)))
        end
        if page.documentation.description and page.documentation.description ~= "" then
            table.insert(html, string.format('<div class="function-description">%s</div>', utils.escape_html(page.documentation.description)))
        end
        
        -- Page sections
        if page.documentation.sections and #page.documentation.sections > 0 then
            for _, section in ipairs(page.documentation.sections) do
                table.insert(html, string.format('<div class="section" id="section-%s">', section.id))
                table.insert(html, string.format('<h3>%s</h3>', utils.escape_html(section.title)))
                if section.content and #section.content > 0 then
                    table.insert(html, '<div class="section-content">')
                    for _, content_item in ipairs(section.content) do
                        -- Check if content is already HTML (from code blocks)
                        if content_item:match("^<pre><code") then
                            table.insert(html, content_item)
                        else
                            table.insert(html, string.format('<p>%s</p>', utils.escape_html(content_item)))
                        end
                    end
                    table.insert(html, '</div>')
                end
                table.insert(html, '</div>')
            end
        end
        
        -- Notes section
        if page.documentation.notes and #page.documentation.notes > 0 then
            table.insert(html, '<div class="notes-section">')
            table.insert(html, '<h4>📝 Notes</h4>')
            for _, note in ipairs(page.documentation.notes) do
                table.insert(html, string.format('<p>%s</p>', utils.escape_html(note)))
            end
            table.insert(html, '</div>')
        end
        
        -- See also section
        if page.documentation.see_also and #page.documentation.see_also > 0 then
            table.insert(html, '<div class="see-also-section">')
            table.insert(html, '<h4>🔗 See Also</h4>')
            table.insert(html, '<ul>')
            for _, see_ref in ipairs(page.documentation.see_also) do
                table.insert(html, string.format('<li>%s</li>', utils.escape_html(see_ref)))
            end
            table.insert(html, '</ul>')
            table.insert(html, '</div>')
        end
    end
    table.insert(html, '</div>')
    
    table.insert(html, html_generator.generate_html_footer())
    return table.concat(html, '\n')
end

function html_generator.generate_index_html(title, all_files, navigation_items)
    local html = {}
    table.insert(html, html_generator.generate_html_header(title, "API Documentation Index", navigation_items, "index"))
    
    table.insert(html, '<h2>📚 Welcome to the API Documentation</h2>')
    table.insert(html, '<p>This documentation was automatically generated from Doxygen-style comments in the source code.</p>')
    
    -- Statistics overview
    local total_classes = (navigation_items.classes and #navigation_items.classes) or 0
    local total_libraries = (navigation_items.libraries and #navigation_items.libraries) or 0
    local total_modules = (navigation_items.modules and #navigation_items.modules) or 0
    local total_cores = (navigation_items.cores and #navigation_items.cores) or 0
    local total_files = #all_files
    
    table.insert(html, '<div class="stats-grid">')
    table.insert(html, '<div class="stat-card">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', total_cores))
    table.insert(html, '<div class="stat-label">Core Systems</div>')
    table.insert(html, '</div>')
    table.insert(html, '<div class="stat-card">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', total_libraries))
    table.insert(html, '<div class="stat-label">Libraries</div>')
    table.insert(html, '</div>')
    table.insert(html, '<div class="stat-card">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', total_classes))
    table.insert(html, '<div class="stat-label">Classes</div>')
    table.insert(html, '</div>')
    table.insert(html, '<div class="stat-card">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', total_modules))
    table.insert(html, '<div class="stat-label">Modules</div>')
    table.insert(html, '</div>')
    table.insert(html, '<div class="stat-card">')
    table.insert(html, string.format('<span class="stat-number">%d</span>', total_files))
    table.insert(html, '<div class="stat-label">Source Files</div>')
    table.insert(html, '</div>')
    table.insert(html, '</div>')
    
    -- Quick navigation
    table.insert(html, '<div class="toc">')
    table.insert(html, '<h3>📖 Quick Navigation</h3>')
    table.insert(html, '<div class="toc-grid">')
    
    -- Cores section
    if total_cores > 0 then
        table.insert(html, '<div class="toc-section">')
        table.insert(html, '<h4>⚡ Core Systems</h4>')
        table.insert(html, '<ul>')
        for _, core in ipairs(navigation_items.cores) do
            local core_file = core.name:gsub("%.", "_") .. "_core.html"
            table.insert(html, string.format('<li><a href="%s">%s</a></li>', core_file, utils.escape_html(core.name)))
        end
        table.insert(html, '</ul>')
        table.insert(html, '</div>')
    end
    
    -- Libraries section
    if total_libraries > 0 then
        table.insert(html, '<div class="toc-section">')
        table.insert(html, '<h4>📚 Libraries</h4>')
        table.insert(html, '<ul>')
        for _, library in ipairs(navigation_items.libraries) do
            local library_file = library.name:gsub("%.", "_") .. "_library.html"
            table.insert(html, string.format('<li><a href="%s">%s</a></li>', library_file, utils.escape_html(library.name)))
        end
        table.insert(html, '</ul>')
        table.insert(html, '</div>')
    end
    
    -- Classes section
    if total_classes > 0 then
        table.insert(html, '<div class="toc-section">')
        table.insert(html, '<h4>📦 Classes</h4>')
        table.insert(html, '<ul>')
        for _, class in ipairs(navigation_items.classes) do
            local class_file = class.name:gsub("%.", "_") .. ".html"
            table.insert(html, string.format('<li><a href="%s">%s</a></li>', class_file, utils.escape_html(class.name)))
        end
        table.insert(html, '</ul>')
        table.insert(html, '</div>')
    end
    
    -- Modules section
    if total_modules > 0 then
        table.insert(html, '<div class="toc-section">')
        table.insert(html, '<h4>🔧 Modules</h4>')
        table.insert(html, '<ul>')
        for _, module in ipairs(navigation_items.modules) do
            local module_file = module.name:gsub("%.", "_") .. "_module.html"
            table.insert(html, string.format('<li><a href="%s">%s</a></li>', module_file, utils.escape_html(module.name)))
        end
        table.insert(html, '</ul>')
        table.insert(html, '</div>')
    end
    
    -- Quick links section
    table.insert(html, '<div class="toc-section">')
    table.insert(html, '<h4>🔗 Quick Links</h4>')
    table.insert(html, '<ul>')
    table.insert(html, '<li><a href="all-functions.html">All Functions & Methods</a></li>')
    table.insert(html, '</ul>')
    table.insert(html, '</div>')
    
    table.insert(html, '</div>')
    table.insert(html, '</div>')
    
    -- Recent files (show first 10)
    if #all_files > 0 then
        table.insert(html, '<div class="section">')
        table.insert(html, '<div class="section-header">')
        table.insert(html, '<h3>📄 Source Files</h3>')
        table.insert(html, string.format('<span class="section-count">%d</span>', #all_files))
        table.insert(html, '</div>')
        
        local files_to_show = math.min(15, #all_files)
        for i = 1, files_to_show do
            local file_path = all_files[i]
            local file_name = file_path:match("([^/\\]+)$") or file_path
            table.insert(html, string.format('<div class="file-path">%s</div>', utils.escape_html(file_path)))
        end
        
        if #all_files > files_to_show then
            table.insert(html, string.format('<p class="text-muted">... and %d more files</p>', #all_files - files_to_show))
        end
        
        table.insert(html, '</div>')
    end
    
    table.insert(html, html_generator.generate_html_footer())
    return table.concat(html, '\n')
end

-- Main processing functions
local processor = {}

function processor.process_files(input_dir, output_dir, title)
    print("Scanning for Lua files in: " .. input_dir)
    local lua_files = utils.get_files_recursive(input_dir, "lua")
    print("Found " .. #lua_files .. " Lua files")
    
    local all_modules = {}
    local all_classes = {}
    local all_libraries = {}
    local all_cores = {}
    local all_functions = {}
    local all_fields = {}
    local all_pages = {}
    local all_files = {}
    
    -- Parse all files
    for _, filepath in ipairs(lua_files) do
        print("Processing: " .. filepath)
        local file_doc = parser.parse_file(filepath)
        
        if file_doc then
            table.insert(all_files, filepath)
            
            -- Collect modules
            for _, module in ipairs(file_doc.modules) do
                table.insert(all_modules, module)
            end
            
            -- Collect classes
            for _, class in ipairs(file_doc.classes) do
                table.insert(all_classes, class)
            end
            
            -- Collect libraries
            for _, library in ipairs(file_doc.libraries) do
                table.insert(all_libraries, library)
            end
            
            -- Collect cores
            for _, core in ipairs(file_doc.cores) do
                table.insert(all_cores, core)
            end
            
            -- Collect functions
            for _, func in ipairs(file_doc.functions) do
                func.file = filepath
                table.insert(all_functions, func)
            end
            
            -- Collect fields
            for _, field in ipairs(file_doc.fields) do
                field.file = filepath
                table.insert(all_fields, field)
            end
            
            -- Collect pages (aggregate content from multiple files)
            for _, page in ipairs(file_doc.pages) do
                page.file = filepath
                
                -- Check if page already exists and merge content
                local existing_page = nil
                for _, existing in ipairs(all_pages) do
                    if existing.name == page.name then
                        existing_page = existing
                        break
                    end
                end
                
                if existing_page then
                    -- Merge sections from this file into existing page
                    if page.documentation and page.documentation.sections then
                        if not existing_page.documentation.sections then
                            existing_page.documentation.sections = {}
                        end
                        for _, section in ipairs(page.documentation.sections) do
                            table.insert(existing_page.documentation.sections, section)
                        end
                    end
                    
                    -- Merge other content
                    if page.documentation then
                        if page.documentation.description and page.documentation.description ~= "" then
                            if existing_page.documentation.description == "" then
                                existing_page.documentation.description = page.documentation.description
                            else
                                existing_page.documentation.description = existing_page.documentation.description .. "\n\n" .. page.documentation.description
                            end
                        end
                        
                        if page.documentation.notes then
                            if not existing_page.documentation.notes then
                                existing_page.documentation.notes = {}
                            end
                            for _, note in ipairs(page.documentation.notes) do
                                table.insert(existing_page.documentation.notes, note)
                            end
                        end
                        
                        if page.documentation.see_also then
                            if not existing_page.documentation.see_also then
                                existing_page.documentation.see_also = {}
                            end
                            for _, see_ref in ipairs(page.documentation.see_also) do
                                table.insert(existing_page.documentation.see_also, see_ref)
                            end
                        end
                    end
                else
                    -- New page
                    table.insert(all_pages, page)
                end
            end
        end
    end
    
    -- Associate fields with their parent classes/modules/libraries
    for _, field in ipairs(all_fields) do
        -- Associate with classes
        for _, class in ipairs(all_classes) do
            if field.name:find(class.name, 1, true) == 1 then
                if not class.detected_fields then
                    class.detected_fields = {}
                end
                table.insert(class.detected_fields, field)
            end
        end
        
        -- Associate with modules
        for _, module in ipairs(all_modules) do
            if field.name:find(module.name, 1, true) == 1 then
                if not module.detected_fields then
                    module.detected_fields = {}
                end
                table.insert(module.detected_fields, field)
            end
        end
        
        -- Associate with libraries
        for _, library in ipairs(all_libraries) do
            if field.name:find(library.name, 1, true) == 1 then
                if not library.detected_fields then
                    library.detected_fields = {}
                end
                table.insert(library.detected_fields, field)
            end
        end
        
        -- Associate with cores
        for _, core in ipairs(all_cores) do
            if field.name:find(core.name, 1, true) == 1 then
                if not core.detected_fields then
                    core.detected_fields = {}
                end
                table.insert(core.detected_fields, field)
            end
        end
    end
    
    -- Ensure output directory exists
    utils.mkdir_p(output_dir)
    
    -- Sort all navigation items alphabetically
    sort_alphabetically(all_classes)
    sort_alphabetically(all_modules)
    sort_alphabetically(all_libraries)
    sort_alphabetically(all_cores)
    sort_alphabetically(all_pages)
    
    -- Prepare navigation data
    local navigation_items = {
        classes = all_classes,
        modules = all_modules,
        libraries = all_libraries,
        cores = all_cores,
        pages = all_pages
    }
    
    -- Generate index.html
    local index_html = html_generator.generate_index_html(title, all_files, navigation_items)
    local index_file = io.open(output_dir .. "/index.html", "w")
    if index_file then
        index_file:write(index_html)
        index_file:close()
        print("Generated: index.html")
    end
    
    -- Generate individual class pages
    for _, class in ipairs(all_classes) do
        local class_file = class.name:gsub("%.", "_") .. ".html"
        local class_html = html_generator.generate_class_page(class, all_functions, navigation_items, title)
        local class_output = io.open(output_dir .. "/" .. class_file, "w")
        if class_output then
            class_output:write(class_html)
            class_output:close()
            print("Generated: " .. class_file)
        end
    end
    
    -- Generate individual library pages
    for _, library in ipairs(all_libraries) do
        local library_file = library.name:gsub("%.", "_") .. "_library.html"
        local library_html = html_generator.generate_library_page(library, all_functions, navigation_items, title)
        local library_output = io.open(output_dir .. "/" .. library_file, "w")
        if library_output then
            library_output:write(library_html)
            library_output:close()
            print("Generated: " .. library_file)
        end
    end
    
    -- Generate individual module pages
    for _, module in ipairs(all_modules) do
        local module_file = module.name:gsub("%.", "_") .. "_module.html"
        local module_html = html_generator.generate_module_page(module, all_functions, navigation_items, title)
        local module_output = io.open(output_dir .. "/" .. module_file, "w")
        if module_output then
            module_output:write(module_html)
            module_output:close()
            print("Generated: " .. module_file)
        end
    end
    
    -- Generate individual core pages
    for _, core in ipairs(all_cores) do
        local core_file = core.name:gsub("%.", "_") .. "_core.html"
        local core_html = html_generator.generate_core_page(core, all_functions, navigation_items, title)
        local core_output = io.open(output_dir .. "/" .. core_file, "w")
        if core_output then
            core_output:write(core_html)
            core_output:close()
            print("Generated: " .. core_file)
        end
    end
    
    -- Generate individual page files
    for _, page in ipairs(all_pages) do
        local page_file = page.name:gsub("%.", "_"):gsub("%s+", "_"):lower() .. "_page.html"
        local page_html = html_generator.generate_page_html(page, navigation_items, title)
        local page_output = io.open(output_dir .. "/" .. page_file, "w")
        if page_output then
            page_output:write(page_html)
            page_output:close()
            print("Generated: " .. page_file)
        end
    end
    
    -- Generate all functions page
    local all_functions_html = {}
    table.insert(all_functions_html, html_generator.generate_html_header(title .. " - All Functions", "All Functions & Methods", navigation_items, "all-functions"))
    
    table.insert(all_functions_html, '<h2>📋 All Functions & Methods</h2>')
    table.insert(all_functions_html, string.format('<p>Complete reference of all %d functions and methods.</p>', #all_functions))
    
    -- Group functions by type
    local functions_by_type = {
        functions = {},
        methods = {},
        undocumented = {}
    }
    
    for _, func in ipairs(all_functions) do
        if func.undocumented then
            table.insert(functions_by_type.undocumented, func)
        elseif func.name:find(":") then
            table.insert(functions_by_type.methods, func)
        else
            table.insert(functions_by_type.functions, func)
        end
    end
    
    -- Sort all function categories alphabetically
    sort_alphabetically(functions_by_type.functions)
    sort_alphabetically(functions_by_type.methods)
    sort_alphabetically(functions_by_type.undocumented)
    
    -- Statistics
    table.insert(all_functions_html, '<div class="stats-grid">')
    table.insert(all_functions_html, '<div class="stat-card">')
    table.insert(all_functions_html, string.format('<span class="stat-number">%d</span>', #functions_by_type.functions))
    table.insert(all_functions_html, '<div class="stat-label">Functions</div>')
    table.insert(all_functions_html, '</div>')
    table.insert(all_functions_html, '<div class="stat-card">')
    table.insert(all_functions_html, string.format('<span class="stat-number">%d</span>', #functions_by_type.methods))
    table.insert(all_functions_html, '<div class="stat-label">Methods</div>')
    table.insert(all_functions_html, '</div>')
    table.insert(all_functions_html, '<div class="stat-card">')
    table.insert(all_functions_html, string.format('<span class="stat-number">%d</span>', #functions_by_type.undocumented))
    table.insert(all_functions_html, '<div class="stat-label">Undocumented</div>')
    table.insert(all_functions_html, '</div>')
    table.insert(all_functions_html, '<div class="stat-card">')
    table.insert(all_functions_html, string.format('<span class="stat-number">%d</span>', #all_functions))
    table.insert(all_functions_html, '<div class="stat-label">Total</div>')
    table.insert(all_functions_html, '</div>')
    table.insert(all_functions_html, '</div>')
    
    -- Functions section
    if #functions_by_type.functions > 0 then
        table.insert(all_functions_html, '<div class="section">')
        table.insert(all_functions_html, '<div class="section-header">')
        table.insert(all_functions_html, '<h3>Functions</h3>')
        table.insert(all_functions_html, string.format('<span class="section-count">%d</span>', #functions_by_type.functions))
        table.insert(all_functions_html, '</div>')
        
        for _, func in ipairs(functions_by_type.functions) do
            table.insert(all_functions_html, html_generator.generate_function_html(func))
        end
        table.insert(all_functions_html, '</div>')
    end
    
    -- Methods section
    if #functions_by_type.methods > 0 then
        table.insert(all_functions_html, '<div class="section">')
        table.insert(all_functions_html, '<div class="section-header">')
        table.insert(all_functions_html, '<h3>Methods</h3>')
        table.insert(all_functions_html, string.format('<span class="section-count">%d</span>', #functions_by_type.methods))
        table.insert(all_functions_html, '</div>')
        
        for _, method in ipairs(functions_by_type.methods) do
            table.insert(all_functions_html, html_generator.generate_function_html(method))
        end
        table.insert(all_functions_html, '</div>')
    end
    
    -- Undocumented section
    if #functions_by_type.undocumented > 0 then
        table.insert(all_functions_html, '<div class="section">')
        table.insert(all_functions_html, '<div class="section-header">')
        table.insert(all_functions_html, '<h3>Undocumented Functions</h3>')
        table.insert(all_functions_html, string.format('<span class="section-count">%d</span>', #functions_by_type.undocumented))
        table.insert(all_functions_html, '</div>')
        
        for _, func in ipairs(functions_by_type.undocumented) do
            table.insert(all_functions_html, html_generator.generate_function_html(func))
        end
        table.insert(all_functions_html, '</div>')
    end
    
    table.insert(all_functions_html, html_generator.generate_html_footer())
    
    local all_functions_file = io.open(output_dir .. "/all-functions.html", "w")
    if all_functions_file then
        all_functions_file:write(table.concat(all_functions_html, '\n'))
        all_functions_file:close()
        print("Generated: all-functions.html")
    end
    
    print("")
    print("Documentation Generation Summary:")
    print("  - " .. #all_classes .. " classes documented")
    print("  - " .. #all_libraries .. " libraries documented") 
    print("  - " .. #all_modules .. " modules found")
    print("  - " .. #all_cores .. " core systems found")
    print("  - " .. #all_pages .. " custom pages created")
    print("  - " .. #all_functions .. " functions/methods documented")
    print("  - " .. #functions_by_type.undocumented .. " undocumented functions detected")

    -- Count all fields (documented + detected)
    local total_fields = 0
    for _, class in ipairs(all_classes) do
        if class.fields then
            total_fields = total_fields + #class.fields
        end
        if class.detected_fields then
            total_fields = total_fields + #class.detected_fields
        end
    end
    for _, library in ipairs(all_libraries) do
        if library.fields then
            total_fields = total_fields + #library.fields
        end
        if library.detected_fields then
            total_fields = total_fields + #library.detected_fields
        end
    end
    for _, module in ipairs(all_modules) do
        if module.fields then
            total_fields = total_fields + #module.fields
        end
        if module.detected_fields then
            total_fields = total_fields + #module.detected_fields
        end
    end
    for _, core in ipairs(all_cores) do
        if core.fields then
            total_fields = total_fields + #core.fields
        end
        if core.detected_fields then
            total_fields = total_fields + #core.detected_fields
        end
    end
    print("  - " .. total_fields .. " fields detected")
    print("  - " .. #all_files .. " source files processed")
    print("")
    print("Documentation generation complete!")
    print("Open " .. output_dir .. "/index.html in your web browser to view the documentation.")
end

-- Command line argument parsing
local function parse_args(args)
    local i = 1
    while i <= #args do
        local arg = args[i]
        
        if arg == "-h" or arg == "--help" then
            print([[
DocZ - Lua Documentation Generator

Usage: lua DocZ.lua -i <input_dir> -o <output_dir> [-t <title>] [-h]

Options:
  -i, --input   Input directory to scan for Lua files (required)
  -o, --output  Output directory for HTML documentation (required)
  -t, --title   Title for the documentation (default: "Lua API Reference")
  -h, --help    Show this help message

Examples:
  lua DocZ.lua -i ./src -o ./docs
  lua DocZ.lua -i ./FrameworkZ/Contents/mods/FrameworkZ/media/lua -o ./docs -t "FrameworkZ API"

Supported Doxygen-style comment formats:
  --! Comment using --! prefix
  --- Comment using --- prefix
  
Supported tags:
  @brief, @class, @module, @namespace, @param, @paramType, @return, @field, @note, @see, @library, @core, @page, @section, @code, @endcode
  \brief, \class, \module, \namespace, \param, \paramType, \return, \field, \note, \see, \library, \core, \page, \section, \code, \endcode

Page creation features:
  - Use @page or \page to create custom documentation pages
  - Use @section or \section to add sections within pages  
  - Use @code [language] and @endcode to add syntax-highlighted code blocks
  - Page content can be contributed from multiple files and will be aggregated

Type annotations support:
  - Union types: string|nil, number|boolean
  - Array types: string[], table<string,number>
  - Optional types: string?, number?, MyClass? (also supports type|nil format)
  - Generic types: table<K,V>, function<T>
  - Complex types: MyClass|nil, string[]|boolean
  - Mixed optional: table<string>?, function<T>|nil, CustomType?
]])
            os.exit(0)
        elseif arg == "-i" or arg == "--input" then
            i = i + 1
            if i <= #args then
                config.input_dir = args[i]
            else
                print("Error: -i/--input requires a directory path")
                os.exit(1)
            end
        elseif arg == "-o" or arg == "--output" then
            i = i + 1
            if i <= #args then
                config.output_dir = args[i]
            else
                print("Error: -o/--output requires a directory path")
                os.exit(1)
            end
        elseif arg == "-t" or arg == "--title" then
            i = i + 1
            if i <= #args then
                config.title = args[i]
            else
                print("Error: -t/--title requires a title string")
                os.exit(1)
            end
        else
            print("Error: Unknown argument: " .. arg)
            print("Use -h or --help for usage information")
            os.exit(1)
        end
        
        i = i + 1
    end
    
    if not config.input_dir then
        print("Error: Input directory is required (-i/--input)")
        os.exit(1)
    end
    
    if not config.output_dir then
        print("Error: Output directory is required (-o/--output)")
        os.exit(1)
    end
end

-- Main execution
local function main()
    print("DocZ - Lua Documentation Generator v" .. DocZ.version)
    print("")
    
    parse_args(arg)
    
    processor.process_files(config.input_dir, config.output_dir, config.title)
end

-- Run if this file is executed directly
if arg and arg[0] and arg[0]:match("DocZ%.lua$") then
    main()
end

return DocZ