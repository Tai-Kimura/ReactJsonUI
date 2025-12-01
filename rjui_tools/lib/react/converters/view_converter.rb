# frozen_string_literal: true

require_relative 'base_converter'

module RjuiTools
  module React
    module Converters
      class ViewConverter < BaseConverter
        def convert(indent = 2)
          class_name = build_class_name
          style_attr = build_style_attr_with_visibility
          children = convert_children(indent)
          id_attr = extract_id ? " id=\"#{extract_id}\"" : ''
          event_attrs = build_event_attrs

          jsx = if children.empty?
            "#{indent_str(indent)}<div#{id_attr} className=\"#{class_name}\"#{style_attr}#{event_attrs} />"
          else
            <<~JSX.chomp
              #{indent_str(indent)}<div#{id_attr} className="#{class_name}"#{style_attr}#{event_attrs}>
              #{children}
              #{indent_str(indent)}</div>
            JSX
          end

          # Wrap with visibility condition (for 'gone' type)
          wrap_with_visibility(jsx, indent)
        end

        protected

        # Build style attribute including visibility (for 'invisible' type)
        def build_style_attr_with_visibility
          visibility_style = build_visibility_style

          if visibility_style
            @dynamic_styles ||= {}
            # Add visibility opacity to dynamic styles
            existing_style = build_style_attr
            if existing_style.empty?
              " style={{ #{visibility_style} }}"
            else
              # Merge with existing styles
              existing_style.sub(/\}\}$/, ", #{visibility_style} }}")
            end
          else
            build_style_attr
          end
        end

        def build_class_name
          classes = [super]

          # Default flex column for View with children
          if json['child'].is_a?(Array) && !json['orientation']
            classes.unshift('flex flex-col')
          end

          # Center alignment
          classes << 'items-center' if json['centerHorizontal']
          classes << 'justify-center' if json['centerVertical']
          classes << 'items-center justify-center' if json['centerInParent']

          # Gap/Spacing
          if json['spacing']
            spacing = TailwindMapper::PADDING_MAP[json['spacing']] || json['spacing']
            classes << "gap-#{spacing}"
          end

          # Cursor pointer for clickable items
          classes << 'cursor-pointer' if json['onClick'] || json['onclick']

          # Highlight/Tap background effects (using hover/active states)
          if json['tapBackground'] || json['highlightBackground']
            tap_bg = json['tapBackground'] || json['highlightBackground']
            classes << "active:#{TailwindMapper.map_color(tap_bg, 'bg')}" if tap_bg.is_a?(String)
          end

          # Highlighted state (initial highlight)
          if json['highlighted']
            highlight_bg = json['highlightBackground'] || '#E5E7EB'
            classes << TailwindMapper.map_color(highlight_bg, 'bg')
          end

          # Transition for smooth effects
          classes << 'transition-colors' if json['tapBackground'] || json['highlightBackground']

          classes.compact.reject(&:empty?).join(' ')
        end

        # Build all event handler attributes
        def build_event_attrs
          attrs = []

          # onClick
          attrs << build_onclick_attr

          # onLongPress (using onContextMenu as fallback, or custom implementation)
          if json['onLongPress']
            handler = json['onLongPress']
            if handler.start_with?('@{')
              attrs << " onContextMenu={(e) => { e.preventDefault(); #{handler.gsub(/@\{|\}/, '')}(e); }}"
            else
              attrs << " onContextMenu={(e) => { e.preventDefault(); #{handler}(e); }}"
            end
          end

          # onPan (using pointer events for drag)
          if json['onPan']
            handler = json['onPan']
            handler_name = handler.start_with?('@{') ? handler.gsub(/@\{|\}/, '') : handler
            attrs << " onPointerDown={(e) => #{handler_name}?.onStart?.(e)}"
            attrs << " onPointerMove={(e) => #{handler_name}?.onMove?.(e)}"
            attrs << " onPointerUp={(e) => #{handler_name}?.onEnd?.(e)}"
          end

          # onPinch (using touch events)
          if json['onPinch']
            handler = json['onPinch']
            handler_name = handler.start_with?('@{') ? handler.gsub(/@\{|\}/, '') : handler
            attrs << " onTouchStart={(e) => #{handler_name}?.onStart?.(e)}"
            attrs << " onTouchMove={(e) => #{handler_name}?.onMove?.(e)}"
            attrs << " onTouchEnd={(e) => #{handler_name}?.onEnd?.(e)}"
          end

          attrs.compact.join('')
        end
      end
    end
  end
end
