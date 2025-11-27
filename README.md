# ReactJsonUI

Generate React components from JSON layouts with Tailwind CSS.

Part of the JsonUI family:
- [SwiftJsonUI](https://github.com/Tai-Kimura/SwiftJsonUI) - iOS (UIKit + SwiftUI)
- [KotlinJsonUI](https://github.com/Tai-Kimura/KotlinJsonUI) - Android (XML + Compose)
- **ReactJsonUI** - Web (React + Tailwind)

## Features

- 🎨 **JSON-driven UI** - Define layouts in JSON, generate React components
- 🎯 **Tailwind CSS** - Automatic mapping to Tailwind classes
- 🔄 **Same JSON spec** - Compatible with SwiftJsonUI/KotlinJsonUI
- ⚡ **No runtime overhead** - Static code generation

## Installation

```bash
# Clone the repository
git clone https://github.com/Tai-Kimura/ReactJsonUI.git

# Install Ruby dependencies
cd ReactJsonUI/rjui_tools
bundle install
```

## Quick Start

### 1. Initialize in your React project

```bash
cd your-react-app
/path/to/rjui_tools/bin/rjui init
```

This creates:
- `rjui.config.json` - Configuration file
- `src/Layouts/` - JSON layout definitions
- `src/generated/` - Generated React components

### 2. Create a view

```bash
rjui g view HomeView
```

### 3. Edit the JSON layout

```json
{
  "type": "View",
  "className": "flex flex-col p-4",
  "child": [
    {
      "type": "Label",
      "text": "Hello World!",
      "fontSize": 24,
      "fontColor": "#000000"
    },
    {
      "type": "Button",
      "text": "Click Me",
      "onClick": "handleClick",
      "background": "#007AFF",
      "fontColor": "#FFFFFF",
      "cornerRadius": 8,
      "padding": [12, 24]
    }
  ]
}
```

### 4. Build

```bash
rjui build
```

Generated component (`src/generated/components/HomeView.jsx`):

```jsx
import React from 'react';

export const HomeView = ({ handleClick }) => {
  return (
    <div className="flex flex-col p-4">
      <span className="text-2xl text-[#000000]">Hello World!</span>
      <button
        className="bg-[#007AFF] rounded-lg py-3 px-6 text-[#FFFFFF] cursor-pointer"
        onClick={handleClick}
      >
        Click Me
      </button>
    </div>
  );
};

export default HomeView;
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `rjui init` | Initialize ReactJsonUI in current project |
| `rjui build` | Generate React components from JSON |
| `rjui g view <name>` | Generate a new view layout |
| `rjui help` | Show help |

## Configuration

`rjui.config.json`:

```json
{
  "layouts_directory": "src/Layouts",
  "generated_directory": "src/generated",
  "components_directory": "src/generated/components",
  "styles_directory": "src/Styles",
  "use_tailwind": true,
  "typescript": false
}
```

## Supported Components

| Component | HTML Element | Notes |
|-----------|-------------|-------|
| View | `<div>` | Container with flex layout |
| Label | `<span>` | Text display |
| Button | `<button>` | Clickable button |
| Image | `<img>` | Image display |
| TextField | `<input>` | Text input |

## JSON to Tailwind Mapping

| JSON Attribute | Tailwind Class |
|----------------|---------------|
| `padding: [12]` | `p-3` |
| `padding: [12, 24]` | `py-3 px-6` |
| `cornerRadius: 8` | `rounded-lg` |
| `fontSize: 16` | `text-base` |
| `background: "#007AFF"` | `bg-[#007AFF]` |
| `fontColor: "#FFFFFF"` | `text-[#FFFFFF]` |
| `width: "matchParent"` | `w-full` |
| `orientation: "horizontal"` | `flex flex-row` |

## License

MIT License
