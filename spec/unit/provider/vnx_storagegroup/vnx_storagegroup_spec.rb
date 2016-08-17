require "spec_helper"
require "rspec/expectations"

describe Puppet::Type.type(:vnx_storagegroup).provider(:vnx_storagegroup) do
  let(:resource) {Puppet::Type.type(:vnx_storagegroup).new(
    {
      :name     => "bs",
      :sg_name => "Testsg",
      :ensure   => "present",
      :host_name => "testesxi"
    }
    )
  }

  let(:provider) { resource.provider }

  describe "#host_list" do
    context "When you pass storagegroup" do
      it "returns list of hosts connected to that storagegroup" do
        provider.stubs(:run).returns("Host name: testhost")
        expect(provider.host_list).to match_array(["testhost"])
      end
    end
  end
end
