# 故障排除

## 菜单栏 App

### 快捷键不工作

**症状**：按 `⌘⇧L` 没有反应

**解决方法**：
1. 系统设置 → 隐私与安全性 → 辅助功能
2. 确保 LaterRead 已添加并启用
3. 如果已添加，尝试移除后重新添加
4. 重启 LaterRead App

### 无法捕获浏览器页面

**症状**：按快捷键后提示"Cannot get page"

**解决方法**：
1. 系统设置 → 隐私与安全性 → 自动化
2. 找到 LaterRead → 勾选对应浏览器
3. 确保浏览器窗口有打开的标签页
4. 当前标签页不是空白页或设置页

**支持的浏览器**：
- ✅ Safari
- ✅ Chrome
- ✅ Arc
- ❌ Firefox（暂不支持）
- ❌ Edge（暂不支持）

### AI 分类不工作

**症状**：保存后显示"AI 分类失败"或"AI 分类跳过"

**原因和解决方法**：

1. **未设置 API Key**
   - 错误：`AI 分类跳过 - 未设置 API Key`
   - 解决：菜单栏 → Settings → 填入 OpenRouter API Key

2. **API Key 无效**
   - 错误：`API Key 无效或已过期`
   - 解决：检查 Key 格式是否为 `sk-or-...`
   - 验证：访问 [OpenRouter Activity](https://openrouter.ai/activity) 确认 Key 有效

3. **请求过于频繁**
   - 错误：`API 请求过于频繁，请稍后再试`
   - 解决：等待几秒后重试，或使用批量分类功能（自动限流）

4. **网络错误**
   - 错误：`网络错误: ...`
   - 解决：检查网络连接，确认能访问 OpenRouter API

5. **服务器错误**
   - 错误：`服务器错误 (500)`
   - 解决：OpenRouter 服务问题，稍后重试

### 批量分类失败

**症状**：批量分类时部分条目失败

**说明**：
- 批量分类会自动限流（每次请求间隔 0.5 秒）
- 部分失败不影响成功的条目
- 查看通知了解具体失败原因
- 可以再次点击 "Classify All" 重新分类失败的条目

### 保存失败

**症状**：按快捷键后提示"Save failed"

**解决方法**：

1. **检查 Vault 路径**
   - 默认路径：`~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Joeyyyyuwww`
   - 菜单栏 → Settings → 查看 Vault Path
   - 确认路径存在且可访问

2. **创建目录**
   ```bash
   mkdir -p ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Joeyyyyuwww/【00】LaterRead
   ```

3. **检查文件权限**
   ```bash
   ls -la ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Joeyyyyuwww/【00】LaterRead/
   ```

4. **手动创建 inbox.md**
   ```bash
   echo "# 📖 LaterRead Inbox" > ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Joeyyyyuwww/【00】LaterRead/inbox.md
   ```

### 菜单栏图标不显示

**症状**：菜单栏没有 📖 图标

**解决方法**：
1. 确认 App 正在运行（活动监视器中查找 LaterRead）
2. 重启 App
3. 检查是否被其他菜单栏图标遮挡
4. 尝试调整菜单栏图标顺序（按住 `⌘` 拖动）

---

## Obsidian 插件

### 侧边栏不显示

**症状**：点击左侧栏图标没反应

**解决方法**：
1. 设置 → 第三方插件 → 确保 LaterRead 已启用
2. 尝试使用命令面板：`⌘P` → "LaterRead: Open view"
3. 重启 Obsidian
4. 重新安装插件

### 分类不工作

**症状**：手动添加条目时 AI 分类失败

**解决方法**：
1. 插件设置 → 确认已填入 Claude API Key
2. 确保"自动分类"开关已开启
3. 网络连接正常
4. 条目会保存为"待分类"状态，可稍后手动分类

### 文件同步问题

**症状**：菜单栏 App 和 Obsidian 数据不一致

**说明**：
- 两者读写同一个 `inbox.md` 文件
- Obsidian 插件会自动监听文件变更

**解决方法**：
1. 关闭再打开 Obsidian 侧边栏强制刷新
2. 检查文件是否被其他程序占用
3. 确认 iCloud 同步完成

### 归档和 Digest 位置

**归档文件**：
- 位置：`【00】LaterRead/archive.md`
- 格式：按月份分组（如 `## 📅 2025-01`）

**Digest 文件**：
- 位置：`【00】LaterRead/YYYY-WXX.md`
- 示例：`2025-W02.md`（2025 年第 2 周）

---

## 数据同步

### iCloud 同步延迟

**症状**：不同设备上数据不同步

**说明**：
- 这是 iCloud Drive 的正常行为
- 通常几分钟内会自动同步

**加速同步**：
1. Finder → iCloud Drive → 右键 → 立即下载
2. 或等待自动同步完成

### 冲突文件

**症状**：出现 `inbox 2.md` 等冲突文件

**原因**：
- 两个设备同时编辑同一文件
- iCloud 无法自动合并

**解决方法**：
1. 手动比较两个文件内容
2. 合并到主文件 `inbox.md`
3. 删除冲突文件
4. 建议：同一时间只在一个设备上操作

---

## 性能问题

### App 启动慢

**可能原因**：
- inbox.md 文件过大（超过 1000 条）
- iCloud 同步中

**建议**：
- 定期归档已读条目
- 删除不需要的条目
- 使用 Obsidian 插件的归档功能

### 批量分类卡顿

**正常现象**：
- 批量分类需要调用多次 API
- 每次请求间隔 0.5 秒
- 100 条目约需 50 秒

**优化**：
- 分批处理（每次 20-30 条）
- 在空闲时进行批量分类

---

## 调试技巧

### 查看日志

**菜单栏 App**：
```bash
# 打开 Console.app
open /System/Applications/Utilities/Console.app

# 搜索 "LaterRead" 或 "[AI]"
```

**Obsidian 插件**：
1. 打开开发者工具：`⌘⌥I`
2. 切换到 Console 标签
3. 查看错误信息

### 重置配置

**删除 API Key**：
```bash
# 菜单栏 App
# 菜单栏 → Settings → Clear 按钮
```

**重新安装插件**：
```bash
cd laterread-mvp/obsidian-plugin
npm run build
cp main.js manifest.json ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Joeyyyyuwww/.obsidian/plugins/laterread/
```

---

## 常见错误代码

| 错误 | 说明 | 解决方法 |
|------|------|----------|
| 401 | API Key 无效 | 重新填入正确的 Key |
| 429 | 请求过于频繁 | 等待后重试或使用批量功能 |
| 500 | 服务器错误 | OpenRouter 问题，稍后重试 |
| Network error | 网络连接失败 | 检查网络和防火墙 |

---

## 获取帮助

如果以上方法都无法解决问题：

1. 查看 [GitHub Issues](https://github.com/yourusername/laterread/issues)
2. 提交新 Issue，包含：
   - macOS 版本
   - 问题描述
   - 错误日志
   - 复现步骤
