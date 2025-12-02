# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class WebConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          style_attr = build_style_attr
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''

          # Build iframe attributes
          src = build_src_attr
          sandbox_attr = build_sandbox_attr
          allow_attr = build_allow_attr

          "#{indent_str(indent)}<iframe#{id_attr} className=\"#{class_name}\"#{src}#{sandbox_attr}#{allow_attr}#{style_attr} />"
        end

        protected

        def build_class_name
          classes = [super]

          # Default border none for iframe
          classes << 'border-0'

          classes.compact.reject(&:empty?).join(' ')
        end

        def build_src_attr
          url = json['url']
          html = json['html']

          if url
            if has_binding?(url)
              converted = url.gsub(/@\{([^}]+)\}/, '{\1}')
              " src={#{converted.gsub(/[{}]/, '')}}"
            else
              " src=\"#{url}\""
            end
          elsif html
            # For HTML content, use srcdoc
            if has_binding?(html)
              converted = html.gsub(/@\{([^}]+)\}/, '{\1}')
              " srcDoc={#{converted.gsub(/[{}]/, '')}}"
            else
              escaped_html = html.gsub('"', '&quot;')
              " srcDoc=\"#{escaped_html}\""
            end
          else
            ''
          end
        end

        def build_sandbox_attr
          # Build sandbox permissions based on JSON config
          permissions = []

          # JavaScript enabled
          permissions << 'allow-scripts' if json['javaScriptEnabled'] != false

          # Allow same origin for most functionality
          permissions << 'allow-same-origin'

          # Allow popups if JavaScript can open windows
          permissions << 'allow-popups' if json['javaScriptCanOpenWindowsAutomatically']

          # Allow forms
          permissions << 'allow-forms'

          return '' if permissions.empty?

          " sandbox=\"#{permissions.join(' ')}\""
        end

        def build_allow_attr
          allows = []

          # Inline media playback
          allows << 'autoplay' if json['allowsInlineMediaPlayback']

          # Fullscreen
          allows << 'fullscreen'

          return '' if allows.empty?

          " allow=\"#{allows.join('; ')}\""
        end
      end
    end
  end
end
