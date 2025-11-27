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

          attrs = build_attributes
          on_change = build_on_change

          "#{indent_str(indent)}<textarea#{id_attr} className=\"#{class_name}\"#{style_attr}#{attrs}#{on_change} />"
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
          classes << 'rounded-md'
          classes << 'outline-none'
          classes << 'focus:ring-2 focus:ring-blue-500'
          classes << 'resize-none' unless json['resize']

          # Scrollable
          classes << 'overflow-auto' if json['scrollEnabled'] != false

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_attributes
          attrs = []

          # Placeholder
          attrs << " placeholder=\"#{json['hint']}\"" if json['hint']

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

          # Editable
          if json['editable'] == false
            attrs << ' readOnly'
          end

          # Disabled
          if json['enabled'] == false
            attrs << ' disabled'
          end

          # Max length
          if json['maxLength']
            attrs << " maxLength={#{json['maxLength']}}"
          end

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
      end
    end
  end
end
