# frozen_string_literal: true

require 'core/type_converter'

RSpec.describe RjuiTools::Core::TypeConverter do
  describe '.to_typescript_type' do
    context 'with string types' do
      it 'converts String types to string' do
        expect(described_class.to_typescript_type('String')).to eq('string')
        expect(described_class.to_typescript_type('string')).to eq('string')
      end
    end

    context 'with number types' do
      it 'converts Int types to number' do
        expect(described_class.to_typescript_type('Int')).to eq('number')
        expect(described_class.to_typescript_type('int')).to eq('number')
        expect(described_class.to_typescript_type('Integer')).to eq('number')
        expect(described_class.to_typescript_type('integer')).to eq('number')
      end

      it 'converts Double types to number' do
        expect(described_class.to_typescript_type('Double')).to eq('number')
        expect(described_class.to_typescript_type('double')).to eq('number')
      end

      it 'converts Float types to number' do
        expect(described_class.to_typescript_type('Float')).to eq('number')
        expect(described_class.to_typescript_type('float')).to eq('number')
      end

      it 'converts Number types to number' do
        expect(described_class.to_typescript_type('Number')).to eq('number')
        expect(described_class.to_typescript_type('number')).to eq('number')
      end

      it 'converts CGFloat to number' do
        expect(described_class.to_typescript_type('CGFloat')).to eq('number')
      end
    end

    context 'with boolean types' do
      it 'converts Bool types to boolean' do
        expect(described_class.to_typescript_type('Bool')).to eq('boolean')
        expect(described_class.to_typescript_type('bool')).to eq('boolean')
        expect(described_class.to_typescript_type('Boolean')).to eq('boolean')
        expect(described_class.to_typescript_type('boolean')).to eq('boolean')
      end
    end

    context 'with array types' do
      it 'converts Array types to any[]' do
        expect(described_class.to_typescript_type('Array')).to eq('any[]')
        expect(described_class.to_typescript_type('array')).to eq('any[]')
      end
    end

    context 'with object types' do
      it 'converts Object types to Record<string, any>' do
        expect(described_class.to_typescript_type('Object')).to eq('Record<string, any>')
        expect(described_class.to_typescript_type('object')).to eq('Record<string, any>')
        expect(described_class.to_typescript_type('Hash')).to eq('Record<string, any>')
        expect(described_class.to_typescript_type('hash')).to eq('Record<string, any>')
      end
    end

    context 'with unknown types' do
      it 'returns the type as-is' do
        expect(described_class.to_typescript_type('CollectionDataSource')).to eq('CollectionDataSource')
        expect(described_class.to_typescript_type('CustomType')).to eq('CustomType')
        expect(described_class.to_typescript_type('MyInterface')).to eq('MyInterface')
      end
    end

    context 'with nil or empty types' do
      it 'returns any for nil input' do
        expect(described_class.to_typescript_type(nil)).to eq('any')
      end

      it 'returns any for empty input' do
        expect(described_class.to_typescript_type('')).to eq('any')
      end
    end
  end

  describe '.extract_platform_value' do
    context 'with simple value' do
      it 'returns the value as-is' do
        expect(described_class.extract_platform_value('string')).to eq('string')
        expect(described_class.extract_platform_value(123)).to eq(123)
      end
    end

    context 'with language-only hash' do
      it 'extracts react value' do
        value = { 'swift' => 'Int', 'kotlin' => 'Int', 'react' => 'number' }
        expect(described_class.extract_platform_value(value)).to eq('number')
      end

      it 'returns original hash if no react key' do
        value = { 'swift' => 'Int', 'kotlin' => 'Int' }
        expect(described_class.extract_platform_value(value)).to eq(value)
      end
    end

    context 'with language + mode hash' do
      let(:value) do
        {
          'swift' => { 'swiftui' => 'Color', 'uikit' => 'UIColor' },
          'kotlin' => { 'compose' => 'Color', 'xml' => 'Int' },
          'react' => { 'react' => 'string' }
        }
      end

      it 'extracts react value when mode is react' do
        expect(described_class.extract_platform_value(value, 'react')).to eq('string')
      end

      it 'falls back to first available mode if specified mode not found' do
        value_missing_mode = {
          'react' => { 'react' => 'string' }
        }
        expect(described_class.extract_platform_value(value_missing_mode, 'other')).to eq('string')
      end
    end
  end

  describe '.normalize_data_property' do
    context 'with simple class' do
      it 'normalizes String class to string' do
        prop = { 'name' => 'title', 'class' => 'String', 'defaultValue' => 'Hello' }
        result = described_class.normalize_data_property(prop, 'react')

        expect(result['name']).to eq('title')
        expect(result['tsType']).to eq('string')
        expect(result['defaultValue']).to eq('Hello')
      end

      it 'converts Bool to boolean' do
        prop = { 'name' => 'isEnabled', 'class' => 'Bool', 'defaultValue' => true }
        result = described_class.normalize_data_property(prop, 'react')

        expect(result['tsType']).to eq('boolean')
      end
    end

    context 'with platform-specific hash values' do
      it 'extracts class and defaultValue for react' do
        prop = {
          'name' => 'backgroundColor',
          'class' => {
            'swift' => { 'swiftui' => 'Color', 'uikit' => 'UIColor' },
            'kotlin' => { 'compose' => 'Color', 'xml' => 'Int' },
            'react' => { 'react' => 'string' }
          },
          'defaultValue' => {
            'swift' => { 'swiftui' => 'Color.blue', 'uikit' => 'UIColor.blue' },
            'kotlin' => { 'compose' => 'Color.Blue', 'xml' => '0xFF0000FF' },
            'react' => { 'react' => '"#0000FF"' }
          }
        }

        result = described_class.normalize_data_property(prop, 'react')
        expect(result['tsType']).to eq('string')
        expect(result['defaultValue']).to eq('"#0000FF"')
      end
    end

    context 'with unknown types' do
      it 'preserves unknown types as-is' do
        prop = { 'name' => 'dataSource', 'class' => 'CollectionDataSource' }
        result = described_class.normalize_data_property(prop, 'react')

        expect(result['tsType']).to eq('CollectionDataSource')
      end
    end
  end

  describe '.normalize_data_properties' do
    it 'normalizes array of properties' do
      props = [
        { 'name' => 'title', 'class' => 'String' },
        { 'name' => 'count', 'class' => 'Int' },
        { 'name' => 'isActive', 'class' => 'Bool' }
      ]

      result = described_class.normalize_data_properties(props, 'react')

      expect(result[0]['tsType']).to eq('string')
      expect(result[1]['tsType']).to eq('number')
      expect(result[2]['tsType']).to eq('boolean')
    end

    it 'returns empty array for nil input' do
      expect(described_class.normalize_data_properties(nil)).to eq([])
    end

    it 'returns empty array for non-array input' do
      expect(described_class.normalize_data_properties('not an array')).to eq([])
    end
  end

  describe '.primitive?' do
    it 'returns true for primitive types' do
      expect(described_class.primitive?('String')).to be true
      expect(described_class.primitive?('Int')).to be true
      expect(described_class.primitive?('Bool')).to be true
      expect(described_class.primitive?('Double')).to be true
    end

    it 'returns false for non-primitive types' do
      expect(described_class.primitive?('CollectionDataSource')).to be false
      expect(described_class.primitive?('CustomType')).to be false
    end

    it 'returns false for nil or empty' do
      expect(described_class.primitive?(nil)).to be false
      expect(described_class.primitive?('')).to be false
    end
  end

  describe '.default_value' do
    it 'returns correct defaults for TypeScript types' do
      expect(described_class.default_value('string')).to eq('""')
      expect(described_class.default_value('number')).to eq('0')
      expect(described_class.default_value('boolean')).to eq('false')
      expect(described_class.default_value('any[]')).to eq('[]')
      expect(described_class.default_value('Record<string, any>')).to eq('{}')
    end

    it 'returns undefined for unknown types' do
      expect(described_class.default_value('CustomType')).to eq('undefined')
    end
  end

  describe '.format_value' do
    it 'formats string values with quotes' do
      expect(described_class.format_value('hello', 'string')).to eq('"hello"')
    end

    it 'formats number values' do
      expect(described_class.format_value(42, 'number')).to eq('42.0')
      expect(described_class.format_value(3.14, 'number')).to eq('3.14')
    end

    it 'formats boolean values' do
      expect(described_class.format_value(true, 'boolean')).to eq('true')
      expect(described_class.format_value(false, 'boolean')).to eq('false')
    end

    it 'formats array values' do
      expect(described_class.format_value([1, 2, 3], 'any[]')).to eq('[1,2,3]')
      expect(described_class.format_value([], 'any[]')).to eq('[]')
    end

    it 'formats object values' do
      expect(described_class.format_value({ 'a' => 1 }, 'Record<string, any>')).to eq('{"a":1}')
      expect(described_class.format_value({}, 'Record<string, any>')).to eq('{}')
    end

    it 'returns undefined for nil' do
      expect(described_class.format_value(nil, 'string')).to eq('undefined')
    end
  end
end
