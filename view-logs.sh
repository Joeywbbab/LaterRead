#!/bin/bash
# LaterRead 日志查看脚本

echo "=== 正在监控 LaterRead 日志 ==="
echo "请在应用中执行操作（添加链接、点击 Classify All 等）"
echo "按 Ctrl+C 停止"
echo ""

# 使用 log stream 实时查看日志
log stream --predicate 'processImagePath CONTAINS "LaterRead" OR eventMessage CONTAINS "[AI]" OR eventMessage CONTAINS "[Settings]" OR eventMessage CONTAINS "[LaterRead]"' --level debug 2>&1
