# frozen_string_literal: true

require_relative '../tailwind_mapper'
require_relative '../helpers/string_manager_helper'

module RjuiTools
  module React
    module Converters
      class BaseConverter
        include Helpers::StringManagerHelper

        attr_reader :json, :config

        def initialize(json, config)
          @json = json
          @config = config
          @use_tailwind = config['use_tailwind'] != false
        end

        def convert(indent = 2)
          raise NotImplementedError, 'Subclasses must implement convert method'
        end

        protected

        def build_class_name
          classes = []
          @dynamic_styles = {}

          # Width/Height
          classes << TailwindMapper.map_width(json['width'])
          classes << TailwindMapper.map_height(json['height'])

          # Padding (array format)
          classes << TailwindMapper.map_padding(json['padding'] || json['paddings'])

          # Individual paddings (topPadding, bottomPadding, leftPadding, rightPadding)
          classes << TailwindMapper.map_individual_paddings(
            json['topPadding'],
            json['rightPadding'],
            json['bottomPadding'],
            json['leftPadding']
          )

          # Margin (array format)
          classes << TailwindMapper.map_margin(json['margins'])

          # Individual margins (topMargin, bottomMargin, leftMargin, rightMargin)
          classes << TailwindMapper.map_individual_margins(
            json['topMargin'],
            json['rightMargin'],
            json['bottomMargin'],
            json['leftMargin']
          )

          # Background - check for dynamic binding
          if json['background']
            if has_binding?(json['background'])
              @dynamic_styles['backgroundColor'] = convert_binding(json['background'])
            else
              classes << TailwindMapper.map_color(json['background'], 'bg')
            end
          end

          # Corner radius
          classes << TailwindMapper.map_corner_radius(json['cornerRadius']) if json['cornerRadius']

          # Text color - check for dynamic binding
          if json['fontColor']
            if has_binding?(json['fontColor'])
              @dynamic_styles['color'] = convert_binding(json['fontColor'])
            else
              classes << TailwindMapper.map_color(json['fontColor'], 'text')
            end
          end

          # Font size
          classes << TailwindMapper.map_font_size(json['fontSize']) if json['fontSize']

          # Font weight
          classes << TailwindMapper.map_font_weight(json['fontWeight']) if json['fontWeight']

          # Text align
          classes << TailwindMapper.map_text_align(json['textAlign'])

          # Orientation (flex)
          classes << TailwindMapper.map_orientation(json['orientation'])

          # Shadow
          classes << TailwindMapper.map_shadow(json['shadow']) if json['shadow']

          # Border
          classes << TailwindMapper.map_border(json['borderWidth'], json['borderColor']) if json['borderWidth'] || json['borderColor']

          # Opacity/Alpha
          opacity = json['opacity'] || json['alpha']
          classes << TailwindMapper.map_opacity(opacity) if opacity && opacity < 1

          # Visibility (hidden attribute - static)
          classes << TailwindMapper.map_visibility(json['hidden']) if json['hidden']

          # Visibility attribute (supports data binding)
          # If it's a binding, we'll handle it with conditional class
          if json['visibility'] && !has_binding?(json['visibility'])
            classes << 'hidden' unless json['visibility']
          end

          # Clip to bounds
          classes << TailwindMapper.map_overflow(json['clipToBounds']) if json['clipToBounds']

          # Z-index
          classes << TailwindMapper.map_z_index(json['zIndex']) if json['zIndex']

          # Flex grow (weight)
          classes << TailwindMapper.map_flex_grow(json['weight']) if json['weight']

          # Gravity alignment
          classes.concat(TailwindMapper.map_gravity(json['gravity'])) if json['gravity']

          # Direction (RTL/LTR)
          classes << TailwindMapper.map_direction(json['direction']) if json['direction']

          # Additional className from JSON
          classes << json['className'] if json['className']

          classes.compact.reject(&:empty?).join(' ')
        end

        def has_binding?(value)
          value.is_a?(String) && value.include?('@{')
        end

        def build_style_attr
          return '' if @dynamic_styles.nil? || @dynamic_styles.empty?

          style_pairs = @dynamic_styles.map do |key, value|
            # Remove braces from the value since we're inside a JSX expression
            clean_value = value.gsub(/^\{|\}$/, '')
            "#{key}: #{clean_value}"
          end

          " style={{ #{style_pairs.join(', ')} }}"
        end

        def convert_children(indent)
          # Support both 'children' and 'child' keys
          child_array = json['children'] || json['child']
          return '' unless child_array.is_a?(Array)

          child_array.filter_map do |child|
            # Skip data-only elements (they define props, not rendered content)
            next nil if data_only_element?(child)

            converter = create_converter_for_child(child)
            converter.convert(indent + 2)
          end.join("\n")
        end

        # Check if a child element is a data-only element (should not be rendered)
        # Data-only element: { "data": [...] } with only the data key
        def data_only_element?(child)
          return false unless child.is_a?(Hash)
          child.keys == ['data'] && child['data'].is_a?(Array)
        end

        def create_converter_for_child(child)
          # Check if this is an include component
          if child['include']
            require_relative 'include_converter'
            return IncludeConverter.new(child, config)
          end

          # Apply style if specified
          resolved_child = apply_style(child)

          converter_class = get_converter_class(resolved_child['type'])
          converter_class.new(resolved_child, config)
        end

        def apply_style(child)
          return child unless child['style']

          style_name = child['style']
          style_data = load_style(style_name)
          return child unless style_data

          # Merge style with child (child attributes override style)
          merged = style_data.merge(child)
          merged.delete('style')
          merged
        end

        def load_style(style_name)
          styles_dir = config['styles_directory'] || 'src/Styles'
          style_path = File.join(styles_dir, "#{style_name}.json")

          return nil unless File.exist?(style_path)

          JSON.parse(File.read(style_path))
        rescue JSON::ParserError
          nil
        end

        def get_converter_class(type)
          # First check extension converters
          extension_converters = config['_extension_converters'] || {}
          return extension_converters[type] if extension_converters[type]

          require_relative 'view_converter'
          require_relative 'label_converter'
          require_relative 'button_converter'
          require_relative 'image_converter'
          require_relative 'text_field_converter'
          require_relative 'text_view_converter'
          require_relative 'scroll_view_converter'
          require_relative 'collection_converter'
          require_relative 'toggle_converter'
          require_relative 'slider_converter'
          require_relative 'segment_converter'
          require_relative 'radio_converter'
          require_relative 'progress_converter'
          require_relative 'indicator_converter'
          require_relative 'select_box_converter'
          require_relative 'include_converter'
          require_relative 'icon_label_converter'
          require_relative 'gradient_view_converter'
          require_relative 'blur_converter'
          require_relative 'circle_view_converter'
          require_relative 'web_converter'
          require_relative 'switch_converter'
          require_relative 'network_image_converter'

          {
            'View' => ViewConverter,
            'SafeAreaView' => ViewConverter,
            'Label' => LabelConverter,
            'Text' => LabelConverter,
            'Button' => ButtonConverter,
            'Image' => ImageConverter,
            'CircleImage' => ImageConverter,
            'NetworkImage' => NetworkImageConverter,
            'TextField' => TextFieldConverter,
            'TextView' => TextViewConverter,
            'Scroll' => ScrollViewConverter,
            'ScrollView' => ScrollViewConverter,
            'Collection' => CollectionConverter,
            'Table' => CollectionConverter,
            'Switch' => SwitchConverter,
            'Toggle' => ToggleConverter,
            'Check' => ToggleConverter,
            'Checkbox' => ToggleConverter,
            'Slider' => SliderConverter,
            'Segment' => SegmentConverter,
            'Radio' => RadioConverter,
            'Progress' => ProgressConverter,
            'Indicator' => IndicatorConverter,
            'SelectBox' => SelectBoxConverter,
            'Include' => IncludeConverter,
            'IconLabel' => IconLabelConverter,
            'GradientView' => GradientViewConverter,
            'Blur' => BlurConverter,
            'CircleView' => CircleViewConverter,
            'Web' => WebConverter
          }[type] || ViewConverter
        end

        def indent_str(indent)
          ' ' * indent
        end

        def convert_binding(value)
          return value unless value.is_a?(String)

          # Check if it's a snake_case string key for StringManager
          if string_key?(value)
            return convert_string_key(value)
          end

          # Check if it's a binding expression @{propName} or @{prop.name}
          if value.match?(/@\{[^}]+\}/)
            # Convert @{propName} or @{prop.name} to {propName} or {prop.name}
            converted = value.gsub(/@\{([^}]+)\}/, '{\1}')
            # Also escape any remaining literal braces (not part of binding expressions)
            return escape_jsx_braces_with_bindings(converted)
          end

          # Convert newlines to <br /> and escape JSX braces
          convert_text_with_newlines(value)
        end

        # Convert text with newline characters to JSX with <br /> tags
        def convert_text_with_newlines(value)
          return value unless value.is_a?(String)

          # If text contains newlines, convert to JSX fragment with <br /> tags
          if value.include?("\n")
            parts = value.split("\n")
            # Build JSX expression: <>line1<br />line2<br />line3</>
            jsx_parts = parts.map.with_index do |part, i|
              escaped_part = escape_text_for_jsx(part)
              i < parts.length - 1 ? "#{escaped_part}<br />" : escaped_part
            end
            return "<>#{jsx_parts.join('')}</>"
          end

          # Escape { and } in plain text for JSX (must be wrapped as JSX expressions)
          escape_jsx_braces(value)
        end

        # Escape special characters in text for JSX (without wrapping)
        def escape_text_for_jsx(text)
          return text unless text.is_a?(String)
          # Escape if text contains braces or single quotes
          return text unless text.include?('{') || text.include?('}') || text.include?("'")

          # Wrap text containing special characters in JSX expression
          escaped = text.gsub('`', '\\`').gsub('${', '\\${')
          "{`#{escaped}`}"
        end

        def escape_jsx_braces_with_bindings(value)
          # For text that has both JSX expressions {binding} and literal braces,
          # we need to handle them differently
          return value unless value.is_a?(String)

          # If the text contains literal { or } that aren't part of JSX expressions,
          # wrap in template literal
          # Check if text starts with { and is likely JSON (not a binding)
          if value.start_with?('{') && !value.match?(/^\{[a-zA-Z]/)
            # Likely JSON code block, wrap in template literal
            escaped = value.gsub('`', '\\`').gsub('${', '\\${')
            return "{`#{escaped}`}"
          end

          value
        end

        def escape_jsx_braces(value)
          return value unless value.is_a?(String)
          # Escape if text contains braces or single quotes (which can break JSX attributes)
          return value unless value.include?('{') || value.include?('}') || value.include?("'")

          # For text containing special characters, wrap entire string in JSX expression with template literal
          escaped = value.gsub('`', '\\`').gsub('${', '\\${')
          "{`#{escaped}`}"
        end

        def extract_id
          json['id'] || json['propertyName']
        end

        # Build onClick attribute - converts @{handler} to {handler}
        def build_onclick_attr
          handler = json['onClick']
          return '' unless handler

          if handler.start_with?('@{')
            # Binding: @{handleClick} -> {handleClick}
            " onClick={#{handler.gsub(/@\{|\}/, '')}}"
          else
            # Direct handler name
            " onClick={#{handler}}"
          end
        end

        # Build visibility binding for conditional rendering (gone) or opacity (invisible)
        # Returns: { type: :gone, condition: "..." } or { type: :invisible, condition: "...", invert: bool } or nil
        def build_visibility_info
          visibility = json['visibility']
          return nil unless visibility && has_binding?(visibility)

          binding_expr = visibility.gsub(/@\{|\}/, '')

          # Check for ternary patterns: condition ? 'value1' : 'value2'
          # Supports both 'visible' and '.visible' formats
          # Pattern: condition ? 'visible' : 'gone' or condition ? '.visible' : '.gone'
          if binding_expr =~ /^(.+?)\s*\?\s*'\.?visible'\s*:\s*'\.?gone'\s*$/
            { type: :gone, condition: $1.strip }
          # Pattern: condition ? 'gone' : 'visible'
          elsif binding_expr =~ /^(.+?)\s*\?\s*'\.?gone'\s*:\s*'\.?visible'\s*$/
            { type: :gone, condition: "!#{$1.strip}" }
          # Pattern: condition ? 'visible' : 'invisible'
          elsif binding_expr =~ /^(.+?)\s*\?\s*'\.?visible'\s*:\s*'\.?invisible'\s*$/
            { type: :invisible, condition: $1.strip, invert: true }
          # Pattern: condition ? 'invisible' : 'visible'
          elsif binding_expr =~ /^(.+?)\s*\?\s*'\.?invisible'\s*:\s*'\.?visible'\s*$/
            { type: :invisible, condition: $1.strip, invert: false }
          # Simple boolean variable like "viewModel.isVisible"
          elsif binding_expr =~ /^[\w.]+$/
            { type: :gone, condition: binding_expr }
          else
            nil
          end
        end

        # Wrap JSX with visibility condition (for 'gone' type - conditional render)
        def wrap_with_visibility(jsx, indent)
          vis_info = build_visibility_info
          return jsx unless vis_info

          case vis_info[:type]
          when :gone
            <<~JSX.chomp
              #{indent_str(indent)}{#{vis_info[:condition]} && (
              #{jsx}
              #{indent_str(indent)})}
            JSX
          when :invisible
            # For invisible, we add opacity style instead of conditional rendering
            # The opacity is handled in build_visibility_style
            jsx
          else
            jsx
          end
        end

        # Build style for invisible visibility (opacity: 0)
        def build_visibility_style
          vis_info = build_visibility_info
          return nil unless vis_info && vis_info[:type] == :invisible

          condition = vis_info[:condition]
          if vis_info[:invert]
            # condition ? 'visible' : 'invisible' -> opacity: condition ? 1 : 0
            "opacity: #{condition} ? 1 : 0"
          else
            # condition ? 'invisible' : 'visible' -> opacity: condition ? 0 : 1
            "opacity: #{condition} ? 0 : 1"
          end
        end

        # Get default value from config
        def defaults(component_type = nil)
          return {} unless config['defaults']

          if component_type
            config['defaults'][component_type] || {}
          else
            config['defaults']
          end
        end

        # Get value with fallback to default
        def get_value(key, component_type = nil)
          json[key] || defaults(component_type)[key]
        end
      end
    end
  end
end
