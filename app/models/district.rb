# == Schema Information
#
# Table name: districts
#
#  gid        :integer          not null, primary key
#  state      :string(2)
#  cd         :string(3)
#  name       :string(100)
#  the_geom   :string           multi_polygon, -1
#  level      :string(255)
#  dataset_id :integer
#

# Schema explanation:
#     gid           - Postgres-assigned id
#     state         - FIPS code
#     name          - District name. Most are like "029" but some have crazy english names.
#     cd            - District code. Often equivalent to name (district name), but not always. Not exposed in the api but it can be handy for matching up part of different data sets.
#     level         - "state_lower", "state_upper", or "federal".
#     the_geom

class District < ActiveRecord::Base
  DEFAULT_EPSG_SRID_CODE = '4269' # (GCS_North_American_1983) - based on census data *.prj files.  See: http://prj2epsg.org/

  belongs_to :dataset

  self.primary_key = "id"

  scope :lookup, lambda {|lat, lng, datetime| lookup_all(lat,lng).valid_at(datetime) }
  scope :valid_at, lambda{|datetime| where(["(expires_at IS NULL OR expires_at > ?) AND valid_at < ?", datetime, datetime]) }
  scope :lookup_all, lambda {|lat, lng| where(["ST_Contains(the_geom,  ST_GeomFromText('POINT(? ?)', #{DEFAULT_EPSG_SRID_CODE}))",lng.to_f,lat.to_f]).includes(:dataset) }

  def color
    LEVEL_COLORS.fetch(self.level)
  end

  def state_name
    FIPS_CODES[self.state]
  end

  def display_name
    if /^\d*$/ =~ name
      "#{state_name} #{name.to_i.ordinalize}"
    else
      "#{state_name} #{name}"
    end
  end

  def full_name
    "#{display_name} #{DESCRIPTION.fetch(level)}"
  end

  def polygon_coordinates
    self.the_geom.to_coordinates[0].compact
  end

  def exceptions
    Scheduler::VALID_DATE_EXCEPTIONS[state_name][level.to_sym]
  end

  def has_exception?
    !exceptions.blank?
  end

  # Finds datasets and states with non-numeric district names
  #
  # States like MA have non-numeric districts. When renamed, there are occssional inconsistances.  This method can be used to identify normaliztions that need to be made.
  def self.unusual_district_names(column='cd')
    unusual = District.select(District.column_names-['the_geom']).where("#{column} ~ '[A-Za-z]'")
    unusual.each_with_object({}) do |unusual_hash, d|
      unusual_hash[d.state_name] ||= {:names => {}, :count => 0}
      unusual_hash[d.state_name][:names][d.dataset_id] ||= []
      unusual_hash[d.state_name][:names][d.dataset_id] << d.cd
      unusual_hash[d.state_name][:count] +=1
    end
    #unusual_hash.each{|state_name,names| names.each{|dataset,ids| puts [state_name, dataset, ids.size].join(', ') }} #useful for counting bad datasets
  end

  LEVEL_COLORS = {
    'federal' => 'red',
    'state_upper' => 'green',
    'state_lower' => 'blue'
  }.freeze


  DESCRIPTION = {
    'federal' => 'Congressional District',
    'state_upper' => 'Upper State House District',
    'state_lower' => 'Lower State House District'
  }.freeze

  LEVELS = DESCRIPTION.keys

  FIPS_CODES = {
    "01" => "AL",
    "02" => "AK",
    "04" => "AZ",
    "05" => "AR",
    "06" => "CA",
    "08" => "CO",
    "09" => "CT",
    "10" => "DE",
    "11" => "DC",
    "12" => "FL",
    "13" => "GA",
    "15" => "HI",
    "16" => "ID",
    "17" => "IL",
    "18" => "IN",
    "19" => "IA",
    "20" => "KS",
    "21" => "KY",
    "22" => "LA",
    "23" => "ME",
    "24" => "MD",
    "25" => "MA",
    "26" => "MI",
    "27" => "MN",
    "28" => "MS",
    "29" => "MO",
    "30" => "MT",
    "31" => "NE",
    "32" => "NV",
    "33" => "NH",
    "34" => "NJ",
    "35" => "NM",
    "36" => "NY",
    "37" => "NC",
    "38" => "ND",
    "39" => "OH",
    "40" => "OK",
    "41" => "OR",
    "42" => "PA",
    "44" => "RI",
    "45" => "SC",
    "46" => "SD",
    "47" => "TN",
    "48" => "TX",
    "49" => "UT",
    "50" => "VT",
    "51" => "VA",
    "53" => "WA",
    "54" => "WV",
    "55" => "WI",
    "56" => "WY",
    #non-states follow
    "60" => "AS",
    #"64" => "FM",  Not in census
    "66" => "GU",
    "68" => "MH",
    "69" => "MP",
    #"70" => "PW",
    "72" => "PR",
    #"74" => "UM",
    "78" => "VI"
  }
  STATES = FIPS_CODES.invert.freeze
end

