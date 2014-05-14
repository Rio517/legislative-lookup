# == Schema Information
#
# Table name: districts
#
#  gid      :integer          not null, primary key
#  state    :string(2)
#  cd       :string(3)
#  name     :string(100)
#  the_geom :string           multi_polygon, -1
#  level    :string(255)
#

require 'spec_helper'

describe District do

  let(:datetime){Date.parse('2003-03-03')}

  it "should have a FIPS code lookup table" do
    District::FIPS_CODES['01'].should == 'AL'
  end

  it "should be able to locate by point" do
    districts = District.lookup(41.823989,-71.412834,datetime)
    districts.size.should == 3
    districts.select{|d| d.level == 'federal'}.first.display_name.should == 'RI 2nd'
  end

  it "should be able to load polygon_coordinates object" do
    p = District.first.polygon_coordinates
    p.should_not be_nil
  end

  it "should not locate by point when outside of any polygons" do
    districts = District.lookup(-36.158887, 86.782056,datetime)
    districts.size.should == 0
  end
end
