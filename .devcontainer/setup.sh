#!/usr/bin/env bash

if command -v p 2>&1 >/dev/null
then
    echo "P is already installed"
else
    echo "P is not installed. Installing..."
    dotnet tool install --global P
fi

# git config --global --add safe.directory ${containerWorkspaceFolder}

cat << EOF
▗▄▄▖     ▗▄▄▄ ▗▄▄▄▖▗▖  ▗▖
▐▌ ▐▌    ▐▌  █▐▌   ▐▌  ▐▌
▐▛▀▘     ▐▌  █▐▛▀▀▘▐▌  ▐▌
▐▌       ▐▙▄▄▀▐▙▄▄▖ ▝▚▞▘ 

Copyright (C) 2024 Shinwoo Kim
EOF

echo -ne "\t"
p -v
echo -ne "\t"
java --version
echo -e "\t.Net version: $(dotnet --version)"