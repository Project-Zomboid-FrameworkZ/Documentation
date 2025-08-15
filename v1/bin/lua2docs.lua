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

-- Function to convert Doxygen comments to proper format
function convertDoxygenToJSDoc(docText)
    if not docText or docText == "" then
        return ""
    end
    
    -- Keep Doxygen syntax since we're using Doxygen to process the JavaScript
    -- Just clean up the formatting for better readability
    
    return docText
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
	TCore_IO_write('# ZZ: ')
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
	TCore_IO_write('# Lua2DoX new eof')
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
    -- Look for return statements and handle multiple types properly
    local allReturns = {}
    
    -- Common Lua types for validation (map to JavaScript equivalents)
    local commonTypes = {
        ["boolean"] = "boolean", ["string"] = "string", ["number"] = "number", ["table"] = "object", 
        ["integer"] = "number", ["void"] = "void", ["nil"] = "void", ["userdata"] = "object",
        ["function"] = "function", ["list"] = "Array", ["dict"] = "object"
    }
    
    for _, dl in ipairs(docLines) do
        local rline = dl:match("\\return%s+(.*)")
        if rline then
            local types = {}
            
            -- Method 1: Look for backslash syntax: \boolean \string description
            local pos = 1
            while pos <= #rline do
                local startPos, endPos, foundType = string.find(rline, "\\([%w_]+)", pos)
                if foundType then
                    if commonTypes[foundType] then
                        table.insert(types, commonTypes[foundType])
                    end
                    pos = endPos + 1
                else
                    break
                end
            end
            
            -- Method 2: If no backslash types, look for space-separated types at start
            if #types == 0 then
                local words = {}
                for word in rline:gmatch("([%w_]+)") do
                    table.insert(words, word)
                end
                
                -- Only take consecutive types from the beginning
                for i, word in ipairs(words) do
                    if commonTypes[word] then
                        table.insert(types, commonTypes[word])
                    else
                        break -- Stop at first non-type word (description)
                    end
                end
            end
            
            -- Method 3: If still no types, just take first word if it's a type
            if #types == 0 then
                local firstWord = rline:match("([%w_]+)")
                if firstWord and commonTypes[firstWord] then
                    table.insert(types, commonTypes[firstWord])
                elseif firstWord then
                    table.insert(types, firstWord) -- Use it anyway as fallback
                end
            end
            
            -- Add all types from this return statement
            for _, t in ipairs(types) do
                table.insert(allReturns, t)
            end
        end
    end

    if #allReturns == 0 then
        return "void"
    elseif #allReturns == 1 then
        return allReturns[1]
    else
        -- Multiple return values - JavaScript array syntax
        return "[" .. table.concat(allReturns, ", ") .. "]"
    end
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

	local inFunctionDoc = false
    local inTableDefinition = false
    local tableDefinitionBraceCount = 0
    local globals = {}
    local elements = {}
    local processedClasses = {}
    local currentClass = nil
    local docBuffer = {}
    local generalDocs = {}

    local function flushDocBuffer()
        local buffer = table.concat(docBuffer, "\n")
        docBuffer = {}
        return buffer
    end

    local function writeGeneralDocs()
        if #generalDocs > 0 then
            outStream:writeln("/*!")
            for _, line in ipairs(generalDocs) do
                outStream:writeln(" * " .. line)
            end
            outStream:writeln(" */")
        end
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
        return returnTypeFromDoc(docBuffer)
    end

    local function enhanceParameterTypes(fnArgs, docLines)
        -- Map parameter names to their types from documentation
        local paramTypes = {}
        local typeMap = {
            ["boolean"] = "boolean", ["string"] = "string", ["number"] = "number", ["table"] = "object",
            ["integer"] = "number", ["function"] = "function", ["userdata"] = "object"
        }
        
        -- Parse \param directives
        for _, dl in ipairs(docLines) do
            local paramLine = dl:match("\\param%s+(.*)")
            if paramLine then
                -- Pattern: \param paramName \type description
                local paramName, paramType = paramLine:match("([%w_]+)%s+\\([%w_]+)")
                if paramName and paramType and typeMap[paramType] then
                    paramTypes[paramName] = typeMap[paramType]
                end
            end
        end
        
        -- Enhance function arguments with type hints
        if fnArgs and fnArgs ~= "" then
            local enhancedArgs = {}
            for arg in string.gmatch(fnArgs, "([%w_]+)") do
                if paramTypes[arg] then
                    table.insert(enhancedArgs, arg .. " /*" .. paramTypes[arg] .. "*/")
                else
                    table.insert(enhancedArgs, arg)
                end
            end
            return table.concat(enhancedArgs, ", ")
        end
        
        return fnArgs or ""
    end

    if inStream:getContents(Filename) then
        local line
        while not (err or inStream:eof()) do
            line = string_trim(inStream:getLine())

            -- Handle table definition brace counting
            local skipThisLine = false
            if inTableDefinition then
                -- Count opening and closing braces on this line
                for _ in string.gmatch(line, "{") do
                    tableDefinitionBraceCount = tableDefinitionBraceCount + 1
                end
                for _ in string.gmatch(line, "}") do
                    tableDefinitionBraceCount = tableDefinitionBraceCount - 1
                end
                
                -- If braces are balanced, we're done with the table
                if tableDefinitionBraceCount <= 0 then
                    inTableDefinition = false
                    tableDefinitionBraceCount = 0
                end
                
                -- Skip processing lines inside table definitions (except comments)
                if inTableDefinition and not string.match(line, "^%s*%-%-") then
                    skipThisLine = true
                end
            end

            if not skipThisLine and string.sub(line, 1, 2) == "--" then
                -- Handle comments
                if string.sub(line, 3, 3) == "!" then
                    table.insert(docBuffer, string.sub(line, 4))
                elseif string.sub(line, 3, 5) == "[[!" then
                    -- Handle multi-line comments
                    line = string.sub(line, 5)
                    local comment = ""
                    while not inStream:eof() do
                        local closeSquare = string.find(line, "]]")
                        if closeSquare then
                            comment = comment .. string.sub(line, 1, closeSquare - 1)
                            break
                        else
                            comment = comment .. line .. "\n"
                            line = inStream:getLine()
                        end
                    end
                    for commentLine in string.gmatch(comment, "([^\n]+)") do
                        table.insert(docBuffer, commentLine)
                    end
                else
                    --table.insert(docBuffer, string.sub(line, 3))
                end

            elseif not skipThisLine and string.find(table.concat(docBuffer, "\n"), "\\class%s+") then
                -- Class definition with explicit \class directive
                local className, classDoc = detectClassFromDoc()
                if className then
                    if processedClasses[className] then
                        print("Warning: Duplicate class name detected: " .. className)
                    else
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

            elseif not skipThisLine and #docBuffer > 0 and string.match(line, "^%s*([%w_.]+)%s*=%s*") then
                -- Check if this could be a class/object definition with documentation
                local varName = string.match(line, "^%s*([%w_.]+)%s*=%s*")
                local varValue = string.match(line, "^%s*[%w_.]+%s*=%s*(.*)$")
                
                if varName and string.find(varName, "%.") then
                    -- Check if this is a member of an existing class
                    local parentClass = varName:match("^(.+)%.[^%.]+$")
                    local memberName = varName:match("([^%.]+)$")
                    
                    -- Clean up the variable value and check for table definitions FIRST
                    if varValue then
                        varValue = string_trim(varValue)
                        local commentPos = string.find(varValue, "%-%-")
                        if commentPos then
                            varValue = string_trim(string.sub(varValue, 1, commentPos - 1))
                        end
                        
                        -- Check if this is a table definition
                        if string.find(varValue, "{") then
                            inTableDefinition = true
                            tableDefinitionBraceCount = 0
                            -- Count opening braces on this line
                            for _ in string.gmatch(varValue, "{") do
                                tableDefinitionBraceCount = tableDefinitionBraceCount + 1
                            end
                            -- Count closing braces on this line  
                            for _ in string.gmatch(varValue, "}") do
                                tableDefinitionBraceCount = tableDefinitionBraceCount - 1
                            end
                            -- If braces are balanced on this line, we're done with the table
                            if tableDefinitionBraceCount <= 0 then
                                inTableDefinition = false
                                tableDefinitionBraceCount = 0
                            end
                        end
                    end
                    
                    if parentClass and elements[parentClass] then
                        -- This is a member of an existing class - add it as a member variable
                        local varDoc = flushDocBuffer()
                        table.insert(elements[parentClass].members, {
                            type = "variable",
                            name = memberName,
                            fullName = varName,
                            doc = varDoc
                        })
                    else
                        -- This looks like a module/class assignment (e.g., FrameworkZ.Characters = {})
                        local hasClassDoc = false
                        local isClassOrModule = false
                        
                        for _, comment in ipairs(docBuffer) do
                            if string.match(comment, "\\brief") or string.match(comment, "\\class") then
                                hasClassDoc = true
                            end
                            if string.match(comment, "\\class") then
                                isClassOrModule = true
                            end
                        end
                        
                        -- Clean up the variable value
                        if varValue then
                            varValue = string_trim(varValue)
                            local commentPos = string.find(varValue, "%-%-")
                            if commentPos then
                                varValue = string_trim(string.sub(varValue, 1, commentPos - 1))
                            end
                        end
                        
                        if hasClassDoc and (isClassOrModule or (varValue and string.match(varValue, "^%s*{%s*}?%s*$"))) then
                            -- This looks like a class/module definition
                            local classDoc = table.concat(docBuffer, "\n")
                            elements[varName] = {
                                name = varName,
                                isObject = true,
                                members = {},
                                functions = {},
                                doc = classDoc
                            }
                            currentClass = varName
                            flushDocBuffer()
                        else
                            -- Regular variable assignment with documentation
                            local varDoc = flushDocBuffer()
                            table.insert(globals, {
                                type = "variable",
                                name = varName,
                                value = varValue,
                                doc = varDoc
                            })
                        end
                    end
                else
                    -- Simple variable assignment
                    local varDoc = flushDocBuffer()
                    table.insert(globals, {
                        type = "variable", 
                        name = varName,
                        value = varValue,
                        doc = varDoc
                    })
                end

            elseif not skipThisLine and string.match(line, '^%s*function%s') then
                inFunctionDoc = true
				
				-- Function definition
                local fnSignature = string.match(line, "^%s*function%s+(.+)$")
                local returnType = getReturnTypeFromDoc()
                
                -- Store docBuffer before flushing for parameter enhancement
                local docBufferCopy = {}
                for _, doc in ipairs(docBuffer) do
                    table.insert(docBufferCopy, doc)
                end
                
                local fnDoc = flushDocBuffer()

                -- Extract function name and arguments more carefully
                local namespace, baseFnName, fnArgs = "", "", ""
                
                if fnSignature then
                    -- First try to match with parentheses
                    local nameAndArgs = string.match(fnSignature, "^(.-)%s*%((.*)%)%s*$")
                    if nameAndArgs then
                        local fullName = string.match(fnSignature, "^(.-)%s*%(")
                        fnArgs = string.match(fnSignature, "%((.*)%)") or ""
                        
                        -- Extract namespace and function name
                        if string.find(fullName, "[.:]") then
                            namespace, baseFnName = string.match(fullName, "^(.-)[.:]([^.:]+)$")
                            
                            -- For methods using : syntax, we don't need to modify fnArgs since
                            -- the : doesn't add 'self' to the parameter list in the function definition
                            -- The 'self' is implicit and handled by the : syntax itself
                        else
                            baseFnName = fullName
                        end
                    else
                        -- Function without parentheses (shouldn't happen but let's be safe)
                        baseFnName = fnSignature
                    end
                end
				
                baseFnName = baseFnName or "UnnamedFunction"
                namespace = namespace or ""

                if baseFnName then
                    if currentClass or (namespace and namespace ~= "") then
                        local fullNamespace = namespace ~= "" and namespace or currentClass
                        if fullNamespace and fullNamespace ~= "" then
                            if not elements[fullNamespace] then
                                elements[fullNamespace] = {
                                    name = fullNamespace,
                                    isObject = true,
                                    members = {},
                                    functions = {},
                                    doc = ""
                                }
                            end
                            local enhancedArgs = enhanceParameterTypes(fnArgs, docBufferCopy)
                            table.insert(elements[fullNamespace].functions, {
                                name = baseFnName,
                                class = fullNamespace,
                                args = enhancedArgs,
                                doc = fnDoc,
                                returnType = returnType or "None"
                            })
                        end
                    else
                        -- Only add to globals if it's truly a standalone function
                        -- Don't add methods that clearly belong to a class/module but we haven't detected the class yet
                        local hasNamespacePattern = string.find(fnSignature or "", "%.")
                        local looksLikeMethod = string.find(fnSignature or "", ":")
                        local isConstructorLike = string.match(baseFnName, "^[A-Z]")
                        
                        if not hasNamespacePattern and not looksLikeMethod and not isConstructorLike then
                            local enhancedArgs = enhanceParameterTypes(fnArgs, docBufferCopy)
                            table.insert(globals, {
                                type = "function",
                                name = baseFnName,
                                args = enhancedArgs,
                                doc = fnDoc,
                                returnType = returnType or "None"
                            })
                        end
                    end
                end

            elseif not skipThisLine and string.find(line, "^%s*end%s*$") then
                currentClass = nil
				inFunctionDoc = false

            elseif not skipThisLine and inFunctionDoc == false and not inTableDefinition and string.find(line, "%s*=%s*") then
                -- Handle variable assignments
                local varName, varValue = string.match(line, "^%s*([%w_.]+)%s*=%s*(.*)$")
                if varName then
                    local varDoc = flushDocBuffer()
                    
                    -- Clean up the variable value (remove trailing comments, whitespace)
                    if varValue then
                        varValue = string_trim(varValue)
                        -- Remove inline comments
                        local commentPos = string.find(varValue, "%-%-")
                        if commentPos then
                            varValue = string_trim(string.sub(varValue, 1, commentPos - 1))
                        end
                    end
                    
                    local varEntry = {
                        type = "variable",
                        name = varName,
                        value = varValue,
                        doc = varDoc
                    }
                    
                    -- Determine if this should be added to a class or as a global
                    local isClassMember = false
                    if currentClass then
                        -- We're inside a class context
                        table.insert(elements[currentClass].members, varEntry)
                        isClassMember = true
                    else
                        -- Check if this looks like a class member assignment (e.g., SomeClass.member = value)
                        local possibleClass = string.match(varName, "^([%w_]+)%.")
                        if possibleClass and elements[possibleClass] then
                            table.insert(elements[possibleClass].members, varEntry)
                            isClassMember = true
                        else
                            -- Check for multi-level namespace patterns (e.g., Module.SubModule.member)
                            local namespaceParts = {}
                            for part in string.gmatch(varName, "([%w_]+)") do
                                table.insert(namespaceParts, part)
                            end
                            
                            -- Try to find the longest matching namespace
                            if #namespaceParts > 1 then
                                for i = #namespaceParts - 1, 1, -1 do
                                    local possibleNamespace = table.concat(namespaceParts, ".", 1, i)
                                    if elements[possibleNamespace] then
                                        table.insert(elements[possibleNamespace].members, varEntry)
                                        isClassMember = true
                                        break
                                    end
                                end
                            end
                        end
                    end
                    
                    -- Only add to globals if it's truly a global (no dots or simple constants)
                    if not isClassMember then
                        -- Only add simple names or constants to globals
                        if not string.find(varName, "%.") or string.match(varName, "^[A-Z_][A-Z0-9_]*$") then
                            table.insert(globals, varEntry)
                        end
                    end
                end

            else
                for _, comment in ipairs(docBuffer) do
                    table.insert(generalDocs, comment)
                end
                flushDocBuffer()
            end
        end

        -- Write JavaScript namespace and module structure
        outStream:writeln("/*!")
        outStream:writeln(" * \\file")
        outStream:writeln(" * \\brief FrameworkZ Lua Documentation")
        outStream:writeln(" */")
        outStream:writeln("")

        -- Write general documentation
        writeGeneralDocs()

        -- Write parsed elements
        for _, element in pairs(elements) do
            if element.isObject then
                -- Write class documentation first
				if element.doc and element.doc ~= "" then
                    outStream:writeln("/*!")
                    local convertedDoc = convertDoxygenToJSDoc(element.doc)
                    for line in string.gmatch(convertedDoc, "([^\n]+)") do
                        outStream:writeln(" * " .. line)
                    end
                    outStream:writeln(" */")
                end
                
                -- Use JavaScript class/namespace declaration
                outStream:writeln("/*!")
                outStream:writeln(" * \\class " .. element.name)
                if element.doc and element.doc ~= "" then
                    local convertedDoc = convertDoxygenToJSDoc(element.doc)
                    for line in string.gmatch(convertedDoc, "([^\n]+)") do
                        outStream:writeln(" * " .. line)
                    end
                end
                outStream:writeln(" */")
                
                -- Generate proper JavaScript namespace syntax
                local varName = element.name
                if string.find(varName, "%.") then
                    -- For namespaced names like FrameworkZ.Characters, declare without var
                    outStream:writeln(varName .. " = {")
                else
                    -- For simple names, use var declaration
                    outStream:writeln("var " .. varName .. " = {")
                end
                
                -- Write member variables/constants as object properties
                for _, member in ipairs(element.members) do
                    if member.name then
                        if member.doc and member.doc ~= "" then
                            outStream:writeln("    /*!")
                            for line in string.gmatch(member.doc, "([^\n]+)") do
                                outStream:writeln("     * " .. line)
                            end
                            outStream:writeln("     */")
                        end
                        
                        local valueStr = ""
                        if member.value and member.value ~= "" then
                            valueStr = " = " .. member.value
                        end
                        
                        -- Determine member type - JavaScript style
                        local memberType = ""
                        if string.match(member.name, "^[A-Z_][A-Z0-9_]*$") then
                            -- Constants get proper typing based on value
                            local valueType = "number"
                            if member.value then
                                if string.match(member.value, "^['\"].*['\"]$") then
                                    valueType = "string"
                                elseif member.value == "true" or member.value == "false" then
                                    valueType = "boolean"
                                end
                            end
                            memberType = " /* " .. valueType .. " */"
                        else
                            -- Regular members
                            memberType = ""
                        end
                        
                        -- Output as JavaScript object property
                        local propName = member.name
                        
                        -- Fix property names that would be invalid in JavaScript object syntax
                        if string.find(propName, "%.") then
                            -- Skip properties with dots as they're likely assignments, not object properties
                            goto continue_member
                        end
                        
                        if member.value and member.value ~= "" then
                            outStream:writeln("    " .. propName .. ": " .. member.value .. "," .. memberType)
                        else
                            outStream:writeln("    " .. propName .. ": undefined," .. memberType)
                        end
                        
                        ::continue_member::
                    end
                end
                
                -- Add spacing between members and functions if we have both
                if #element.members > 0 and #element.functions > 0 then
                    outStream:writeln("")
                end
                
                outStream:writeln("};")
                outStream:writeln("")
                
                -- Write member functions as proper JavaScript function declarations
                for _, fn in ipairs(element.functions) do
                    if fn.name then
                        if fn.doc and fn.doc ~= "" then
                            outStream:writeln("/*!")
                            local convertedDoc = convertDoxygenToJSDoc(fn.doc)
                            for line in string.gmatch(convertedDoc, "([^\n]+)") do
                                outStream:writeln(" * " .. line)
                            end
                            outStream:writeln(" */")
                        end
                        -- Generate proper JavaScript function declaration that Doxygen can parse
                        outStream:writeln(element.name .. "." .. fn.name .. " = function(" .. (fn.args or "") .. ") {")
                        outStream:writeln("    // " .. (fn.returnType or "void"))
                        outStream:writeln("};")
                        outStream:writeln("")
                    end
                end
            end
        end

        -- Write global functions and variables (only truly global items)
        local hasGlobalConstants = false
        local hasGlobalVariables = false 
        local hasGlobalFunctions = false
        
        -- Check what we actually have
        for _, global in ipairs(globals) do
            if global.type == "function" then
                hasGlobalFunctions = true
            elseif global.type == "variable" then
                if string.match(global.name, "^[A-Z_][A-Z0-9_]*$") then
                    hasGlobalConstants = true
                else
                    hasGlobalVariables = true
                end
            end
        end
        
        if hasGlobalConstants then
            outStream:writeln("/*! \\defgroup GlobalConstants Global Constants")
            outStream:writeln(" * Global constants used throughout the framework")
            outStream:writeln(" * @{")
            outStream:writeln(" */")
        end
        
        if hasGlobalVariables then
            outStream:writeln("/*! \\defgroup GlobalVariables Global Variables") 
            outStream:writeln(" * Global variables and module references")
            outStream:writeln(" * @{")
            outStream:writeln(" */")
        end
        
        if hasGlobalFunctions then
            outStream:writeln("/*! \\defgroup GlobalFunctions Global Functions")
            outStream:writeln(" * Standalone utility functions")
            outStream:writeln(" * @{")
            outStream:writeln(" */")
        end
        
        for _, global in ipairs(globals) do
            if global.type == "function" then
                if global.doc and global.doc ~= "" then
                    outStream:writeln("/*!")
                    for line in string.gmatch(global.doc, "([^\n]+)") do
                        outStream:writeln(" * " .. line)
                    end
                    outStream:writeln(" * \\ingroup GlobalFunctions")
                    outStream:writeln(" */")
                end
                outStream:writeln("function " .. global.name .. "(" .. (global.args or "") .. ") { /* returns " .. (global.returnType or "void") .. " */ }")
                outStream:writeln("")
            elseif global.type == "variable" then
                if global.doc and global.doc ~= "" then
                    outStream:writeln("/*!")
                    for line in string.gmatch(global.doc, "([^\n]+)") do
                        outStream:writeln(" * " .. line)
                    end
                    
                    -- Determine group membership
                    if string.match(global.name, "^[A-Z_][A-Z0-9_]*$") then
                        outStream:writeln(" * \\ingroup GlobalConstants")
                    else
                        outStream:writeln(" * \\ingroup GlobalVariables")
                    end
                    outStream:writeln(" */")
                end
                local valueStr = ""
                if global.value and global.value ~= "" then
                    valueStr = " = " .. global.value
                end
                
                -- JavaScript syntax for constants and variables with better type detection
                if string.match(global.name, "^[A-Z_][A-Z0-9_]*$") then
                    -- Constants: detect type from value
                    local valueType = "number"
                    if global.value then
                        if string.match(global.value, "^['\"].*['\"]$") then
                            valueType = "string"
                        elseif global.value == "true" or global.value == "false" then
                            valueType = "boolean"
                        end
                    end
                    outStream:writeln("const " .. global.name .. " = " .. (global.value or "undefined") .. "; /* " .. valueType .. " */")
                else
                    -- Variables: use var/let
                    outStream:writeln("var " .. global.name .. " = " .. (global.value or "undefined") .. ";")
                end
                outStream:writeln("")
            end
        end
        
        if hasGlobalFunctions then
            outStream:writeln("/*! @} */") -- Close GlobalFunctions
        end
        if hasGlobalVariables then
            outStream:writeln("/*! @} */") -- Close GlobalVariables  
        end
        if hasGlobalConstants then
            outStream:writeln("/*! @} */") -- Close GlobalConstants
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