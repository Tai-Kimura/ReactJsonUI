# frozen_string_literal: true

module RjuiTools
  module React
    class TailwindMapper
      # Padding mapping (px to Tailwind)
      PADDING_MAP = {
        0 => '0', 1 => 'px', 2 => '0.5', 4 => '1', 6 => '1.5',
        8 => '2', 10 => '2.5', 12 => '3', 14 => '3.5', 16 => '4',
        20 => '5', 24 => '6', 28 => '7', 32 => '8', 36 => '9',
        40 => '10', 44 => '11', 48 => '12', 56 => '14', 64 => '16'
      }.freeze

      # Font size mapping
      FONT_SIZE_MAP = {
        12 => 'text-xs', 14 => 'text-sm', 16 => 'text-base',
        18 => 'text-lg', 20 => 'text-xl', 24 => 'text-2xl',
        30 => 'text-3xl', 36 => 'text-4xl', 48 => 'text-5xl',
        60 => 'text-6xl'
      }.freeze

      # Corner radius mapping
      RADIUS_MAP = {
        0 => 'rounded-none', 2 => 'rounded-sm', 4 => 'rounded',
        6 => 'rounded-md', 8 => 'rounded-lg', 12 => 'rounded-xl',
        16 => 'rounded-2xl', 24 => 'rounded-3xl'
      }.freeze

      # Shadow mapping
      SHADOW_MAP = {
        'sm' => 'shadow-sm',
        'md' => 'shadow-md',
        'lg' => 'shadow-lg',
        'xl' => 'shadow-xl',
        '2xl' => 'shadow-2xl'
      }.freeze

      # Opacity mapping
      OPACITY_MAP = {
        0 => 'opacity-0',
        0.1 => 'opacity-10',
        0.2 => 'opacity-20',
        0.25 => 'opacity-25',
        0.3 => 'opacity-30',
        0.4 => 'opacity-40',
        0.5 => 'opacity-50',
        0.6 => 'opacity-60',
        0.7 => 'opacity-70',
        0.75 => 'opacity-75',
        0.8 => 'opacity-80',
        0.9 => 'opacity-90',
        1 => 'opacity-100'
      }.freeze

      # Font weight mapping
      FONT_WEIGHT_MAP = {
        'thin' => 'font-thin',
        'extralight' => 'font-extralight',
        'light' => 'font-light',
        'normal' => 'font-normal',
        'medium' => 'font-medium',
        'semibold' => 'font-semibold',
        'bold' => 'font-bold',
        'extrabold' => 'font-extrabold',
        'black' => 'font-black'
      }.freeze

      class << self
        def map_padding(padding)
          case padding
          when Numeric
            "p-#{closest_padding(padding)}"
          when Array
            map_padding_array(padding)
          else
            ''
          end
        end

        def map_padding_array(arr)
          case arr.length
          when 1
            "p-#{closest_padding(arr[0])}"
          when 2
            "py-#{closest_padding(arr[0])} px-#{closest_padding(arr[1])}"
          when 4
            classes = []
            classes << "pt-#{closest_padding(arr[0])}"
            classes << "pr-#{closest_padding(arr[1])}"
            classes << "pb-#{closest_padding(arr[2])}"
            classes << "pl-#{closest_padding(arr[3])}"
            classes.join(' ')
          else
            ''
          end
        end

        def map_margin(margin)
          case margin
          when Numeric
            "m-#{closest_padding(margin)}"
          when Array
            map_margin_array(margin)
          else
            ''
          end
        end

        def map_margin_array(arr)
          case arr.length
          when 1
            "m-#{closest_padding(arr[0])}"
          when 2
            "my-#{closest_padding(arr[0])} mx-#{closest_padding(arr[1])}"
          when 4
            classes = []
            classes << "mt-#{closest_padding(arr[0])}"
            classes << "mr-#{closest_padding(arr[1])}"
            classes << "mb-#{closest_padding(arr[2])}"
            classes << "ml-#{closest_padding(arr[3])}"
            classes.join(' ')
          else
            ''
          end
        end

        def map_font_size(size)
          FONT_SIZE_MAP[size] || "text-[#{size}px]"
        end

        def map_corner_radius(radius)
          RADIUS_MAP[radius] || "rounded-[#{radius}px]"
        end

        def map_color(color, prefix = 'bg')
          return '' unless color

          if color.start_with?('#')
            "#{prefix}-[#{color}]"
          else
            "#{prefix}-#{color}"
          end
        end

        def map_width(width)
          case width
          when 'matchParent'
            'w-full'
          when 'wrapContent'
            'w-auto'
          when Numeric
            "w-[#{width}px]"
          else
            ''
          end
        end

        def map_height(height)
          case height
          when 'matchParent'
            'h-full'
          when 'wrapContent'
            'h-auto'
          when Numeric
            "h-[#{height}px]"
          else
            ''
          end
        end

        def map_text_align(align)
          case align&.downcase
          when 'center'
            'text-center'
          when 'right'
            'text-right'
          when 'left'
            'text-left'
          else
            ''
          end
        end

        def map_orientation(orientation)
          case orientation&.downcase
          when 'horizontal'
            'flex flex-row'
          when 'vertical'
            'flex flex-col'
          else
            ''
          end
        end

        def map_shadow(shadow)
          return '' unless shadow

          if shadow.is_a?(Hash)
            # Custom shadow: { radius: 5, offsetX: 0, offsetY: 2, color: "#000" }
            radius = shadow['radius'] || 5
            offset_x = shadow['offsetX'] || 0
            offset_y = shadow['offsetY'] || 2
            color = shadow['color'] || 'rgba(0,0,0,0.1)'
            "[box-shadow:#{offset_x}px_#{offset_y}px_#{radius}px_#{color}]"
          elsif shadow.is_a?(String)
            SHADOW_MAP[shadow] || 'shadow'
          elsif shadow == true
            'shadow'
          else
            ''
          end
        end

        def map_opacity(opacity)
          return '' unless opacity

          closest = OPACITY_MAP.keys.min_by { |k| (k - opacity.to_f).abs }
          OPACITY_MAP[closest]
        end

        def map_border(border_width, border_color, corner_radius = 0)
          classes = []

          if border_width
            classes << case border_width
                       when 0 then 'border-0'
                       when 1 then 'border'
                       when 2 then 'border-2'
                       when 4 then 'border-4'
                       when 8 then 'border-8'
                       else "border-[#{border_width}px]"
                       end
          end

          classes << map_color(border_color, 'border') if border_color
          classes.compact.reject(&:empty?).join(' ')
        end

        def map_font_weight(weight)
          return '' unless weight

          FONT_WEIGHT_MAP[weight.to_s.downcase] || ''
        end

        def map_gap(spacing)
          return '' unless spacing

          "gap-#{closest_padding(spacing)}"
        end

        def map_gravity(gravity)
          return [] unless gravity

          classes = []
          gravity_str = gravity.is_a?(Array) ? gravity.join('|') : gravity.to_s

          # Horizontal alignment
          if gravity_str.include?('center') || gravity_str.include?('centerHorizontal')
            classes << 'items-center'
          elsif gravity_str.include?('right')
            classes << 'items-end'
          elsif gravity_str.include?('left')
            classes << 'items-start'
          end

          # Vertical alignment
          if gravity_str.include?('center') || gravity_str.include?('centerVertical')
            classes << 'justify-center'
          elsif gravity_str.include?('bottom')
            classes << 'justify-end'
          elsif gravity_str.include?('top')
            classes << 'justify-start'
          end

          classes
        end

        def map_visibility(hidden)
          hidden ? 'hidden' : ''
        end

        def map_overflow(clip_to_bounds)
          clip_to_bounds ? 'overflow-hidden' : ''
        end

        def map_z_index(z_index)
          return '' unless z_index

          case z_index
          when 0 then 'z-0'
          when 10 then 'z-10'
          when 20 then 'z-20'
          when 30 then 'z-30'
          when 40 then 'z-40'
          when 50 then 'z-50'
          else "z-[#{z_index}]"
          end
        end

        def map_flex_grow(weight)
          return '' unless weight

          weight > 0 ? "grow-[#{weight}]" : 'grow-0'
        end

        private

        def closest_padding(value)
          return '0' unless value

          closest = PADDING_MAP.keys.min_by { |k| (k - value).abs }
          PADDING_MAP[closest]
        end
      end
    end
  end
end
