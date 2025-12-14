# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class SelectBoxConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          style_attr = build_style_attr
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''
          testid_attr = build_testid_attr
          tag_attr = build_tag_attr
          items = json['items'] || []

          value_attr = build_value_attr
          on_change = build_on_change
          disabled_attr = build_disabled_attr

          jsx = if items.is_a?(String) && has_binding?(items)
            generate_dynamic_select(indent, id_attr, class_name, style_attr, testid_attr, tag_attr, value_attr, on_change, disabled_attr, items)
          else
            generate_static_select(indent, id_attr, class_name, style_attr, testid_attr, tag_attr, value_attr, on_change, disabled_attr, items)
          end

          wrap_with_visibility(jsx, indent)
        end

        protected

        def build_class_name
          classes = [super]

          # Default select styling
          classes << 'border'
          classes << 'rounded-md'
          classes << 'px-3 py-2'
          classes << 'bg-white'
          classes << 'cursor-pointer'
          classes << 'outline-none'
          classes << 'focus:ring-2 focus:ring-blue-500 focus:border-blue-500'

          # Border color
          border_color = json['borderColor']
          classes << TailwindMapper.map_color(border_color, 'border') if border_color

          # Font color
          font_color = json['fontColor']
          classes << TailwindMapper.map_color(font_color, 'text') if font_color

          # Font size
          font_size = json['fontSize']
          classes << TailwindMapper.map_font_size(font_size) if font_size

          # Disabled state
          if json['enabled'] == false
            classes << 'opacity-50 cursor-not-allowed'
          elsif has_binding?(json['enabled'])
            binding_expr = extract_binding_property(json['enabled'])
            classes << "${!#{binding_expr} ? 'opacity-50 cursor-not-allowed' : ''}"
          end

          classes.compact.reject(&:empty?).join(' ')
        end

        private

        def generate_dynamic_select(indent, id_attr, class_name, style_attr, testid_attr, tag_attr, value_attr, on_change, disabled_attr, items)
          items_prop = extract_binding_property(items)
          hint = json['hint'] || json['placeholder']
          hint_option = hint ? "\n#{indent_str(indent + 2)}<option value=\"\" disabled>#{hint}</option>" : ''

          <<~JSX.chomp
            #{indent_str(indent)}<select#{id_attr} className="#{class_name}"#{value_attr}#{on_change}#{disabled_attr}#{style_attr}#{testid_attr}#{tag_attr}>#{hint_option}
            #{indent_str(indent + 2)}{#{items_prop}?.map((item) => (
            #{indent_str(indent + 4)}<option key={item.value || item.id} value={item.value || item.id}>{item.text || item.label}</option>
            #{indent_str(indent + 2)}))}
            #{indent_str(indent)}</select>
          JSX
        end

        def generate_static_select(indent, id_attr, class_name, style_attr, testid_attr, tag_attr, value_attr, on_change, disabled_attr, items)
          options_jsx = items.map do |item|
            if item.is_a?(Hash)
              value = item['value'] || item['id'] || item['text']
              label = item['text'] || item['label'] || value
              "#{indent_str(indent + 2)}<option value=\"#{value}\">#{label}</option>"
            else
              "#{indent_str(indent + 2)}<option value=\"#{item}\">#{item}</option>"
            end
          end.join("\n")

          hint = json['hint'] || json['placeholder']
          if hint
            options_jsx = "#{indent_str(indent + 2)}<option value=\"\" disabled>#{hint}</option>\n#{options_jsx}"
          end

          <<~JSX.chomp
            #{indent_str(indent)}<select#{id_attr} className="#{class_name}"#{value_attr}#{on_change}#{disabled_attr}#{style_attr}#{testid_attr}#{tag_attr}>
            #{options_jsx}
            #{indent_str(indent)}</select>
          JSX
        end

        def build_value_attr
          value = json['selectedValue'] || json['value']

          if value && has_binding?(value)
            prop = extract_binding_property(value)
            " value={#{prop}}"
          elsif value
            " defaultValue=\"#{value}\""
          else
            ''
          end
        end

        def build_on_change
          handler = json['onValueChanged'] || json['onChange']
          return '' unless handler

          if has_binding?(handler)
            prop = extract_binding_property(handler)
            " onChange={(e) => #{prop}(e.target.value)}"
          else
            " onChange={(e) => #{handler}(e.target.value)}"
          end
        end

        def build_disabled_attr
          enabled = json['enabled']
          return '' if enabled.nil?

          if has_binding?(enabled)
            " disabled={!#{extract_binding_property(enabled)}}"
          elsif enabled == false
            ' disabled'
          else
            ''
          end
        end
      end
    end
  end
end
