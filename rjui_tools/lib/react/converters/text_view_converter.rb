# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class TextViewConverter < BaseConverter
        def convert(indent = 2)
          apply_defaults
          class_name = build_class_name
          style_attr = build_style_attr
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''
          testid_attr = build_testid_attr
          tag_attr = build_tag_attr

          attrs = build_attributes
          on_change = build_on_change
          disabled_attr = build_disabled_attr

          "#{indent_str(indent)}<textarea#{id_attr} className=\"#{class_name}\"#{style_attr}#{attrs}#{on_change}#{disabled_attr}#{testid_attr}#{tag_attr}></textarea>"
        end

        protected

        def apply_defaults
          # Apply textView defaults if not explicitly set
          text_view_defaults = defaults('textView')
          return if text_view_defaults.empty?

          @json = json.dup
          @json['fontColor'] ||= text_view_defaults['fontColor']
          @json['padding'] ||= text_view_defaults['padding']
          @json['background'] ||= text_view_defaults['background']
          @json['cornerRadius'] ||= text_view_defaults['cornerRadius']
        end

        def build_class_name
          classes = [super]

          # Default textarea styles
          classes << 'border'
          classes << 'outline-none'
          classes << 'focus:ring-2 focus:ring-blue-500'
          classes << 'resize-none' unless json['resize']

          # Scrollable
          classes << 'overflow-auto' if json['scrollEnabled'] != false

          # Flexible height
          classes << 'resize-y' if json['flexible']

          # Disabled state
          classes << 'disabled:bg-gray-100 disabled:cursor-not-allowed' if json['enabled'] == false || json['enabled'].is_a?(String)

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_style_attr
          super

          # Corner radius
          if json['cornerRadius']
            @dynamic_styles['borderRadius'] = "'#{json['cornerRadius']}px'"
          end

          # Hint/placeholder color
          if json['hintColor'] || json['placeholderColor']
            color = json['hintColor'] || json['placeholderColor']
            @dynamic_styles['--placeholder-color'] = "'#{color}'"
          end

          # Hint attributes (color)
          if json['hintAttributes'] && json['hintAttributes']['fontColor']
            @dynamic_styles['--placeholder-color'] = "'#{json['hintAttributes']['fontColor']}'"
          end

          # Container inset (internal padding)
          if json['containerInset']
            inset = json['containerInset']
            if inset.is_a?(Array)
              case inset.length
              when 1
                @dynamic_styles['padding'] = "'#{inset[0]}px'"
              when 2
                @dynamic_styles['padding'] = "'#{inset[0]}px #{inset[1]}px'"
              when 4
                @dynamic_styles['padding'] = "'#{inset[0]}px #{inset[1]}px #{inset[2]}px #{inset[3]}px'"
              end
            else
              @dynamic_styles['padding'] = "'#{inset}px'"
            end
          end

          # Min/max height for flexible textareas
          if json['minHeight']
            @dynamic_styles['minHeight'] = "'#{json['minHeight']}px'"
          end

          if json['maxHeight']
            @dynamic_styles['maxHeight'] = "'#{json['maxHeight']}px'"
          end

          # Border
          if json['borderWidth'] && json['borderColor']
            @dynamic_styles['borderWidth'] = "'#{json['borderWidth']}px'"
            @dynamic_styles['borderColor'] = "'#{json['borderColor']}'"
            @dynamic_styles['borderStyle'] = "'solid'"
          end

          return '' if @dynamic_styles.nil? || @dynamic_styles.empty?

          style_pairs = @dynamic_styles.map do |key, value|
            clean_value = value.gsub(/^\{|\}$/, '')
            "#{key}: #{clean_value}"
          end

          " style={{ #{style_pairs.join(', ')} }}"
        end

        def build_attributes
          attrs = []

          # Placeholder (hint)
          placeholder = json['hint'] || json['placeholder']
          attrs << " placeholder=\"#{placeholder}\"" if placeholder

          # Name attribute
          attrs << " name=\"#{json['name']}\"" if json['name']

          # Value binding
          if json['text']
            value = convert_binding(json['text'])
            if value.include?('{')
              attrs << " value={#{value.gsub(/[{}]/, '')}}"
            else
              attrs << " defaultValue=\"#{value}\""
            end
          end

          # Rows
          if json['lines'] || json['rows']
            rows = json['lines'] || json['rows']
            attrs << " rows={#{rows}}"
          end

          # Max length
          attrs << " maxLength={#{json['maxLength']}}" if json['maxLength']

          # Read only
          attrs << ' readOnly' if json['readOnly'] || json['editable'] == false

          # Auto focus
          attrs << ' autoFocus' if json['autoFocus'] || json['becomeFirstResponder']

          attrs.join
        end

        def build_on_change
          handler = json['onTextChange'] || json['onChange']
          return '' unless handler

          if handler.start_with?('@{')
            " onChange={#{handler.gsub(/@\{|\}/, '')}}"
          else
            " onChange={#{handler}}"
          end
        end

        def build_disabled_attr
          enabled = json['enabled']
          return '' if enabled.nil?

          if enabled.is_a?(String) && enabled.start_with?('@{') && enabled.end_with?('}')
            property_name = enabled[2...-1]
            " disabled={!#{property_name}}"
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
