import { App, Plugin, PluginSettingTab, Setting, Notice, TFile, WorkspaceLeaf, ItemView, Modal } from 'obsidian';

// ============== 数据结构 ==============
interface ReadingItem {
  id: string;
  url: string;
  title: string;
  domain: string;
  summary: string;
  category: string;
  note: string;
  createdAt: string;
  isRead: boolean;
}

interface LaterReadSettings {
  openrouterApiKey: string;
  inboxPath: string;
  archivePath: string;
  digestPath: string;
  autoClassify: boolean;
}

const DEFAULT_SETTINGS: LaterReadSettings = {
  openrouterApiKey: '',
  inboxPath: '【00】LaterRead/inbox.md',
  archivePath: '【00】LaterRead/archive.md',
  digestPath: '【00】LaterRead',
  autoClassify: true
};

// 与 Swift App 保持一致的 10 个分类
const CATEGORIES: Record<string, { emoji: string; name: string; keywords: string }> = {
  'ai-tech': { emoji: '🤖', name: 'AI/Tech', keywords: 'AI, machine learning, LLM, GPT, Claude, deep learning, neural network, automation, agents, prompts' },
  'dev-tools': { emoji: '🛠️', name: 'Dev Tools', keywords: 'programming, coding, developer tools, IDE, API, SDK, framework, library, open source' },
  'product': { emoji: '📦', name: 'Product', keywords: 'product launch, startup, SaaS, app, tool, software, service, platform' },
  'design': { emoji: '🎨', name: 'Design', keywords: 'UI, UX, design system, figma, interface, visual, typography, branding' },
  'business': { emoji: '💼', name: 'Business', keywords: 'startup, funding, investment, strategy, growth, marketing, sales, revenue' },
  'research': { emoji: '📚', name: 'Research', keywords: 'paper, study, academic, methodology, analysis, experiment, findings' },
  'career': { emoji: '🎯', name: 'Career', keywords: 'job, hiring, interview, resume, skills, career growth, salary, remote work' },
  'productivity': { emoji: '⚡', name: 'Productivity', keywords: 'workflow, efficiency, habits, time management, tools, automation, life hacks' },
  'reading': { emoji: '📖', name: 'Reading', keywords: 'book, article, blog post, newsletter, essay, long read, writing' },
  'general': { emoji: '📌', name: 'General', keywords: 'everything else, misc, uncategorized' }
};

const CATEGORY_ORDER = ['ai-tech', 'dev-tools', 'product', 'design', 'business', 'research', 'career', 'productivity', 'reading', 'general'];

// ============== 主插件 ==============
export default class LaterReadPlugin extends Plugin {
  settings: LaterReadSettings;
  items: ReadingItem[] = [];

  async onload() {
    await this.loadSettings();
    await this.loadItems();

    // 注册侧边栏视图
    this.registerView(
      'laterread-view',
      (leaf) => new LaterReadView(leaf, this)
    );

    // 添加图标到左侧栏
    this.addRibbonIcon('book-open', 'LaterRead', () => {
      this.activateView();
    });

    // 注册命令
    this.addCommand({
      id: 'add-from-clipboard',
      name: '从剪贴板添加链接',
      callback: () => this.addFromClipboard()
    });

    this.addCommand({
      id: 'add-manual',
      name: '手动添加链接',
      callback: () => new AddItemModal(this.app, this).open()
    });

    this.addCommand({
      id: 'generate-digest',
      name: '生成周末阅读清单',
      callback: () => this.generateDigest()
    });

    this.addCommand({
      id: 'open-laterread',
      name: '打开 LaterRead 面板',
      callback: () => this.activateView()
    });

    this.addCommand({
      id: 'archive-all-read',
      name: '归档所有已读',
      callback: () => this.archiveAllRead()
    });

    // 设置页
    this.addSettingTab(new LaterReadSettingTab(this.app, this));

    // 监听文件变化（菜单栏 App 可能写入）
    this.registerEvent(
      this.app.vault.on('modify', (file) => {
        if (file.path === this.settings.inboxPath) {
          this.loadItems();
        }
      })
    );
  }

  async activateView() {
    const { workspace } = this.app;
    let leaf = workspace.getLeavesOfType('laterread-view')[0];
    
    if (!leaf) {
      leaf = workspace.getRightLeaf(false);
      await leaf.setViewState({ type: 'laterread-view', active: true });
    }
    
    workspace.revealLeaf(leaf);
  }

  async loadSettings() {
    this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
  }

  async saveSettings() {
    await this.saveData(this.settings);
  }

  // ============== 数据操作 ==============
  async loadItems() {
    const file = this.app.vault.getAbstractFileByPath(this.settings.inboxPath);
    if (!file || !(file instanceof TFile)) {
      this.items = [];
      return;
    }

    const content = await this.app.vault.read(file);
    this.items = this.parseMarkdown(content);
    
    // 刷新视图
    this.app.workspace.getLeavesOfType('laterread-view').forEach(leaf => {
      if (leaf.view instanceof LaterReadView) {
        leaf.view.refresh();
      }
    });
  }

  parseMarkdown(content: string): ReadingItem[] {
    const items: ReadingItem[] = [];
    const lines = content.split('\n');

    // 支持所有 emoji 的正则
    const allEmojis = Object.values(CATEGORIES).map(c => c.emoji).join('|');
    const pattern = new RegExp(`^- \\[([ x])\\] (${allEmojis}) \\[(.+?)\\]\\((.+?)\\) \\| (.+?) \\| (.+?)$`);

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const match = line.match(pattern);
      if (match) {
        const [, checked, emoji, title, url, domain, date] = match;
        const category = Object.entries(CATEGORIES).find(([, v]) => v.emoji === emoji)?.[0] || 'general';

        const item: ReadingItem = {
          id: this.generateId(),
          url,
          title,
          domain,
          summary: '',
          category,
          note: '',
          createdAt: date,
          isRead: checked === 'x'
        };

        // 检查下一行是否是摘要
        if (i + 1 < lines.length && lines[i + 1].startsWith('>  ')) {
          item.summary = lines[i + 1].substring(3);
        }

        // 检查是否有备注 ("> 📝 " 前缀)
        if (i + 2 < lines.length && lines[i + 2].startsWith('> 📝 ')) {
          item.note = lines[i + 2].substring(5);
        } else if (i + 1 < lines.length && lines[i + 1].startsWith('> 📝 ')) {
          item.note = lines[i + 1].substring(5);
        }

        items.push(item);
      }
    }

    return items;
  }

  async saveItems() {
    const content = this.generateMarkdown();
    const file = this.app.vault.getAbstractFileByPath(this.settings.inboxPath);
    
    if (file && file instanceof TFile) {
      await this.app.vault.modify(file, content);
    } else {
      // 确保目录存在
      const dir = this.settings.inboxPath.substring(0, this.settings.inboxPath.lastIndexOf('/'));
      if (dir && !this.app.vault.getAbstractFileByPath(dir)) {
        await this.app.vault.createFolder(dir);
      }
      await this.app.vault.create(this.settings.inboxPath, content);
    }
  }

  generateMarkdown(): string {
    let md = '# 📖 LaterRead Inbox\n\n';

    // 按分类分组
    const grouped: Record<string, ReadingItem[]> = {};
    for (const item of this.items) {
      if (!grouped[item.category]) grouped[item.category] = [];
      grouped[item.category].push(item);
    }

    for (const cat of CATEGORY_ORDER) {
      const catItems = grouped[cat];
      if (!catItems || catItems.length === 0) continue;

      const catInfo = CATEGORIES[cat];
      if (!catInfo) continue;

      md += `## ${catInfo.emoji} ${catInfo.name}\n\n`;

      for (const item of catItems) {
        const checkbox = item.isRead ? 'x' : ' ';
        const emoji = CATEGORIES[item.category]?.emoji || '📌';
        md += `- [${checkbox}] ${emoji} [${item.title}](${item.url}) | ${item.domain} | ${item.createdAt}\n`;

        if (item.summary) {
          md += `>  ${item.summary}\n`;
        }
        if (item.note) {
          md += `> 📝 ${item.note}\n`;
        }
        md += '\n';
      }
    }

    return md;
  }

  // ============== 添加条目 ==============
  async addFromClipboard() {
    const text = await navigator.clipboard.readText();
    
    // 尝试提取 URL
    const urlMatch = text.match(/https?:\/\/[^\s]+/);
    if (!urlMatch) {
      new Notice('剪贴板中没有找到有效链接');
      return;
    }

    const url = urlMatch[0];
    await this.addItem(url);
  }

  async addItem(url: string, note: string = '') {
    // 获取页面信息
    let title = url;
    let domain = 'unknown';
    
    try {
      const urlObj = new URL(url);
      domain = urlObj.hostname.replace('www.', '');
      
      // 尝试获取标题（通过 fetch）
      const response = await fetch(url);
      const html = await response.text();
      const titleMatch = html.match(/<title>([^<]+)<\/title>/i);
      if (titleMatch) {
        title = titleMatch[1].trim();
      }
    } catch (e) {
      console.log('Failed to fetch page info:', e);
    }

    const item: ReadingItem = {
      id: this.generateId(),
      url,
      title,
      domain,
      summary: '',
      category: 'general',
      note,
      createdAt: new Date().toISOString().split('T')[0],
      isRead: false
    };

    // AI 分类 (OpenRouter)
    if (this.settings.autoClassify && this.settings.openrouterApiKey) {
      try {
        const result = await this.classifyWithAI(item);
        item.summary = result.summary;
        item.category = result.category;
      } catch (e) {
        console.log('AI classification failed:', e);
      }
    }

    this.items.unshift(item);
    await this.saveItems();
    
    new Notice(`✓ 已保存: ${item.title}`);
    
    // 刷新视图
    this.app.workspace.getLeavesOfType('laterread-view').forEach(leaf => {
      if (leaf.view instanceof LaterReadView) {
        leaf.view.refresh();
      }
    });
  }

  generateCategoryPrompt(): string {
    let prompt = 'Categories (choose the BEST match):\n';
    for (const key of CATEGORY_ORDER) {
      const cat = CATEGORIES[key];
      if (cat) {
        prompt += `- ${key}: ${cat.name} - ${cat.keywords}\n`;
      }
    }
    return prompt;
  }

  async classifyWithAI(item: ReadingItem): Promise<{ summary: string; category: string }> {
    const categoryPrompt = this.generateCategoryPrompt();

    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this.settings.openrouterApiKey}`
      },
      body: JSON.stringify({
        model: 'google/gemini-2.5-flash-preview-05-20',
        max_tokens: 200,
        messages: [{
          role: 'user',
          content: `分析这篇文章并提供：
1. 中文摘要（1-2句话，最多80字）
2. 分类（从下面选择最匹配的分类 key）

标题: ${item.title}
URL: ${item.url}
来源: ${item.domain}

${categoryPrompt}

重要：
- 必须选择一个具体分类，只有在完全无法归类时才用 "general"
- 返回分类 key（如 "ai-tech", "product"），不是名称
- 摘要必须是中文

只返回 JSON: {"summary": "中文摘要", "category": "分类key"}`
        }]
      })
    });

    const data = await response.json();
    const text = data.choices?.[0]?.message?.content || '{}';

    try {
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        return JSON.parse(jsonMatch[0]);
      }
    } catch (e) {
      console.log('Failed to parse AI response:', e);
    }

    return { summary: '', category: 'general' };
  }

  // ============== 标记已读 ==============
  async markAsRead(item: ReadingItem, archive: boolean = true) {
    item.isRead = true;

    if (archive) {
      await this.archiveItem(item);
      this.items = this.items.filter(i => i.id !== item.id);
    }

    await this.saveItems();
  }

  async deleteItem(item: ReadingItem) {
    this.items = this.items.filter(i => i.id !== item.id);
    await this.saveItems();
  }

  // ============== 归档功能 ==============
  async archiveItem(item: ReadingItem) {
    const archivePath = this.settings.archivePath;

    // 确保目录存在
    const dir = archivePath.substring(0, archivePath.lastIndexOf('/'));
    if (dir && !this.app.vault.getAbstractFileByPath(dir)) {
      await this.app.vault.createFolder(dir);
    }

    // 读取现有归档内容
    let archiveContent = '';
    const file = this.app.vault.getAbstractFileByPath(archivePath);
    if (file && file instanceof TFile) {
      archiveContent = await this.app.vault.read(file);
    } else {
      archiveContent = '# 📚 LaterRead Archive\n\n';
    }

    // 获取当前月份
    const now = new Date();
    const monthKey = `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}`;
    const monthHeader = `## 📅 ${monthKey}`;

    // 生成条目内容
    const catInfo = CATEGORIES[item.category] || CATEGORIES['general'];
    let itemContent = `- [x] ${catInfo.emoji} [${item.title}](${item.url}) | ${item.domain} | ${item.createdAt}\n`;
    if (item.summary) {
      itemContent += `>  ${item.summary}\n`;
    }
    if (item.note) {
      itemContent += `> 📝 ${item.note}\n`;
    }
    itemContent += '\n';

    // 插入到对应月份
    if (archiveContent.includes(monthHeader)) {
      // 找到月份标题后插入
      const headerIndex = archiveContent.indexOf(monthHeader);
      const insertIndex = headerIndex + monthHeader.length + 2; // +2 for \n\n
      archiveContent = archiveContent.slice(0, insertIndex) + itemContent + archiveContent.slice(insertIndex);
    } else {
      // 新月份，添加到文件开头（标题后）
      const headerEnd = archiveContent.indexOf('\n\n') + 2;
      const newSection = `${monthHeader}\n\n${itemContent}`;
      archiveContent = archiveContent.slice(0, headerEnd) + newSection + archiveContent.slice(headerEnd);
    }

    // 写入文件
    if (file && file instanceof TFile) {
      await this.app.vault.modify(file, archiveContent);
    } else {
      await this.app.vault.create(archivePath, archiveContent);
    }

    new Notice(`📚 已归档: ${item.title}`);
  }

  // 批量归档所有已读
  async archiveAllRead() {
    const readItems = this.items.filter(i => i.isRead);
    if (readItems.length === 0) {
      new Notice('没有已读条目需要归档');
      return;
    }

    for (const item of readItems) {
      await this.archiveItem(item);
    }

    this.items = this.items.filter(i => !i.isRead);
    await this.saveItems();

    new Notice(`✓ 已归档 ${readItems.length} 篇文章`);
  }

  // ============== 生成 Digest ==============
  async generateDigest() {
    const unreadItems = this.items.filter(i => !i.isRead);
    
    if (unreadItems.length === 0) {
      new Notice('没有待读内容');
      return;
    }

    const now = new Date();
    const weekNum = this.getWeekNumber(now);
    const filename = `${this.settings.digestPath}/${now.getFullYear()}-W${weekNum.toString().padStart(2, '0')}.md`;

    let md = `# 📚 周末阅读清单 ${now.getFullYear()}-W${weekNum}\n\n`;
    md += `> 生成于 ${now.toLocaleDateString('zh-CN')} · 共 ${unreadItems.length} 篇待读\n\n---\n\n`;

    // 按分类分组
    const grouped: Record<string, ReadingItem[]> = {};
    for (const item of unreadItems) {
      if (!grouped[item.category]) grouped[item.category] = [];
      grouped[item.category].push(item);
    }

    for (const cat of CATEGORY_ORDER) {
      const catItems = grouped[cat];
      if (!catItems || catItems.length === 0) continue;

      const catInfo = CATEGORIES[cat];
      if (!catInfo) continue;

      md += `## ${catInfo.emoji} ${catInfo.name}\n\n`;
      
      for (const item of catItems) {
        md += `### [${item.title}](${item.url})\n\n`;
        md += `- **来源**: ${item.domain}\n`;
        md += `- **添加**: ${item.createdAt}\n`;
        if (item.summary) {
          md += `- **摘要**: ${item.summary}\n`;
        }
        if (item.note) {
          md += `\n> 📝 ${item.note}\n`;
        }
        md += '\n';
      }
    }

    md += `---\n\n*由 LaterRead 自动生成*`;

    // 写入文件
    const existingFile = this.app.vault.getAbstractFileByPath(filename);
    if (existingFile && existingFile instanceof TFile) {
      await this.app.vault.modify(existingFile, md);
    } else {
      await this.app.vault.create(filename, md);
    }

    new Notice(`✓ 已生成: ${filename}`);
    
    // 打开文件
    const file = this.app.vault.getAbstractFileByPath(filename);
    if (file && file instanceof TFile) {
      this.app.workspace.getLeaf().openFile(file);
    }
  }

  getWeekNumber(date: Date): number {
    const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
    const pastDaysOfYear = (date.getTime() - firstDayOfYear.getTime()) / 86400000;
    return Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7);
  }

  generateId(): string {
    return Math.random().toString(36).substring(2, 9);
  }
}

// ============== 侧边栏视图 ==============
class LaterReadView extends ItemView {
  plugin: LaterReadPlugin;

  constructor(leaf: WorkspaceLeaf, plugin: LaterReadPlugin) {
    super(leaf);
    this.plugin = plugin;
  }

  getViewType(): string {
    return 'laterread-view';
  }

  getDisplayText(): string {
    return 'LaterRead';
  }

  getIcon(): string {
    return 'book-open';
  }

  async onOpen() {
    this.refresh();
  }

  refresh() {
    const container = this.containerEl.children[1];
    container.empty();

    // 头部
    const header = container.createDiv({ cls: 'laterread-header' });
    header.createEl('h4', { text: '📖 LaterRead' });
    
    const stats = header.createDiv({ cls: 'laterread-stats' });
    const unreadCount = this.plugin.items.filter(i => !i.isRead).length;
    stats.setText(`${unreadCount} 篇待读`);

    // 工具栏
    const toolbar = container.createDiv({ cls: 'laterread-toolbar' });

    const addBtn = toolbar.createEl('button', { text: '+ 添加' });
    addBtn.onclick = () => new AddItemModal(this.app, this.plugin).open();

    const digestBtn = toolbar.createEl('button', { text: '📋 Digest' });
    digestBtn.onclick = () => this.plugin.generateDigest();

    const archiveBtn = toolbar.createEl('button', { text: '📚 归档已读' });
    archiveBtn.onclick = () => this.plugin.archiveAllRead().then(() => this.refresh());

    // 列表
    const list = container.createDiv({ cls: 'laterread-list' });
    
    if (this.plugin.items.length === 0) {
      list.createDiv({ cls: 'laterread-empty', text: '暂无待读内容\n按 Ctrl/Cmd+P 搜索 "LaterRead" 添加' });
      return;
    }

    for (const item of this.plugin.items.filter(i => !i.isRead)) {
      const itemEl = list.createDiv({ cls: 'laterread-item' });

      // 分类 emoji + 标题
      const titleRow = itemEl.createDiv({ cls: 'laterread-item-title' });
      const catInfo = CATEGORIES[item.category] || CATEGORIES['general'];
      titleRow.createSpan({ text: catInfo.emoji + ' ' });
      
      const link = titleRow.createEl('a', { text: item.title, href: item.url });
      link.onclick = (e) => {
        e.preventDefault();
        window.open(item.url, '_blank');
      };

      // 元信息
      const meta = itemEl.createDiv({ cls: 'laterread-item-meta' });
      meta.setText(`${item.domain} · ${item.createdAt}`);

      // 摘要
      if (item.summary) {
        const summary = itemEl.createDiv({ cls: 'laterread-item-summary' });
        summary.setText(item.summary);
      }

      // 备注
      if (item.note) {
        const note = itemEl.createDiv({ cls: 'laterread-item-note' });
        note.setText('📝 ' + item.note);
      }

      // 操作按钮
      const actions = itemEl.createDiv({ cls: 'laterread-item-actions' });
      
      const readBtn = actions.createEl('button', { text: '✓ 已读' });
      readBtn.onclick = async () => {
        await this.plugin.markAsRead(item);
        this.refresh();
      };
      
      const deleteBtn = actions.createEl('button', { text: '✕' });
      deleteBtn.onclick = async () => {
        await this.plugin.deleteItem(item);
        this.refresh();
      };
    }

    // 样式
    this.addStyles();
  }

  addStyles() {
    const style = document.getElementById('laterread-styles') || document.createElement('style');
    style.id = 'laterread-styles';
    style.textContent = `
      .laterread-header { display: flex; justify-content: space-between; align-items: center; padding: 10px; border-bottom: 1px solid var(--background-modifier-border); }
      .laterread-header h4 { margin: 0; }
      .laterread-stats { font-size: 12px; color: var(--text-muted); }
      .laterread-toolbar { display: flex; gap: 8px; padding: 10px; border-bottom: 1px solid var(--background-modifier-border); }
      .laterread-toolbar button { font-size: 12px; padding: 4px 8px; }
      .laterread-list { padding: 10px; }
      .laterread-empty { text-align: center; color: var(--text-muted); padding: 20px; white-space: pre-line; }
      .laterread-item { padding: 10px; margin-bottom: 8px; background: var(--background-secondary); border-radius: 6px; }
      .laterread-item-title { font-weight: 500; margin-bottom: 4px; }
      .laterread-item-title a { color: var(--text-normal); text-decoration: none; }
      .laterread-item-title a:hover { color: var(--text-accent); }
      .laterread-item-meta { font-size: 11px; color: var(--text-muted); margin-bottom: 4px; }
      .laterread-item-summary { font-size: 12px; color: var(--text-muted); margin-bottom: 4px; }
      .laterread-item-note { font-size: 12px; color: var(--text-accent); }
      .laterread-item-actions { display: flex; gap: 8px; margin-top: 8px; }
      .laterread-item-actions button { font-size: 11px; padding: 2px 6px; }
    `;
    document.head.appendChild(style);
  }
}

// ============== 添加弹窗 ==============
class AddItemModal extends Modal {
  plugin: LaterReadPlugin;
  url: string = '';
  note: string = '';

  constructor(app: App, plugin: LaterReadPlugin) {
    super(app);
    this.plugin = plugin;
  }

  onOpen() {
    const { contentEl } = this;
    contentEl.createEl('h3', { text: '添加到 LaterRead' });

    new Setting(contentEl)
      .setName('URL')
      .addText(text => {
        text.setPlaceholder('https://...');
        text.onChange(value => this.url = value);
        
        // 自动粘贴剪贴板
        navigator.clipboard.readText().then(clipText => {
          if (clipText.match(/^https?:\/\//)) {
            text.setValue(clipText);
            this.url = clipText;
          }
        });
      });

    new Setting(contentEl)
      .setName('备注')
      .addText(text => {
        text.setPlaceholder('可选备注...');
        text.onChange(value => this.note = value);
      });

    new Setting(contentEl)
      .addButton(btn => {
        btn.setButtonText('保存');
        btn.setCta();
        btn.onClick(async () => {
          if (!this.url) {
            new Notice('请输入 URL');
            return;
          }
          await this.plugin.addItem(this.url, this.note);
          this.close();
        });
      })
      .addButton(btn => {
        btn.setButtonText('取消');
        btn.onClick(() => this.close());
      });
  }

  onClose() {
    this.contentEl.empty();
  }
}

// ============== 设置页 ==============
class LaterReadSettingTab extends PluginSettingTab {
  plugin: LaterReadPlugin;

  constructor(app: App, plugin: LaterReadPlugin) {
    super(app, plugin);
    this.plugin = plugin;
  }

  display(): void {
    const { containerEl } = this;
    containerEl.empty();

    containerEl.createEl('h2', { text: 'LaterRead 设置' });

    new Setting(containerEl)
      .setName('OpenRouter API Key')
      .setDesc('用于自动分类和生成摘要 (使用 Gemini 3 Pro)')
      .addText(text => text
        .setPlaceholder('sk-or-...')
        .setValue(this.plugin.settings.openrouterApiKey)
        .onChange(async (value) => {
          this.plugin.settings.openrouterApiKey = value;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('自动分类')
      .setDesc('添加时自动调用 AI 分类')
      .addToggle(toggle => toggle
        .setValue(this.plugin.settings.autoClassify)
        .onChange(async (value) => {
          this.plugin.settings.autoClassify = value;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('Inbox 文件路径')
      .addText(text => text
        .setValue(this.plugin.settings.inboxPath)
        .onChange(async (value) => {
          this.plugin.settings.inboxPath = value;
          await this.plugin.saveSettings();
        }));

    new Setting(containerEl)
      .setName('Digest 目录')
      .addText(text => text
        .setValue(this.plugin.settings.digestPath)
        .onChange(async (value) => {
          this.plugin.settings.digestPath = value;
          await this.plugin.saveSettings();
        }));
  }
}
