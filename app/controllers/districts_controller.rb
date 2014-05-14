class DistrictsController < ApplicationController
  before_filter :load_districts, :only => [:lookup_map_polygons,:lookup]
  caches_action :state_map, :cache_path => Proc.new { |c| Digest::SHA1.hexdigest(c.params.values.join) }

  def index
    respond_to do |type|
      type.html{}
    end
  end

  def lookup
    respond_to do |type|
      type.xml { render :layout => false}
      type.kml { render :layout => false}
      type.georss { render :layout => false}
      type.json{
        args = { :json => @district_presenter && @district_presenter.districts_json }
        args[:callback] = params[:callback] if params[:callback]
        render args
      }

    end
  end

  def lookup_map_polygons
    respond_to do |type|
      type.json{ render :json => @district_presenter && @district_presenter.lookup_ploygon_json }
    end
  end

  def state_maps
    @datasets = Dataset.all.map{|d| [d.source_identifer, d.id]}
    @fips = params[:fips] || params[:state] && District::STATES[params[:state]] || District::STATES['NY']
    @level = params[:level] || District::LEVELS.first

    district_scope = District.where(:level => @level, :state => @fips)
    if params[:dataset_id].present?
      dataset_id = params[:dataset_id]
      district_scope = district_scope.where(:dataset_id => dataset_id)
    else
      parse_date
      district_scope = district_scope.valid_at(@date)
    end

    district_presenter = DistrictsPresenter.new(:district_scope => district_scope)
    respond_to do |type|
      type.html{}
      type.json{
        render :json => district_presenter.state_polygon_json
      }
    end
  end

  private

  def load_districts
    @lat = params[:lat]
    @lng = params[:lng]

    parse_date

    @districts = District.lookup(@lat, @lng, @date) if @lat.present? && @lng.present?

    if @districts.present? || @districts.any?
      @district_presenter = DistrictsPresenter.new(
        :districts => @districts,
        :lat => @lat,
        :lng => @lng,
        :date => @date)
    else
      @message = "That lat/lng is not inside a congressional district"
    end
  end

  def parse_date
    @date = begin
      DateTime.parse(params[:date]) if params[:date].present?
    rescue ArgumentError
      @message = "Invalid Date: #{params[:date]}. Using today's date instead"
      nil
    end

    @date ||= DateTime.now
  end

end


class DistrictsPresenter
  attr_accessor :districts, :lat, :lng, :date, :district_scope
  DEFAULT_GMAPS_OPTIONS = {
    strokeColor: '#000000',
    strokeOpacity: 0.8,
    strokeWeight: 1,
    fillOpacity: 0.3,
    visible: true
  }

  def initialize(attributes)
    attributes.each {|k,v| send("#{k}=",v)}
  end

  def lookup_ploygon_json
    output = {
      :districts => [],
      :marker_text => '<div style="min-height:70px">'
    }

    self.districts.each do |district|
      output[:marker_text] += "<div style=\"color: #{district.color};min-width:250px\">#{district.full_name}</div>"
      output[:districts] << {:gmaps_options => DEFAULT_GMAPS_OPTIONS.merge(fillColor: district.color), :polygons => district.polygon_coordinates, :level => district.level}
    end
    output[:marker_text] += "<p>Also available in #{other_fomats_links}.</p>"
    output[:marker_text] += "</div>"

    # json_with_speedy_arrays(output.to_json)
    output.to_json
  end

  def districts_json
    if self.lat.present? && self.lng.present?
      output = {
        :lat=>self.lat,
        :lng=>self.lng,
        :date=>self.date,
      }
      self.districts.each do |d|
        output[d.level] = {
         :state        => d.state_name,
         :district     => d.name,
         :display_name => d.display_name,
         :data_source  => {:organization => d.dataset.source_organization, :url => d.dataset.source_url}
        }
      end
    else
      output = {:error => "You must submit a lat and lng."}
    end
    output.to_json
  end

  def state_polygon_json
    districts = self.district_scope.all.map{|district| {:gmaps_options => DEFAULT_GMAPS_OPTIONS, :polygons => district.polygon_coordinates.inspect} } # array as string for faster json rendering
    json_with_speedy_arrays(districts)
  end

  private

  # Parse arrays represented as strings into json represented as a string. Faster.
  # Parsing large coordinate arrays into json w/ ruby is expensive. Using string and gsubing escaped characters is about 300% faster.
  def json_with_speedy_arrays(source)
    source.to_json.gsub('"[[[','[[[').gsub(']]]"', ']]]').html_safe #.gsub('\\', '')
  end

  def other_fomats_links
    %w[json xml kml georss].map do |format|
      "<a href=\"/lookup.#{format}?lat=#{self.lat}&lng=#{self.lng}\">#{format}</a>"
    end.to_sentence
  end
end

