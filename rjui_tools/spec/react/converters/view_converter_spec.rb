# frozen_string_literal: true

require_relative '../../spec_helper'
require 'react/converters/view_converter'

RSpec.describe RjuiTools::React::Converters::ViewConverter do
  let(:default_config) { { 'use_tailwind' => true } }

  def create_converter(json_data, config = nil)
    described_class.new(json_data, config || default_config)
  end

  describe '#build_class_name' do
    context 'with spacing' do
      it 'adds gap class for spacing (16px -> gap-4)' do
        converter = create_converter({
          'type' => 'View',
          'orientation' => 'horizontal',
          'spacing' => 16,
          'child' => [
            { 'type' => 'Label', 'text' => 'A' }
          ]
        })
        classes = converter.send(:build_class_name)
        # 16px maps to Tailwind gap-4
        expect(classes).to include('gap-4')
      end

      it 'maps spacing to Tailwind gap values (8px -> gap-2)' do
        converter = create_converter({
          'type' => 'View',
          'orientation' => 'vertical',
          'spacing' => 8,
          'child' => []
        })
        classes = converter.send(:build_class_name)
        # 8px maps to Tailwind gap-2
        expect(classes).to include('gap-2')
      end
    end

    context 'with distribution' do
      it 'adds justify-between for fill distribution' do
        converter = create_converter({
          'type' => 'View',
          'orientation' => 'horizontal',
          'distribution' => 'fill',
          'child' => []
        })
        classes = converter.send(:build_class_name)
        expect(classes).to include('justify-between')
      end

      it 'adds justify-evenly for fillEqually distribution' do
        converter = create_converter({
          'type' => 'View',
          'orientation' => 'horizontal',
          'distribution' => 'fillEqually',
          'child' => []
        })
        classes = converter.send(:build_class_name)
        expect(classes).to include('justify-evenly')
      end

      it 'adds justify-around for equalSpacing distribution' do
        converter = create_converter({
          'type' => 'View',
          'orientation' => 'vertical',
          'distribution' => 'equalSpacing',
          'child' => []
        })
        classes = converter.send(:build_class_name)
        expect(classes).to include('justify-around')
      end

      it 'adds justify-evenly for equalCentering distribution' do
        converter = create_converter({
          'type' => 'View',
          'orientation' => 'horizontal',
          'distribution' => 'equalCentering',
          'child' => []
        })
        classes = converter.send(:build_class_name)
        expect(classes).to include('justify-evenly')
      end
    end

    context 'with spacing and distribution combined' do
      it 'applies both spacing and distribution classes' do
        converter = create_converter({
          'type' => 'View',
          'orientation' => 'horizontal',
          'spacing' => 12,
          'distribution' => 'equalSpacing',
          'child' => []
        })
        classes = converter.send(:build_class_name)
        # 12px maps to Tailwind gap-3
        expect(classes).to include('gap-3')
        expect(classes).to include('justify-around')
      end
    end
  end
end
