# FrameworkZ Documentation

The documentation system for FrameworkZ on Project Zomboid. This repository contains two documentation generators:

1. **Doxygen** (legacy) - Full-featured C++ documentation generator
2. **DocZ** (new) - Lightweight Lua-specific documentation generator

## DocZ — Lua Doxygen-style documentation generator

DocZ is a lightweight, dependency-free Lua documentation generator specifically designed for FrameworkZ and similar Lua projects. It recursively scans directories for `.lua` files, parses Doxygen-style comments, and generates clean HTML documentation.

### Features
- 🔍 **Recursive scanning** - Automatically finds all `.lua` files in a directory tree
- 📝 **Doxygen-style parsing** - Supports both `--!` and `---` comment prefixes
- 🏷️ **Rich tag support** - Handles `@brief`, `@class`, `@module`, `@param`, `@return`, `@field`, `@note`, `@see` and more
- 🔗 **Smart detection** - Automatically identifies functions, methods, tables, and classes
- 📱 **Modern HTML output** - Responsive design with clean styling and navigation
- ⚡ **Fast and lightweight** - No external dependencies, pure Lua implementation
- 🎯 **Project Zomboid optimized** - Tailored for FrameworkZ codebase patterns

### Quick Start

#### Using the Batch File (Recommended for Windows)
1. Double-click `Generate_DocZ_Documentation.bat`
2. The script will automatically detect your FrameworkZ installation
3. Open the generated `output/index.html` file in your browser

#### Manual Command Line Usage
```powershell
# From the fzDocumentation directory
lua .\bin\DocZ.lua -i ..\FrameworkZ\Contents\mods\FrameworkZ\media\lua -o .\output -t "FrameworkZ API"

# For testing with the example file
lua .\bin\DocZ.lua -i . -o .\output -t "DocZ Test Documentation"
```

#### Command Line Options
- `-i, --input`  Root folder to scan recursively for `.lua` files (required)
- `-o, --output` Output folder for HTML files (required)  
- `-t, --title`  Documentation title (default: "Lua API Reference")
- `-h, --help`   Show help and usage information

### Documentation Comment Syntax

DocZ supports standard Doxygen-style comments with both backslash and @ prefixes:

#### Basic Module Documentation
```lua
--! \brief Utility module for FrameworkZ
--! \class FrameworkZ.Utilities
--! \note This module provides common utility functions
FrameworkZ.Utilities = {}
```

#### Function Documentation
```lua
--! \brief Copies a table deeply
--! \param originalTable \table The table to copy
--! \param tableCopies \table (Internal) Used for cycle detection
--! \return \table A deep copy of the original table
--! \note This function handles circular references
--! \see FrameworkZ.Utilities:ShallowCopy
function FrameworkZ.Utilities:CopyTable(originalTable, tableCopies)
    -- Implementation here
end
```

#### Alternative @ Syntax
```lua
--- @brief Alternative comment style using --- and @
--- @param input string The input to process
--- @param options table Configuration options
--- @return string The processed result
function ProcessData(input, options)
    -- Implementation here  
end
```

### Supported Tags

| Tag | Description | Example |
|-----|-------------|---------|
| `@brief` / `\brief` | Short description | `@brief Creates a new timer` |
| `@class` / `\class` | Class/type name | `@class FrameworkZ.Timer` |
| `@module` / `\module` | Module name | `@module FrameworkZ.Utilities` |
| `@namespace` / `\namespace` | Namespace | `@namespace FrameworkZ` |
| `@param` / `\param` | Parameter info | `@param name string The object name` |
| `@return` / `\return` | Return value | `@return table The result object` |
| `@field` / `\field` | Class field | `@field value number The stored value` |
| `@note` / `\note` | Additional notes | `@note This is deprecated` |
| `@see` / `\see` | Cross-references | `@see FrameworkZ.Utilities:CopyTable` |

### Output Structure

DocZ generates a complete HTML documentation site:

```
output/
├── index.html      # Main entry point with overview
├── modules.html    # List of all modules/namespaces  
├── classes.html    # List of all classes and types
└── functions.html  # Complete function reference
```

### Features & Benefits

- **Zero Dependencies**: Pure Lua implementation, no external tools required
- **Fast Processing**: Optimized for large codebases like FrameworkZ
- **Smart Parsing**: Automatically detects undocumented functions and includes them
- **Modern UI**: Clean, responsive design that works on desktop and mobile
- **Navigation**: Easy browsing with table of contents and cross-linking
- **Project Zomboid Ready**: Understands FrameworkZ patterns and conventions

### Comparison with Doxygen

| Feature | DocZ | Doxygen |
|---------|------|---------|
| **Size** | ~800 lines of Lua | Large C++ application |
| **Dependencies** | None (just Lua) | Requires Doxygen installation |
| **Speed** | Very fast | Slower on large projects |
| **Lua Support** | Native, optimized | Generic, less Lua-aware |
| **Customization** | Easy to modify | Complex configuration |
| **Output** | Clean HTML | Multiple formats |
| **Learning Curve** | Minimal | Steeper |

### Development & Testing

The repository includes `test_example.lua` which demonstrates all supported documentation features. Use this for testing DocZ functionality:

```bash
lua .\bin\DocZ.lua -i . -o .\test_output -t "DocZ Test"
```

### Requirements

- **Lua 5.1+** (Project Zomboid includes Lua 5.1)
- **Windows/Linux/macOS** (tested on Windows with PowerShell)
- **No external dependencies**

### Troubleshooting

**Common Issues:**

1. **"lua not found"** - Ensure Lua is installed and in your PATH
   - Windows: Install Lua for Windows or use LuaRocks
   - Alternative: Use full path to lua.exe

2. **"Permission denied"** - Run as administrator or check file permissions

3. **"Input directory not found"** - Verify the FrameworkZ path is correct

4. **Empty output** - Check that `.lua` files contain DocZ-style comments (`--!` or `---`)

### Contributing

DocZ is designed to be easily extensible. Key areas for enhancement:
- Additional output formats (Markdown, PDF)
- More Doxygen tag support  
- Enhanced cross-referencing
- Theme customization
- Integration with IDEs

---

## Legacy Doxygen System

The original Doxygen-based system is still available via `Generate_Documentation.bat`. However, DocZ is recommended for new projects due to its simplicity and Lua-specific optimizations.

### When to Use Doxygen
- Need multiple output formats (PDF, LaTeX, etc.)
- Require advanced features like inheritance diagrams
- Working with mixed-language codebases
- Need existing Doxygen workflow integration

### When to Use DocZ  
- Pure Lua projects (recommended for FrameworkZ)
- Want fast, lightweight documentation generation
- Prefer simple setup with no external dependencies
- Need Project Zomboid/FrameworkZ specific optimizations
- Parsing is best-effort and resilient to mixed styles; it errs on including items even without docs.
- Methods declared with `:` are shown as `method` signatures.
- Fields and constants assigned under a module (e.g., `FrameworkZ.X.Y = 42`) are listed under that module.
