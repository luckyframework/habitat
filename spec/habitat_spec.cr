require "./spec_helper"

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

module ConfigurableModule
  Habitat.create do
    setting module_setting : String = "hello"
  end
end

# Test that config is inherited from Parent without calling Habitat
class AnotherChild < Parent
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

    # Should not raise now that settings are set
    Habitat.raise_if_missing_settings!
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
