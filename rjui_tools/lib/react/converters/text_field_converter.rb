# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class TextFieldConverter < BaseConverter
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

          "#{indent_str(indent)}<input#{id_attr} className=\"#{class_name}\"#{style_attr}#{attrs}#{on_change}#{disabled_attr}#{testid_attr}#{tag_attr} />"
        end

        protected

        def apply_defaults
          # Apply textField defaults if not explicitly set
          text_field_defaults = defaults('textField')
          return if text_field_defaults.empty?

          @json = json.dup
          @json['fontColor'] ||= text_field_defaults['fontColor']
          @json['padding'] ||= text_field_defaults['padding']
          @json['background'] ||= text_field_defaults['background']
          @json['cornerRadius'] ||= text_field_defaults['cornerRadius']
        end

        def build_class_name
          classes = [super]

          # Default input styles
          classes << 'border'
          classes << 'outline-none'
          classes << 'focus:ring-2 focus:ring-blue-500'

          # Border style
          case json['borderStyle']&.downcase
          when 'roundedrect'
            classes << 'rounded-md'
          when 'line'
            classes << 'border-b border-t-0 border-l-0 border-r-0 rounded-none'
          when 'none'
            classes << 'border-0'
          end

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

          # Hint/placeholder color using CSS custom property
          if json['hintColor'] || json['placeholderColor']
            color = json['hintColor'] || json['placeholderColor']
            @dynamic_styles['--placeholder-color'] = "'#{color}'"
          end

          # Caret (cursor) color
          if json['caretAttributes'] && json['caretAttributes']['fontColor']
            @dynamic_styles['caretColor'] = "'#{json['caretAttributes']['fontColor']}'"
          end

          # Text padding left
          if json['textPaddingLeft']
            @dynamic_styles['paddingLeft'] = "'#{json['textPaddingLeft']}px'"
          end

          # Shadow
          if json['shadow']
            if json['shadow'].is_a?(Hash)
              radius = json['shadow']['radius'] || 5
              x = json['shadow']['offsetX'] || 0
              y = json['shadow']['offsetY'] || 0
              color = json['shadow']['color'] || 'rgba(0,0,0,0.2)'
              @dynamic_styles['boxShadow'] = "'#{x}px #{y}px #{radius}px #{color}'"
            else
              @dynamic_styles['boxShadow'] = "'0 2px 4px rgba(0,0,0,0.1)'"
            end
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

          # Type based on input attribute
          input_type = determine_input_type
          attrs << " type=\"#{input_type}\""

          # Name attribute
          attrs << " name=\"#{json['name']}\"" if json['name']

          # Placeholder (hint in SwiftJsonUI terminology)
          placeholder = json['hint'] || json['placeholder']
          attrs << " placeholder=\"#{placeholder}\"" if placeholder

          # Value binding
          if json['text']
            value = convert_binding(json['text'])
            if value.include?('{')
              attrs << " value={#{value.gsub(/[{}]/, '')}}"
            else
              attrs << " defaultValue=\"#{value}\""
            end
          end

          # Max length
          attrs << " maxLength={#{json['maxLength']}}" if json['maxLength']

          # Auto complete / content type
          if json['contentType']
            autocomplete = map_content_type(json['contentType'])
            attrs << " autoComplete=\"#{autocomplete}\"" if autocomplete
          end

          # Input mode (for mobile keyboards)
          if json['input']
            inputmode = map_input_mode(json['input'])
            attrs << " inputMode=\"#{inputmode}\"" if inputmode
          end

          # Return key type (for form submission)
          if json['returnKeyType']
            enter_key_hint = map_return_key(json['returnKeyType'])
            attrs << " enterKeyHint=\"#{enter_key_hint}\"" if enter_key_hint
          end

          # Auto focus
          attrs << ' autoFocus' if json['autoFocus'] || json['becomeFirstResponder']

          # Read only
          attrs << ' readOnly' if json['readOnly'] || json['editable'] == false

          attrs.join
        end

        def determine_input_type
          # Secure field takes precedence
          return 'password' if json['secure'] || json['input']&.downcase == 'password'

          case json['input']&.downcase
          when 'email'
            'email'
          when 'number', 'decimal', 'numberpad', 'decimalpad'
            'number'
          when 'tel', 'phonenumber', 'namephonepad'
            'tel'
          when 'url'
            'url'
          when 'search', 'websearch'
            'search'
          else
            'text'
          end
        end

        def map_content_type(type)
          case type&.downcase
          when 'username'
            'username'
          when 'password'
            'current-password'
          when 'newpassword'
            'new-password'
          when 'email'
            'email'
          when 'name'
            'name'
          when 'givenname'
            'given-name'
          when 'familyname'
            'family-name'
          when 'tel', 'telephonenumber'
            'tel'
          when 'streetaddress'
            'street-address'
          when 'postalcode'
            'postal-code'
          when 'country'
            'country'
          when 'creditcardnumber'
            'cc-number'
          else
            nil
          end
        end

        def map_input_mode(input)
          case input&.downcase
          when 'number', 'numberpad'
            'numeric'
          when 'decimal', 'decimalpad'
            'decimal'
          when 'tel', 'phonenumber'
            'tel'
          when 'email'
            'email'
          when 'url'
            'url'
          when 'search', 'websearch'
            'search'
          else
            nil
          end
        end

        def map_return_key(return_key)
          case return_key
          when 'Done'
            'done'
          when 'Go'
            'go'
          when 'Next'
            'next'
          when 'Search'
            'search'
          when 'Send'
            'send'
          when 'Enter', 'Return'
            'enter'
          else
            nil
          end
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
