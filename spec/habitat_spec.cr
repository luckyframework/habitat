require "./spec_helper"

class RandomClass
end

class FakeServer
  Habitat.create do
    setting port : Int32
    setting this_is_missing : String
    setting this_is_missing_and_has_example : String, example: "IO::Memory.new"
    setting debug_errors : Bool = true
    setting boolean : Bool = false
    setting something_that_can_be_multiple_types : String | Int32
    setting this_can_be_nil : String?
    setting nilable_with_default : String? = "default"
  end

  def available_in_instance_methods
    settings.port
  end
end

class SettingWithConstant
  Habitat.create do
    setting constant_setting : RandomClass.class, example: "RandomClass"
  end
end

class Generics < Hash(String, String)
  Habitat.create do
    setting should_work : String = "with generics"
  end
end

class Parent
  Habitat.create do
    setting parent_setting : Bool = true
    setting inheritable_setting : String = ""
  end
end

class Child < Parent
  Habitat.create do
    setting is_child : Bool = true
    setting another_one : String?
  end
end

class WithSpecialFormat
  Habitat.create do
    setting pin : String, validation: :pin_format
    setting code : Int32, validation: :code_format
  end

  def self.pin_format(value : String)
    value.match(/^\d{4}$/) || Habitat.raise_validation_error("Number must be exactly 4 digits")
  end

  def self.code_format(value : Int32)
    (value > 99 && value < 199) || Habitat.raise_validation_error("Number must between 99 and 199")
  end
end

module ConfigurableModule
  Habitat.create do
    setting module_setting : String = "hello"
  end
end

# Test that config is inherited from Parent without calling Habitat
class AnotherChild < Parent
end

# Test that using the constant name Settings doesn't actually conflict with
# the HabitatSettings class
class Settings::Index < Parent
end

# Test that when we set the default value to a setting, and the value
class ConfigWithDefaultException
  # Uncomment this to see a MissingSettingError
  # Ref: https://github.com/luckyframework/habitat/issues/46
  # Habitat.create do
  #  setting explode : String = ConfigWithDefaultException.blows_up
  # end

  def self.blows_up
    nil || raise "Boom"
  end
end

class BaseConfig
  # Comment this block out to see compile-time error
  # from extend
  Habitat.create do
    setting name : String
  end
end

class BaseConfig # reopen for extension
  Habitat.extend do
    setting number : Int32
  end
end

describe Habitat do
  it "works with simple types" do
    setup_server(port: 8080)

    typeof(FakeServer.settings.port).should eq Int32
    FakeServer.settings.port.should eq 8080
    FakeServer.settings.debug_errors.should eq true
    FakeServer.settings.boolean.should eq false
    FakeServer.new.available_in_instance_methods.should eq 8080
  end

  context "with validations" do
    it "returns the correct value when the validation succeeds" do
      WithSpecialFormat.configure do |settings|
        settings.pin = "0123"
        settings.code = 123
      end

      WithSpecialFormat.settings.pin.should eq "0123"
      WithSpecialFormat.settings.code.should eq 123
    end

    it "raises an exception when the validation fails" do
      expect_raises(Habitat::InvalidSettingFormatError, "Number must be exactly 4 digits") do
        WithSpecialFormat.configure do |settings|
          settings.pin = "some code"
        end
      end

      expect_raises(Habitat::InvalidSettingFormatError, "Number must between 99 and 199") do
        WithSpecialFormat.configure do |settings|
          settings.code = 42
        end
      end
    end
  end

  describe "extending configs" do
    it "adds the extended setting" do
      BaseConfig.configure do |settings|
        settings.name = "TestConfig"
        settings.number = 4
      end

      BaseConfig.settings.name.should eq "TestConfig"
      BaseConfig.settings.number.should eq 4
    end
  end

  it "works with modules" do
    ConfigurableModule.settings.module_setting.should eq "hello"
  end

  it "works with inherited config" do
    Parent.temp_config(inheritable_setting: "inherit me") do
      Parent.settings.parent_setting.should be_true
      Child.settings.parent_setting.should be_true
      Child.settings.inheritable_setting.should eq "inherit me"
      Child.settings.is_child.should be_true
      AnotherChild.settings.parent_setting.should be_true
      AnotherChild.settings.responds_to?(:another_one).should be_false
    end

    Child.configure do |settings|
      settings.another_one = "another"
    end

    Child.settings.another_one.should eq "another"
  end

  it "works with union types" do
    setup_server(something_that_can_be_multiple_types: "string")
    FakeServer.settings.something_that_can_be_multiple_types.should eq "string"

    setup_server(something_that_can_be_multiple_types: 1)
    FakeServer.settings.something_that_can_be_multiple_types.should eq 1
  end

  it "works with nilable types" do
    setup_server
    FakeServer.settings.this_can_be_nil.should be_nil

    setup_server(this_can_be_nil: "not nil")
    FakeServer.settings.this_can_be_nil.should eq "not nil"

    FakeServer.settings.nilable_with_default.should eq "default"
    FakeServer.configure { |settings| settings.nilable_with_default = nil }
    FakeServer.settings.nilable_with_default.should be_nil
  end

  it "works with generics" do
    Generics.settings.should_work.should eq "with generics"
  end

  it "can set and reset config using a block" do
    setup_server(port: 3000)

    FakeServer.temp_config(port: 4000, this_can_be_nil: "string!") do
      FakeServer.settings.port.should eq 4000
      FakeServer.settings.this_can_be_nil.should eq "string!"
    end

    FakeServer.settings.port.should eq 3000
    FakeServer.settings.this_can_be_nil.should be_nil
  end

  it "can check for missing settings" do
    setup_server

    expect_raises(Habitat::MissingSettingError, %(settings.this_is_missing = some_value)) do
      Habitat.raise_if_missing_settings!
    end

    FakeServer.configure(&.this_is_missing = "Not anymore")

    expect_raises(Habitat::MissingSettingError, "IO::Memory.new") do
      Habitat.raise_if_missing_settings!
    end

    FakeServer.configure(&.this_is_missing_and_has_example = "No longer missing")

    expect_raises(Habitat::MissingSettingError, %(settings.constant_setting = RandomClass)) do
      Habitat.raise_if_missing_settings!
    end

    SettingWithConstant.configure(&.constant_setting = RandomClass)

    # Should not raise now that settings are set
    Habitat.raise_if_missing_settings!
  end

  it "can be converted to a Hash" do
    setup_server
    hash = {
      "port"                                 => 8080,
      "this_is_missing"                      => "Not anymore",
      "this_is_missing_and_has_example"      => "No longer missing",
      "debug_errors"                         => true,
      "boolean"                              => false,
      "something_that_can_be_multiple_types" => "string type",
      "this_can_be_nil"                      => nil,
      "nilable_with_default"                 => nil,
    }
    FakeServer.settings.to_h.should eq hash
  end

  it "doesn't conflict with Habitat Settings" do
    Settings::Index.settings.parent_setting.should eq true
  end
end

private def setup_server(port = 8080,
                         something_that_can_be_multiple_types = "string type",
                         this_can_be_nil = nil)
  FakeServer.configure do |settings|
    settings.port = port
    settings.something_that_can_be_multiple_types = something_that_can_be_multiple_types
    settings.this_can_be_nil = this_can_be_nil
  end
end
