require "./spec_helper"

private class FakeServer
  Habitat.create do
    setting port : Int32
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

    FakeServer.settings.port.should eq 8080
    FakeServer.settings.debug_errors.should eq false
    FakeServer.new.available_in_instance_methods.should eq 8080
  end
end
