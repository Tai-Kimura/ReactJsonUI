# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class TabViewConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          style_attr = build_style_attr
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''
          testid_attr = build_testid_attr
          tag_attr = build_tag_attr
          tabs = json['tabs'] || []

          selected_binding = build_selected_binding
          on_change = build_on_change

          # Build tab bar items
          tab_items_jsx = tabs.each_with_index.map do |tab, index|
            build_tab_item(tab, index, selected_binding)
          end.join("\n")

          # Build tab content panels
          tab_panels_jsx = tabs.each_with_index.map do |tab, index|
            build_tab_panel(tab, index, selected_binding, indent + 4)
          end.join("\n")

          jsx = <<~JSX.chomp
            #{indent_str(indent)}<div#{id_attr} className="#{class_name}"#{style_attr}#{testid_attr}#{tag_attr}>
            #{indent_str(indent + 2)}<nav className="#{build_nav_class}">
            #{tab_items_jsx}
            #{indent_str(indent + 2)}</nav>
            #{indent_str(indent + 2)}<div className="flex-1 overflow-auto">
            #{tab_panels_jsx}
            #{indent_str(indent + 2)}</div>
            #{indent_str(indent)}</div>
          JSX

          wrap_with_visibility(jsx, indent)
        end

        protected

        def build_class_name
          classes = ['flex', 'flex-col', 'h-full']

          # Width/Height
          classes << TailwindMapper.map_width(json['width'])
          classes << TailwindMapper.map_height(json['height'])

          # Background
          if json['background']
            if has_binding?(json['background'])
              @dynamic_styles ||= {}
              @dynamic_styles['backgroundColor'] = convert_binding(json['background'])
            else
              classes << TailwindMapper.map_color(json['background'], 'bg')
            end
          end

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_nav_class
          classes = ['flex', 'border-t', 'border-gray-200']

          # Tab bar background
          if json['tabBarBackground']
            if has_binding?(json['tabBarBackground'])
              # Handle binding - will need dynamic style
              classes << 'bg-white' # fallback
            else
              classes << TailwindMapper.map_color(json['tabBarBackground'], 'bg')
            end
          else
            classes << 'bg-white'
          end

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_tab_item(tab, index, selected_binding)
          title = tab['title'] || "Tab #{index + 1}"
          icon = tab['icon'] || 'circle'
          badge = tab['badge']
          icon_type = tab['iconType'] || 'system'

          # Build icon component
          icon_jsx = build_icon(icon, tab['selectedIcon'], index, selected_binding, icon_type)

          # Build badge if present
          badge_jsx = build_badge(badge) if badge

          # Build button classes
          button_class = build_tab_button_class(index, selected_binding)

          # Show/hide labels
          show_labels = json['showLabels'] != false
          label_jsx = show_labels ? "\n#{indent_str(8)}<span className=\"text-xs mt-1\">#{title}</span>" : ''

          on_change = build_on_change

          <<~JSX.chomp
            #{indent_str(6)}<button
            #{indent_str(8)}className={`#{button_class}`}
            #{indent_str(8)}onClick={() => #{on_change}(#{index})}
            #{indent_str(6)}>
            #{indent_str(8)}<div className="relative">
            #{icon_jsx}#{badge_jsx ? "\n#{badge_jsx}" : ''}
            #{indent_str(8)}</div>#{label_jsx}
            #{indent_str(6)}</button>
          JSX
        end

        def build_tab_button_class(index, selected_binding)
          tint = json['tintColor'] || 'blue-600'
          unselected = json['unselectedColor'] || 'gray-500'

          tint_class = TailwindMapper.map_color(tint, 'text')
          unselected_class = TailwindMapper.map_color(unselected, 'text')

          base_classes = 'flex-1 flex flex-col items-center justify-center py-2 px-1 transition-colors'

          "${#{selected_binding} === #{index} ? '#{base_classes} #{tint_class}' : '#{base_classes} #{unselected_class} hover:text-gray-700'}"
        end

        def build_icon(icon, selected_icon, index, selected_binding, icon_type = 'system')
          if icon_type == 'resource'
            # Use image from assets
            selected_icon_name = selected_icon || icon
            if icon != selected_icon_name
              "#{indent_str(10)}{#{selected_binding} === #{index} ? <img src=\"/assets/#{selected_icon_name}.png\" className=\"w-6 h-6\" alt=\"\" /> : <img src=\"/assets/#{icon}.png\" className=\"w-6 h-6\" alt=\"\" />}"
            else
              "#{indent_str(10)}<img src=\"/assets/#{icon}.png\" className=\"w-6 h-6\" alt=\"\" />"
            end
          else
            # Map SF Symbol/Material icon names to Lucide React icons
            icon_name = map_to_lucide_icon(icon)
            selected_icon_name = selected_icon ? map_to_lucide_icon(selected_icon) : icon_name

            if selected_icon
              "#{indent_str(10)}{#{selected_binding} === #{index} ? <#{selected_icon_name} className=\"w-6 h-6\" /> : <#{icon_name} className=\"w-6 h-6\" />}"
            else
              "#{indent_str(10)}<#{icon_name} className=\"w-6 h-6\" />"
            end
          end
        end

        def build_badge(badge)
          if has_binding?(badge)
            binding_prop = extract_binding_property(badge)
            "#{indent_str(10)}{#{binding_prop} && <span className=\"absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full w-4 h-4 flex items-center justify-center\">{#{binding_prop}}</span>}"
          elsif badge.is_a?(Integer) && badge > 0
            "#{indent_str(10)}<span className=\"absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full w-4 h-4 flex items-center justify-center\">#{badge}</span>"
          elsif badge.is_a?(String) && !badge.empty?
            "#{indent_str(10)}<span className=\"absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full px-1 min-w-4 h-4 flex items-center justify-center\">#{badge}</span>"
          end
        end

        def build_tab_panel(tab, index, selected_binding, indent)
          view_name = tab['view']

          if view_name
            # Convert snake_case to PascalCase for React component name
            pascal_name = view_name.split('_').map(&:capitalize).join
            content = "<#{pascal_name}View />"
          else
            content = "<div className=\"p-4\">#{tab['title'] || "Tab #{index + 1}"} content</div>"
          end

          <<~JSX.chomp
            #{indent_str(indent)}{#{selected_binding} === #{index} && (
            #{indent_str(indent + 2)}#{content}
            #{indent_str(indent)})}
          JSX
        end

        def build_selected_binding
          selected = json['selectedIndex']

          if selected && has_binding?(selected)
            extract_binding_property(selected)
          else
            'data.selectedTab'
          end
        end

        def build_on_change
          handler = json['onTabChange']

          if handler && has_binding?(handler)
            extract_binding_property(handler)
          else
            # Generate setter from the binding
            selected = json['selectedIndex']
            raw_binding = if selected && has_binding?(selected)
                            extract_raw_binding_property(selected)
                          else
                            'selectedTab'
                          end
            setter_name = "set#{raw_binding[0].upcase}#{raw_binding[1..]}"
            add_viewmodel_data_prefix(setter_name)
          end
        end

        # Map SF Symbol/Material icon names to Lucide React icon component names
        def map_to_lucide_icon(icon)
          icon_map = {
            'house' => 'Home',
            'house.fill' => 'Home',
            'Home' => 'Home',
            'person' => 'User',
            'person.fill' => 'User',
            'Person' => 'User',
            'gearshape' => 'Settings',
            'gearshape.fill' => 'Settings',
            'gear' => 'Settings',
            'Settings' => 'Settings',
            'magnifyingglass' => 'Search',
            'Search' => 'Search',
            'heart' => 'Heart',
            'heart.fill' => 'Heart',
            'Favorite' => 'Heart',
            'star' => 'Star',
            'star.fill' => 'Star',
            'Star' => 'Star',
            'bell' => 'Bell',
            'bell.fill' => 'Bell',
            'Notifications' => 'Bell',
            'cart' => 'ShoppingCart',
            'cart.fill' => 'ShoppingCart',
            'ShoppingCart' => 'ShoppingCart',
            'list.bullet' => 'List',
            'List' => 'List',
            'square.grid.2x2' => 'LayoutGrid',
            'GridView' => 'LayoutGrid',
            'circle' => 'Circle',
            'Circle' => 'Circle'
          }
          icon_map[icon] || icon.split('.').first.split(/(?=[A-Z])/).map(&:capitalize).join
        end
      end
    end
  end
end
