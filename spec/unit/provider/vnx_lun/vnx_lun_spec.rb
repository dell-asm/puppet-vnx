require "spec_helper"
require "rspec/expectations"

describe Puppet::Type.type(:vnx_lun).provider(:vnx_lun) do
  let(:resource) {Puppet::Type.type(:vnx_lun).new(
    {
      :name     => "bs",
      :lun_name => "TestVol",
      :ensure   => "present",
      :type     => "nonthin",
      :capacity => "20GB",
      :pool_name => "Pool 0"
    }
    )
  }

  let(:provider) { resource.provider }

  describe "#size_to_sizequal" do
    context "when you pass size" do
      it "returns capacity and units for valid input" do
        expect(provider.size_to_sizequal("100GB")).to match_array([100, "gb"])
      end

      it "raises execption for in valid input" do
        expect { provider.size_to_sizequal("gb100") }.to raise_error("gb100 is not a valid volume size.")
      end
    end
  end

  describe "#get_lun_number" do
    context "When you pass lun name, it returns lunmber" do
      it "returns capacity and units" do
        provider.stubs(:run).returns("LOGICAL UNIT NUMBER 14 \n Name:  lun100 \nUID:  60:06:01:60:10:A0:2D:00:7E:6A:4A:0D:06:4A:E6:11")
        expect(provider.get_lun_number).to eq(14)
      end
    end
  end

  describe "#get_hlu_sg_of_lun" do
    context "When you pass lun number" do
      it "returns hlu and sg name of that LUN" do
        provider.stubs(:get_lun_number).returns(3)
        provider.stubs(:run).returns("Storage Group Name:    test_group\n  HLU Number     ALU Number\n  ----------     ----------\n  0               3")
        expect(provider.get_hlu_sg_of_lun).to match_array([0, "test_group"])
      end
    end
  end

  describe "#get_lun_capacity_mb" do
    context "When you pass lun number" do
      it "returns LUN capacity in Megabytes" do
        provider.stubs(:run).returns("LUN Capacity(Megabytes): 10\nLUN Capacity(Blocks): 2048")
        expect(provider.get_lun_capacity_mb).to eq(10)
      end
    end
  end
end
