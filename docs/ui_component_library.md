# Sprout Lands UI 组件库（UI-00）

本目录提供一组局部、可实例化的 Godot 4 原生 `Control` 控件。基础组件负责显示与交互，由业务界面组合使用；订单、库存、存档等状态由调用方管理。独立预览仍使用模拟数据。

## 预览

打开 `scenes/ui/components/ui_component_preview.tscn` 运行独立预览。页面底部状态栏会记录按钮、弹窗、物品格、滚动列表和分类切换的结果；页面顶部明确标注“模拟数据”。预览不接游戏主场景、不暂停游戏、不锁定玩家；项目配置中的自动加载单例仍随引擎启动，预览脚本不使用它们管理业务状态。

## 组件 API

### `SproutTheme`

文件：`scripts/ui/components/sprout_theme.gd`

- `SproutTheme.make_theme() -> Theme`：创建一份局部主题。
- `SproutTheme.icon(index) -> AtlasTexture`：从现有 `assets/ui/all_icons.png` 取 16×16 图标区域。
- `panel_style()`、`button_style(color)`、`selected_style()`：创建九宫格面板/按钮样式。

主题使用现有 `assets/ui/zcool_kuail.ttf` 显示中文，键帽/像素图标使用现有 Sprout Lands 资源。代码只引用资源，不复制或修改下载目录。

### `SproutButton`

文件：`scripts/ui/components/sprout_button.gd`

```gdscript
var button := SproutButton.new()
button.configure("打开", 0)
button.activated.connect(_on_button_activated)
container.add_child(button)
```

`pressed` 是 Godot 原生信号，`activated(button)` 是带按钮实例的简洁包装信号。鼠标、Enter/Space 键盘激活均由原生 `Button` 处理；主题提供正常、悬停、按下、禁用和焦点样式。

### `SproutModal`

文件：`scripts/ui/components/sprout_modal.gd`

```gdscript
var modal := SproutModal.new()
add_child(modal)
modal.confirmed.connect(_on_confirmed)
modal.cancelled.connect(_on_cancelled)
modal.closed.connect(_on_closed)
modal.show_modal("标题", "内容", "确认")
```

`show_modal` 打开局部遮罩并把焦点给确认按钮；确认、取消、右上角关闭和 `Esc` 都会关闭，关闭时发出 `closed`。它不调用暂停、不广播全局事件。关闭后遮罩隐藏，焦点由调用方决定。

弹窗底部的取消/确认操作按钮使用 `SproutButton.set_icon_visible(false)` 与 `set_focus_visual(false)`：文字保持居中，不显示业务图标，也不额外绘制绿色焦点框；按钮仍保留 `FOCUS_ALL`，因此 Enter/Space、Tab 和鼠标行为不变。普通 `SproutButton` 默认仍显示图标和主题焦点框。

#### 二级操作弹窗规范

二级操作弹窗指从已有弹窗内发起的短操作，例如重命名、删除前的再次确认。此类操作必须在原弹窗上方叠加较小的居中弹窗；下层保留可见，以便玩家知道正在操作哪一项。整页导航或主流程切换不属于本规范。

- **保留上下文**：下层标题、列表、选中项、滚动位置保持不变，不能隐藏列表或把原弹窗内容替换成编辑表单。上层配局部半透明遮罩，尺寸小于下层，长名称和错误文案应换行。
- **隔离输入**：只有最上层接收操作。遮罩拦截鼠标，下层按钮停用，Tab、Shift+Tab 和方向键的焦点导航限制在上层。点击遮罩不提交、不关闭、不触发下层按钮。
- **安全默认焦点**：重命名打开后聚焦并全选输入框；删除确认默认聚焦“取消”，直接按 Enter 不应删除。
- **逐层关闭**：取消、关闭按钮或 Esc 只关闭最上层，不改变数据，不连带关闭下层。恢复发起操作的控件焦点；该控件已被删除时，转移到下层安全控件（如“取消”）。
- **提交与失败**：成功后关闭上层并刷新下层相关内容，保留仍存在的选中项和滚动位置；滚动位置超出新列表范围时允许夹到有效范围。失败时上层保持打开，保留输入和下层上下文，在上层显示错误并允许重试。提交期间禁用重复操作。

正确示例：存档列表 → 点击行内铅笔 → 上层输入新名称 → 保存 → 原列表显示新名称。反例：把整个存档列表替换成“重命名存档”，或一次 Esc 同时关闭两层。

当前组合实现见 `scripts/ui/save_selection_modal.gd`：复用 `SproutModal` 构造上层弹窗，并由调用方管理下层禁用、焦点循环、业务结果与恢复。基础 `SproutModal` 本身不提供自动弹窗栈；需要等待业务结果的组合应覆盖默认确认即关闭行为。

验收应在 1152×648、1280×720 下检查两层可见及尺寸，执行取消、关闭、Esc、重复打开、鼠标遮罩拦截、键盘焦点循环、默认 Enter 取消删除、成功刷新与失败保留输入。若出现穿透、上下文丢失或两层同时关闭，应修正组合方的输入隔离和关闭路由，再重跑这些场景。修改基础弹窗或焦点导航时需重新验收。

### `SproutItemSlot`

文件：`scripts/ui/components/sprout_item_slot.gd`

```gdscript
var slot := SproutItemSlot.new()
slot.configure("apple", "苹果", 3, 5, false)
slot.slot_selected.connect(_on_slot_selected)
container.add_child(slot)
slot.set_selected(true)
```

`configure(id, label, quantity, icon_index, disabled)` 设置展示数据；`slot_selected(item_id)` 只报告选择，不写入任何库存。

### `SproutScrollList`

文件：`scripts/ui/components/sprout_scroll_list.gd`

```gdscript
var list := SproutScrollList.new()
list.item_selected.connect(_on_item_selected)
container.add_child(list)
list.set_items([{"id": "soup", "label": "蘑菇汤", "icon": 10}])
list.set_items([]) # 显示空状态
```

列表内部使用 `ScrollContainer`；条目为空时显示“暂无模拟条目”。

### `SproutCategoryTabs`

文件：`scripts/ui/components/sprout_category_tabs.gd`

```gdscript
var tabs := SproutCategoryTabs.new()
tabs.category_changed.connect(_on_category_changed)
container.add_child(tabs)
tabs.set_categories([
    {"id": "food", "label": "料理"},
    {"id": "tool", "label": "工具"},
])
```

`category_changed(category_id)` 报告选择结果，当前分类使用浅绿色选中样式。分类内容由调用方决定，不在组件内持有业务状态。

## 素材与授权

本票据仅用于非商业原型。Sprout Lands Basic Pack 作者为 Cup Nooble，来源与许可说明保留在下载包 `read_me.txt`；Basic Pack 允许非商业项目使用，但禁止再分发或转售素材包。项目只引用已有的 `ui_big_play_blank.png`、`all_icons.png`、`sprout_lands.ttf`，中文使用已有 `zcool_kuail.ttf`，没有新增或重绘图片。
