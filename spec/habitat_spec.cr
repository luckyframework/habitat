require "./spec_helper"

class FakeServer
  Habitat.create do
    setting port : Int32
    setting this_is_missing : String
    setting debug_errors : Bool = true
  end

  def available_in_instance_methods
    settings.port
  end
end

describe Habitat do
  it "works" do
    FakeServer.configure do
      settings.port = 8080
    end

    typeof(FakeServer.settings.port).should eq Int32
    FakeServer.settings.port.should eq 8080
    FakeServer.settings.debug_errors.should eq true
    FakeServer.new.available_in_instance_methods.should eq 8080
  end

  it "can check for missing settings" do
    # Because this_is_missing was never set
    Habitat.missing_settings?.should be_true

    FakeServer.configure do
      settings.this_is_missing = "Not anymore"
    end

    Habitat.missing_settings?.should be_false
  end
end
