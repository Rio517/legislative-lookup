class DatasetImporter::Ky < DatasetImporter::StateBase

  def download!
    self.create_path_and_clean!(zip_files_directory, false)

    zip_files = %w[HH001M01.zip SH001A02.zip]
    zip_file_path = 'http://www.lrc.ky.gov/gis/gis%20data/arcview/'

    zip_files.each do |zip_file|
      download_file(zip_file_path,zip_file)
    end
  end

  def import_shapefiles!
    import_shapefile_processor do |shapefile|
      suffix = shapefile.match(/HH/) ? '_lower' : '_upper'
      temp_table_name + suffix
    end
  end

  def combine_and_normalize!
    ActiveRecord::Base.transaction do
      %w[lower upper].each do |level_name|
        current_table_name = temp_table_name + '_' + level_name

        normalize_level_table(current_table_name,level_name)
        rename_or_insert_into_combined(current_table_name)
      end

      normalize_combined_data('district')
    end
  end


  def dataset_attributes(options={})
    {
      :table_name            => temp_table_name,
      :source_type           => 'state',
      :source_organization   => 'Kentuckey',
      :source_url            => 'http://www.lrc.ky.gov/gis/maps.htm',
      :source_identifer      => 'ky113'
    }
  end

end

