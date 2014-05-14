xml.instruct!
xml.response do
  xml.lat @lat
  xml.lng @lng
  xml.date @date.to_s(:db)
  xml.message @message if @message.present?
  if @districts && @districts.any?
    @districts.each do |d|
      xml.tag!(d.level.intern) do
        xml.state d.state_name
        xml.district d.name
        xml.display_name d.display_name
        xml.tag!('date_source') do
          xml.organization d.dataset.source_organization
          xml.url d.dataset.source_url
        end
      end
    end
  else
    if params[:lat] && params[:lng]
      xml.error  "No districts found"
    else
      xml.error "Must supply lat and lng parameters"
    end
  end
end