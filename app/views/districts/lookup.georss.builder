xml.instruct!
xml.rss(:version => "2.0", "xmlns:georss" => GEORSS_NS) do

  xml.channel do
    xml.title 'Legislative Districts'
    xml.link(lookup_url)
    xml.date @date
    xml.message @message if @message.present?

    xml.description "Legislative Districts for #{params[:lat]}, #{params[:lng]} at #{@date}"
    @districts.each do |d|
      xml.item do
        xml.title d.display_name
        xml.description d.level
        xml.data_source do
          xml.organization d.dataset.source_organization
          xml.url d.dataset.source_url
        end
        xml << d.the_geom.as_georss
      end
    end
  end
end