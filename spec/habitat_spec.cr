require "./spec_helper"

class FakeServer
  Habitat.create do
    setting port : Int32
    setting this_is_missing : String
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

describe Habitat do
  it "works with simple types" do
    setup_server(port: 8080)

    typeof(FakeServer.settings.port).should eq Int32
    FakeServer.settings.port.should eq 8080
    FakeServer.settings.debug_errors.should eq true
    FakeServer.settings.boolean.should eq false
    FakeServer.new.available_in_instance_methods.should eq 8080
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
    FakeServer.configure { settings.nilable_with_default = nil }
    FakeServer.settings.nilable_with_default.should be_nil
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

    expect_raises(Habitat::MissingSettingError, "this_is_missing") do
      Habitat.raise_if_missing_settings!
    end

    FakeServer.configure do
      settings.this_is_missing = "Not anymore"
    end

    Habitat.raise_if_missing_settings!
  end
end

private def setup_server(port = 8080,
                         something_that_can_be_multiple_types = "string type",
                         this_can_be_nil = nil)
  FakeServer.configure do
    settings.port = port
    settings.something_that_can_be_multiple_types = something_that_can_be_multiple_types
    settings.this_can_be_nil = this_can_be_nil
  end
end
