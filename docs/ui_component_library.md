# Sprout Lands UI 组件库（UI-00）

本目录提供一组局部、可实例化的 Godot 4 原生 `Control` 控件。它们服务于后续道具界面票据，当前只演示组件行为，**不接真实订单、库存、配方、奖励或声望状态**。

## 预览

打开 `scenes/ui/components/ui_component_preview.tscn` 运行独立预览。页面底部状态栏会记录按钮、弹窗、物品格、滚动列表和分类切换的结果；页面顶部明确标注“模拟数据”。预览不接游戏主场景、不暂停游戏、不锁定玩家，也没有自动加载单例。

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
