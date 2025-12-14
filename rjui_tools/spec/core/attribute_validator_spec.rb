#!/usr/bin/env ruby

require_relative '../../lib/core/attribute_validator'
require 'json'

RSpec.describe RjuiTools::Core::AttributeValidator do
  let(:validator) { described_class.new(:all) }

  describe '#validate' do
    context 'with enum array values' do
      it 'accepts valid single enum value in array' do
        component = {
          'type' => 'View',
          'gravity' => ['centerVertical']
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'accepts valid multiple enum values in array' do
        component = {
          'type' => 'View',
          'gravity' => ['centerVertical', 'left']
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'rejects invalid enum values in array' do
        component = {
          'type' => 'View',
          'gravity' => ['invalid']
        }
        warnings = validator.validate(component)
        expect(warnings).not_to be_empty
        expect(warnings.first).to include('invalid value')
        expect(warnings.first).to include('invalid')
      end

      it 'rejects mixed valid and invalid enum values in array' do
        component = {
          'type' => 'View',
          'gravity' => ['centerVertical', 'invalid']
        }
        warnings = validator.validate(component)
        expect(warnings).not_to be_empty
        expect(warnings.first).to include('invalid value')
        expect(warnings.first).to include('invalid')
      end
    end

    context 'with binding expressions' do
      it 'accepts binding expression for visibility' do
        component = {
          'type' => 'View',
          'visibility' => '@{isVisible}'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'accepts binding expression for enum attribute' do
        component = {
          'type' => 'View',
          'gravity' => '@{gravityValue}'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'accepts binding expression for width' do
        component = {
          'type' => 'View',
          'width' => '@{dynamicWidth}'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'accepts binding expression for height' do
        component = {
          'type' => 'View',
          'height' => '@{dynamicHeight}'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end
    end

    context 'with Hash enum type definitions' do
      it 'accepts valid enum string value for width' do
        component = {
          'type' => 'View',
          'width' => 'matchParent'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'accepts valid enum string value for height' do
        component = {
          'type' => 'View',
          'height' => 'wrapContent'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'accepts numeric value for width' do
        component = {
          'type' => 'View',
          'width' => 100
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'accepts numeric value for height' do
        component = {
          'type' => 'View',
          'height' => 200
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'rejects invalid string value for width' do
        component = {
          'type' => 'View',
          'width' => 'invalid'
        }
        warnings = validator.validate(component)
        expect(warnings).not_to be_empty
        expect(warnings.first).to match(/expects.*got string/)
      end

      it 'rejects invalid string value for height' do
        component = {
          'type' => 'View',
          'height' => 'invalid'
        }
        warnings = validator.validate(component)
        expect(warnings).not_to be_empty
        expect(warnings.first).to match(/expects.*got string/)
      end
    end

    context 'with enum string values' do
      it 'accepts valid enum string value' do
        component = {
          'type' => 'View',
          'visibility' => 'visible'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'accepts valid textAlign value' do
        component = {
          'type' => 'Label',
          'text' => 'Test',
          'textAlign' => 'center'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end
    end

    context 'with type validation' do
      it 'accepts valid number type' do
        component = {
          'type' => 'View',
          'cornerRadius' => 10
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'accepts valid string type' do
        component = {
          'type' => 'Label',
          'text' => 'Hello World'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'accepts valid boolean type' do
        component = {
          'type' => 'View',
          'hidden' => false
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'accepts valid array type for padding' do
        component = {
          'type' => 'View',
          'padding' => [10, 20, 10, 20]
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end
    end

    context 'with min/max validation' do
      it 'accepts valid alpha value within range' do
        component = {
          'type' => 'View',
          'alpha' => 0.5
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'rejects alpha value below minimum' do
        component = {
          'type' => 'View',
          'alpha' => -0.1
        }
        warnings = validator.validate(component)
        expect(warnings).not_to be_empty
        expect(warnings.first).to include('less than minimum')
      end

      it 'rejects alpha value above maximum' do
        component = {
          'type' => 'View',
          'alpha' => 1.5
        }
        warnings = validator.validate(component)
        expect(warnings).not_to be_empty
        expect(warnings.first).to include('greater than maximum')
      end
    end

    context 'with unknown attributes' do
      it 'warns about unknown attributes' do
        component = {
          'type' => 'View',
          'unknownAttribute' => 'value'
        }
        warnings = validator.validate(component)
        expect(warnings).not_to be_empty
        expect(warnings.first).to include('Unknown attribute')
        expect(warnings.first).to include('unknownAttribute')
      end
    end

    context 'with required attributes' do
      it 'does not require type when already provided' do
        component = {
          'type' => 'View'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end
    end

    context 'with nested object validation' do
      it 'accepts valid shadow object' do
        component = {
          'type' => 'View',
          'shadow' => {
            'color' => '#000000',
            'offsetX' => 2,
            'offsetY' => 2,
            'opacity' => 0.5,
            'radius' => 4
          }
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'accepts shadow as string' do
        component = {
          'type' => 'View',
          'shadow' => '#000000|2|2|0.5|4'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end
    end

    context 'with mode compatibility' do
      let(:react_validator) { described_class.new(:react) }

      it 'accepts react-specific attributes in react mode' do
        component = {
          'type' => 'View',
          'className' => 'custom-class'
        }
        warnings = react_validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'accepts react-specific testId in react mode' do
        component = {
          'type' => 'View',
          'testId' => 'test-view'
        }
        warnings = react_validator.validate(component)
        expect(warnings).to be_empty
      end
    end

    context 'with Label specific attributes' do
      it 'accepts valid font attributes' do
        component = {
          'type' => 'Label',
          'text' => 'Test',
          'font' => 'Arial',
          'fontSize' => 16,
          'fontColor' => '#000000'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'accepts valid textTransform value' do
        component = {
          'type' => 'Label',
          'text' => 'Test',
          'textTransform' => 'uppercase'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'rejects invalid textTransform value' do
        component = {
          'type' => 'Label',
          'text' => 'Test',
          'textTransform' => 'invalid'
        }
        warnings = validator.validate(component)
        expect(warnings).not_to be_empty
        expect(warnings.first).to include('invalid value')
      end
    end

    context 'with Button attributes' do
      it 'accepts valid button attributes' do
        component = {
          'type' => 'Button',
          'text' => 'Click Me',
          'onClick' => '@{handleClick}'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end
    end

    context 'with TextField attributes' do
      it 'accepts valid input type' do
        component = {
          'type' => 'TextField',
          'hint' => 'Enter email',
          'input' => 'email'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'rejects invalid input type' do
        component = {
          'type' => 'TextField',
          'hint' => 'Enter value',
          'input' => 'invalid'
        }
        warnings = validator.validate(component)
        expect(warnings).not_to be_empty
        expect(warnings.first).to include('invalid value')
      end
    end

    context 'with Collection attributes' do
      it 'accepts valid columns value' do
        component = {
          'type' => 'Collection',
          'columns' => 2
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end

      it 'accepts valid layout value' do
        component = {
          'type' => 'Collection',
          'layout' => 'vertical'
        }
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end
    end
  end

  describe '#has_warnings?' do
    it 'returns false when no warnings' do
      component = { 'type' => 'View' }
      validator.validate(component)
      expect(validator.has_warnings?).to be false
    end

    it 'returns true when there are warnings' do
      component = {
        'type' => 'View',
        'unknownAttr' => 'value'
      }
      validator.validate(component)
      expect(validator.has_warnings?).to be true
    end
  end

  describe '#print_warnings' do
    it 'prints warnings to stdout' do
      component = {
        'type' => 'View',
        'unknownAttr' => 'value'
      }
      validator.validate(component)

      expect {
        validator.print_warnings
      }.to output(/\[RJUI Warning\]/).to_stdout
    end
  end

  # NEW: Tests for invalid binding syntax
  describe 'Invalid binding syntax validation' do
    context 'with valid binding syntax' do
      let(:component) do
        {
          'type' => 'Label',
          'text' => '@{userName}'
        }
      end

      it 'returns no warnings for valid binding' do
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end
    end

    context 'with invalid binding syntax - missing closing brace' do
      let(:component) do
        {
          'type' => 'Label',
          'text' => '@{userName'
        }
      end

      it 'returns warning for invalid binding syntax' do
        warnings = validator.validate(component)
        expect(warnings).to include(
          "Attribute 'text' in 'Label' has invalid binding syntax (starts with '@{' but doesn't end with '}')"
        )
      end
    end

    context 'with invalid binding syntax - extra characters after closing brace' do
      let(:component) do
        {
          'type' => 'Label',
          'text' => '@{userName}extra'
        }
      end

      it 'returns warning for invalid binding syntax' do
        warnings = validator.validate(component)
        expect(warnings).to include(
          "Attribute 'text' in 'Label' has invalid binding syntax (starts with '@{' but doesn't end with '}')"
        )
      end
    end

    context 'with regular string value' do
      let(:component) do
        {
          'type' => 'Label',
          'text' => 'Hello World'
        }
      end

      it 'returns no warnings for regular string' do
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end
    end

    context 'with string containing @{ but not at start' do
      let(:component) do
        {
          'type' => 'Label',
          'text' => 'Email: @{email}'
        }
      end

      it 'returns no warnings for string with @{ in middle' do
        warnings = validator.validate(component)
        expect(warnings).to be_empty
      end
    end

    context 'with binding attribute type and invalid syntax' do
      let(:component) do
        {
          'type' => 'TextField',
          'text' => '@{inputValue'
        }
      end

      it 'returns warning for invalid binding syntax' do
        warnings = validator.validate(component)
        expect(warnings).to include(
          "Attribute 'text' in 'TextField' has invalid binding syntax (starts with '@{' but doesn't end with '}')"
        )
      end
    end

    context 'with nested object property having invalid binding syntax' do
      let(:component) do
        {
          'type' => 'Label',
          'text' => 'Hello',
          'shadow' => {
            'color' => '@{shadowColor'
          }
        }
      end

      it 'returns warning for invalid binding syntax in nested property' do
        warnings = validator.validate(component)
        expect(warnings).to include(
          "Attribute 'shadow.color' in 'Label' has invalid binding syntax (starts with '@{' but doesn't end with '}')"
        )
      end
    end
  end
end
