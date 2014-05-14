class DatasetImporter::Ca < DatasetImporter::StateBase

  def download!
    self.create_path_and_clean!(zip_files_directory, false)

    zip_files = %w[viz_20110728_q2_ad_finaldraft_shp.zip viz_20110728_q2_sd_finaldraft_shp.zip]
    zip_file_path = 'http://wedrawthelines.ca.gov/downloads/meeting_handouts_072011/'

    zip_files.each do |zip_file|
      download_file(zip_file_path,zip_file)
    end
  end

  def import_shapefiles!
    import_shapefile_processor do |shapefile|
      suffix = shapefile.match(/assembly/) ? '_lower' : '_upper'
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

      normalize_combined_data
    end
  end


  def dataset_attributes(options={})
    {
      :table_name            => temp_table_name,
      :source_type           => 'state',
      :source_organization   => 'California',
      :source_url            => 'http://wedrawthelines.ca.gov/',
      :source_identifer      => 'ca2011'
    }
  end

end

