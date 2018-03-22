# protoc-gen-lua53

protoc-gen-lua for lua5.3.4

## Features

- Support lua5.3.4
- User should predefined a global table "_ModType" as entry, it is just a hack for my project, not very reasonable
- Integer of uint64 type should be no more than 2^63£¬because it is really signed int in lua

## Special Thanks

- protoc-gen-lua-lua: https://github.com/sean-lin/protoc-gen-lua
- protoc-gen-lua-bin-fix: https://github.com/memoryoff/protoc-gen-lua-bin-fix
