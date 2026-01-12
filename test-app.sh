#!/bin/bash
# 直接运行应用并查看控制台输出

cd /Users/joey_uni/Documents/LaterRead/laterread-mvp/menubar-app

echo "=== Building LaterRead ==="
swift build

echo ""
echo "=== Running LaterRead (Press Ctrl+C to stop) ==="
echo ""

# 直接运行可执行文件，这样可以看到 print 输出
.build/debug/LaterRead
