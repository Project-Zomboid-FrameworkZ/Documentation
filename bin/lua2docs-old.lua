--[[--------------------------------------------------------------------------
 --   Copyright (C) 2012 by Simon Dales   --
 --   simon@purrsoft.co.uk   --
 --                                                                         --
 --   This program is free software; you can redistribute it and/or modify  --
 --   it under the terms of the GNU General Public License as published by  --
 --   the Free Software Foundation; either version 2 of the License, or     --
 --   (at your option) any later version.                                   --
 --                                                                         --
 --   This program is distributed in the hope that it will be useful,       --
 --   but WITHOUT ANY WARRANTY; without even the implied warranty of        --
 --   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
 --   GNU General Public License for more details.                          --
 --                                                                         --
 --   You should have received a copy of the GNU General Public License     --
 --   along with this program; if not, write to the                         --
 --   Free Software Foundation, Inc.,                                       --
 --   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             --
----------------------------------------------------------------------------]]

function class(BaseClass, ClassInitialiser)
	local newClass = {}    -- a new class newClass
	if not ClassInitialiser and type(BaseClass) == 'function' then
		ClassInitialiser = BaseClass
		BaseClass = nil
	elseif type(BaseClass) == 'table' then
		-- our new class is a shallow copy of the base class!
		for i,v in pairs(BaseClass) do
			newClass[i] = v
		end
		newClass._base = BaseClass
	end
	-- the class will be the metatable for all its newInstanceects,
	-- and they will look up their methods in it.
	newClass.__index = newClass

	-- expose a constructor which can be called by <classname>(<args>)
	local classMetatable = {}
	classMetatable.__call = 
	function(class_tbl, ...)
		local newInstance = {}
		setmetatable(newInstance,newClass)
		--if init then
		--	init(newInstance,...)
		if class_tbl.init then
			class_tbl.init(newInstance,...)
		else 
			-- make sure that any stuff from the base class is initialized!
			if BaseClass and BaseClass.init then
				BaseClass.init(newInstance, ...)
			end
		end
		return newInstance
	end
	newClass.init = ClassInitialiser
	newClass.is_a = 
	function(this, klass)
		local thisMetatable = getmetatable(this)
		while thisMetatable do 
			if thisMetatable == klass then
				return true
			end
			thisMetatable = thisMetatable._base
		end
		return false
	end
	setmetatable(newClass, classMetatable)
	return newClass
end

-- require 'elijah_clock'

--! \class TCore_Clock
--! \brief a clock
TCore_Clock = class()

--! \brief get the current time
function TCore_Clock.GetTimeNow()
	if os.gettimeofday then
		return os.gettimeofday()
	else
		return os.time()
	end
end

--! \brief constructor
function TCore_Clock.init(this,T0)
	if T0 then
		this.t0 = T0
	else
		this.t0 = TCore_Clock.GetTimeNow()
	end
end

--! \brief get time string
function TCore_Clock.getTimeStamp(this,T0)
	local t0
	if T0 then
		t0 = T0
	else
		t0 = this.t0
	end
	return os.date('%c %Z',t0)
end


--require 'elijah_io'

--! \class TCore_IO
--! \brief io to console
--! 
--! pseudo class (no methods, just to keep documentation tidy)
TCore_IO = class()
-- 
--! \brief write to stdout
function TCore_IO_write(Str)
	if (Str) then
		io.write(Str)
	end
end

--! \brief write to stdout
function TCore_IO_writeln(Str)
	if (Str) then
		io.write(Str)
	end
	io.write("\n")
end


--require 'elijah_string'

--! \brief trims a string
function string_trim(Str)
  return Str:match("^%s*(.-)%s*$")
end

--! \brief split a string
--! 
--! \param Str
--! \param Pattern
--! \returns table of string fragments
function string_split(Str, Pattern)
   local splitStr = {}
   local fpat = "(.-)" .. Pattern
   local last_end = 1
   local str, e, cap = string.find(Str,fpat, 1)
   while str do
      if str ~= 1 or cap ~= "" then
         table.insert(splitStr,cap)
      end
      last_end = e+1
      str, e, cap = string.find(Str,fpat, last_end)
   end
   if last_end <= #Str then
      cap = string.sub(Str,last_end)
      table.insert(splitStr, cap)
   end
   return splitStr
end


--require 'elijah_commandline'

--! \class TCore_Commandline
--! \brief reads/parses commandline
TCore_Commandline = class()

--! \brief constructor
function TCore_Commandline.init(this)
	this.argv = arg
	this.parsed = {}
	this.params = {}
end

--! \brief get value
function TCore_Commandline.getRaw(this,Key,Default)
	local val = this.argv[Key]
	if not val then
		val = Default
	end
	return val
end


--require 'elijah_debug'

-------------------------------
--! \brief file buffer
--! 
--! an input file buffer
TStream_Read = class()

--! \brief get contents of file
--! 
--! \param Filename name of file to read (or nil == stdin)
function 	TStream_Read.getContents(this,Filename)
	-- get lines from file
	local filecontents
	if Filename then
		-- syphon lines to our table
		--TCore_Debug_show_var('Filename',Filename)
		filecontents={}
		for line in io.lines(Filename) do
			table.insert(filecontents,line)
		end
	else
		-- get stuff from stdin as a long string (with crlfs etc)
		filecontents=io.read('*a')
		--  make it a table of lines
		filecontents = TString_split(filecontents,'[\n]') -- note this only works for unix files.
		Filename = 'stdin'
	end
	
	if filecontents then
		this.filecontents = filecontents
		this.contentsLen = #filecontents
		this.currentLineNo = 1
	end
	
	return filecontents
end

--! \brief get lineno
function TStream_Read.getLineNo(this)
	return this.currentLineNo
end

--! \brief get a line
function TStream_Read.getLine(this)
	local line
	if this.currentLine then
		line = this.currentLine
		this.currentLine = nil
	else
		-- get line
		if this.currentLineNo<=this.contentsLen then
			line = this.filecontents[this.currentLineNo]
			this.currentLineNo = this.currentLineNo + 1
		else
			line = ''
		end
	end
	return line
end

--! \brief save line fragment
function TStream_Read.ungetLine(this,LineFrag)
	this.currentLine = LineFrag
end

--! \brief is it eof?
function TStream_Read.eof(this)
	if this.currentLine or this.currentLineNo<=this.contentsLen then
		return false
	end
	return true
end

--! \brief output stream
TStream_Write = class()

--! \brief constructor
function TStream_Write.init(this)
	this.tailLine = {}
end

--! \brief write immediately
function TStream_Write.write(this,Str)
	TCore_IO_write(Str)
end

--! \brief write immediately
function TStream_Write.writeln(this,Str)
	TCore_IO_writeln(Str)
end

--! \brief write immediately
function TStream_Write.writelnComment(this,Str)
	TCore_IO_write('// ZZ: ')
	TCore_IO_writeln(Str)
end

--! \brief write to tail
function TStream_Write.writelnTail(this,Line)
	if not Line then
		Line = ''
	end
	table.insert(this.tailLine,Line)
end

--! \brief outout tail lines
function TStream_Write.write_tailLines(this)
	for k,line in ipairs(this.tailLine) do
		TCore_IO_writeln(line)
	end
	TCore_IO_write('// Lua2DoX new eof')
end

--! \brief input filter
TLua2DoX_filter = class()

--! \brief allow us to do errormessages
function TLua2DoX_filter.warning(this,Line,LineNo,Legend)
	this.outStream:writelnTail(
		'//! \todo warning! ' .. Legend .. ' (@' .. LineNo .. ')"' .. Line .. '"'
		)
end

--! \brief trim comment off end of string
--!
--! If the string has a comment on the end, this trims it off.
--!
local function TString_removeCommentFromLine(Line)
	local pos_comment = string.find(Line,'%-%-')
	local tailComment
	if pos_comment then
		Line = string.sub(Line,1,pos_comment-1)
		tailComment = string.sub(Line,pos_comment)
	end
	return Line,tailComment
end

--! \brief get directive from magic
local function getMagicDirective(Line)
	local macro,tail
	local macroStr = '[\\@]'
	local pos_macro = string.find(Line,macroStr)
	if pos_macro then
		--! ....\\ macro...stuff
		--! ....\@ macro...stuff
		local line = string.sub(Line,pos_macro+1)
		local space = string.find(line,'%s+')
		if space then
			macro = string.sub(line,1,space-1)
			tail  = string_trim(string.sub(line,space+1))
		else
			macro = line
			tail  = ''
		end
	end
	return macro,tail
end

--! \brief check comment for fn
local function checkComment4fn(Fn_magic,MagicLines)
	local fn_magic = Fn_magic
--	TCore_IO_writeln('// checkComment4fn "' .. MagicLines .. '"')
	
	local magicLines = string_split(MagicLines,'\n')
	
	local macro,tail
	
	for k,line in ipairs(magicLines) do
		macro,tail = getMagicDirective(line)
		if macro == 'fn' then
			fn_magic = tail
		--	TCore_IO_writeln('// found fn "' .. fn_magic .. '"')
		else
			--TCore_IO_writeln('// not found fn "' .. line .. '"')
		end
	end
	
	return fn_magic
end

local function returnBriefFromDoc(docLines)
    -- Default return type
    local brief = ""

    for _, dl in ipairs(docLines) do
        local rline = dl:match("\\brief%s+(.*)")
        if rline then
            local extractedBrief = rline:match("([%w_]+)")
            if extractedBrief then
                brief = '//!< ' .. rline
                break
            end
        end
    end

    return brief
end

local function returnTypeFromDoc(docLines)
    -- Default return type
    local retType = "void"

    for _, dl in ipairs(docLines) do
        local rline = dl:match("\\return%s+(.*)")
        if rline then
            local extractedType = rline:match("([%w_]+)")
            if extractedType then
                retType = extractedType
                break
            end
        end
    end

    return retType
end

local function extractReturnType(docBuffer)
    for _, comment in ipairs(docBuffer) do
        local returnType = string.match(comment, "^%s*Returns:%s*(%S+)")
        if returnType then
            return returnType
        end
    end
    return "void" -- Default return type
end

--! \brief run the filter
function TLua2DoX_filter.readfile(this, AppStamp, Filename)
    local err

    local inStream = TStream_Read()
    local outStream = TStream_Write()
    this.outStream = outStream -- Save to this object

    local pages = {} -- Store pages by identifier
    local globals = {}
    local elements = {}
    local processedClasses = {} -- Track processed class names

    local currentClass = nil
    local docBuffer = {}

    local function flushDocBuffer()
        local buffer = table.concat(docBuffer, "\n")
        docBuffer = {}
        return buffer
    end

    local function detectPageFromDoc()
        local pageName, pageContent = nil, ""
        for _, comment in ipairs(docBuffer) do
            local match = string.match(comment, "\\page%s+(%S+)")
            if match then
                pageName = match
            else
                pageContent = pageContent .. comment .. "\n"
            end
        end
        return pageName, string_trim(pageContent)
    end

    local function detectClassFromDoc()
        local className, classDoc = nil, ""
        for _, comment in ipairs(docBuffer) do
            local match = string.match(comment, "\\class%s+(%S+)")
            if match then
                className = match
            else
                classDoc = classDoc .. comment .. "\n"
            end
        end
        return className, string_trim(classDoc)
    end

    local function getReturnTypeFromDoc()
        for _, comment in ipairs(docBuffer) do
            local returnType = string.match(comment, "\\return%s+(%S+)")
            if returnType then
                -- Ensure namespaces or irrelevant prefixes are excluded
                returnType = string.gsub(returnType, "^[^:]+::", "")
                return returnType
            end
        end
        return "void"
    end

    if inStream:getContents(Filename) then
        local line
        while not (err or inStream:eof()) do
            line = string_trim(inStream:getLine())

            if string.sub(line, 1, 2) == '--' then
                -- Capture comments
                if string.sub(line, 3, 3) == '!' or string.match(line, "\\%w+") then
                    table.insert(docBuffer, string.sub(line, 3))
                elseif string.sub(line, 3, 4) == '[[' then
                    -- Capture multi-line comments
                    line = string.sub(line, 5)
                    local comment = ''
                    while not (inStream:eof()) do
                        local closeSquare = string.find(line, ']]')
                        if closeSquare then
                            comment = comment .. string.sub(line, 1, closeSquare - 1)
                            line = string.sub(line, closeSquare + 2) -- Move past ']]'
                            break
                        else
                            comment = comment .. line .. '\n'
                            line = inStream:getLine()
                        end
                    end
                    for commentLine in string.gmatch(comment, "([^\n]+)") do
                        table.insert(docBuffer, commentLine)
                    end
                else
                    -- Normal single-line comments
                    table.insert(docBuffer, string.sub(line, 3))
                end

                -- Detect and process Doxygen directives (e.g., \mainpage, \page, \section)
                local directive, directiveName = string.match(docBuffer[1] or "", "\\(%w+)%s*(%S*)")
                if directive then
                    -- Handle page-specific content
                    if directive == "mainpage" or directive == "page" or directive == "section" then
                        -- Create a new entry for this directive if it doesn't exist
                        if not pages[directiveName] then
                            pages[directiveName] = {
                                type = directive,
                                content = {}
                            }
                        end

                        -- Append the entire docBuffer to the page content
                        for _, line in ipairs(docBuffer) do
                            table.insert(pages[directiveName].content, line)
                        end

                        -- Clear docBuffer only for pages
                        docBuffer = {}
                    end
                end

            elseif string.find(table.concat(docBuffer, "\n"), "\\class%s+") then
                -- Class definition
                local className, classDoc = detectClassFromDoc()
                if className then
                    if processedClasses[className] then
                        print("Warning: Duplicate class name detected: " .. className)
                    else
                        if currentClass then
                            -- Prevent nested or redundant namespaces
                            className = currentClass .. "::" .. className
                        end
                        elements[className] = {
                            name = className,
                            isObject = true,
                            members = {},
                            functions = {},
                            doc = classDoc
                        }
                        processedClasses[className] = true
                        currentClass = className
                    end
                end
                flushDocBuffer()

            elseif string.find(line, "^%s*function%s") then
                -- Function definition
                local fnSignature = string.match(line, "^%s*function%s+(.-)%s*$")
                local fnDoc = flushDocBuffer()
                local returnType = getReturnTypeFromDoc() -- Parse return type only from comments

                -- Extract function name and arguments
                local namespace, baseFnName, fnArgs = string.match(fnSignature, "^(.-)[.:]?([^.:]+)%s*%((.*)%)$")
                fnArgs = fnArgs or ""

                if baseFnName then
                    if currentClass or namespace then
                        -- Determine correct namespace
                        local fullNamespace = (namespace and namespace ~= "" and namespace) or currentClass
                        if fullNamespace then
                            if not elements[fullNamespace] then
                                elements[fullNamespace] = {
                                    name = fullNamespace,
                                    isObject = true,
                                    members = {},
                                    functions = {},
                                    doc = ""
                                }
                            end
                        end

                        -- Ensure returnType is isolated from namespace parsing
                        table.insert(elements[fullNamespace].functions, {
                            name = baseFnName,
                            class = fullNamespace,
                            args = fnArgs,
                            doc = fnDoc,
                            returnType = returnType -- Use only the cleaned return type
                        })
                    else
                        -- Global function
                        table.insert(globals, {
                            type = "function",
                            name = baseFnName,
                            args = fnArgs,
                            doc = fnDoc,
                            returnType = returnType -- Use only the cleaned return type
                        })
                    end
                end

            elseif string.find(line, "%s*=%s*") then
                -- Variable definition
                local varName = string.match(line, "^(.-)%s*=")
                local varDoc = flushDocBuffer()
                if currentClass then
                    table.insert(elements[currentClass].members, {
                        name = varName,
                        doc = varDoc
                    })
                else
                    table.insert(globals, {
                        type = "variable",
                        name = varName,
                        doc = varDoc
                    })
                end

            elseif string.find(line, "^%s*end%s*$") then
                -- End block
                currentClass = nil
            end
        end

        -- Write all pages and sections dynamically
        for directiveName, pageData in pairs(pages) do
            if pageData.type == "mainpage" then
                outStream:writeln("/*!")
                outStream:writeln(" * \\mainpage")
            else
                outStream:writeln("/*!")
                outStream:writeln(" * \\" .. pageData.type .. " " .. directiveName)
            end
            outStream:writeln(" *") -- Add a blank line for formatting
            for _, line in ipairs(pageData.content) do
                outStream:writeln(" * " .. line)
            end
            outStream:writeln(" */")
        end

        -- Write parsed elements
        for _, element in pairs(elements) do
            if element.isObject then
                if element.doc and element.doc ~= "" then
                    outStream:writeln("/*!")
                    for line in string.gmatch(element.doc, "([^\n]+)") do
                        outStream:writeln(" * " .. line)
                    end
                    outStream:writeln(" */")
                end
                outStream:writeln("/*! \\class " .. element.name .. " */")
                outStream:writeln("struct " .. element.name .. " {")
                for _, member in ipairs(element.members) do
                    if member.doc and member.doc ~= "" then
                        outStream:writeln("/*!")
                        for line in string.gmatch(member.doc, "([^\n]+)") do
                            outStream:writeln(" * " .. line)
                        end
                        outStream:writeln(" */")
                    end
                    outStream:writeln("    /*! \\memberof " .. element.name .. " */")
                    outStream:writeln("    " .. member.name .. ";")
                end
                outStream:writeln("    // Methods")
                for _, fn in ipairs(element.functions) do
                    if fn.doc and fn.doc ~= "" then
                        for line in string.gmatch(fn.doc, "([^\n]+)") do
                            outStream:writeln("    //! " .. line)
                        end
                    end
                    outStream:writeln("    /*! \\memberof " .. fn.class .. " */")
                    outStream:writeln("    " .. fn.returnType .. " " .. fn.name .. "(" .. fn.args .. ");")
                end
                outStream:writeln("};")
            end
        end

        -- Write global functions
        for _, global in ipairs(globals) do
            if global.type == "function" then
                if global.doc and global.doc ~= "" then
                    outStream:writeln("/*!")
                    for line in string.gmatch(global.doc, "([^\n]+)") do
                        outStream:writeln(" * " .. line)
                    end
                    outStream:writeln(" */")
                end
                outStream:writeln(global.returnType .. " " .. global.name .. "(" .. global.args .. ");")
            end
        end
    else
        outStream:writeln("!empty file")
    end
end






--! \brief this application
TApp = class()

--! \brief constructor
function TApp.init(this)
	local t0 = TCore_Clock()
	this.timestamp = t0:getTimeStamp()
	this.name = 'Lua2DoX'
	this.version = '0.2 20130128'
	this.copyright = 'Copyright (c) Simon Dales 2012-13'
end

function TApp.getRunStamp(this)
	return this.name .. ' (' .. this.version .. ') ' 
		.. this.timestamp
end

function TApp.getVersion(this)
	return this.name .. ' (' .. this.version .. ') ' 
end

function TApp.getCopyright(this)
	return this.copyright 
end

local This_app = TApp()

--main
local cl = TCore_Commandline()

local argv1 = cl:getRaw(1)
if argv1 == '--help' then
	TCore_IO_writeln(This_app:getVersion())
	TCore_IO_writeln(This_app:getCopyright())
	TCore_IO_writeln([[
run as:
lua2dox_filter <param>
--------------
Param:
  <filename> : interprets filename
  --version  : show version/copyright info
  --help     : this help text]])
elseif argv1 == '--version' then
	TCore_IO_writeln(This_app:getVersion())
	TCore_IO_writeln(This_app:getCopyright())
else
	-- it's a filter
	local appStamp = This_app:getRunStamp()
	local filename = argv1
	
	local filter = TLua2DoX_filter()
	filter:readfile(appStamp,filename)
end


--eof