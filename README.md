# protoc-gen-lua53

protoc-gen-lua for lua5.3.4 and 5.1

## Features

- Support lua5.3.4 and 5.1
- Add 'package.path = package.path .. ";./lua/your_probobuf_generated_file_path/?.lua"' before you use any probobuf generated file
- Integer of uint64 type should be no more than 2^63£¬because it is really signed int in lua
- Don't use "table.insert(msg, v)" for repeated field, use "msg:append(v)" instead, because "__index" was triggered by "table.insert()" for lua5.3 but not for lua5.1

## Special Thanks

- protoc-gen-lua-lua: https://github.com/sean-lin/protoc-gen-lua
- protoc-gen-lua-bin-fix: https://github.com/memoryoff/protoc-gen-lua-bin-fix
