  class DatasetImporter::Pa < DatasetImporter::StateBase

  def download!
    self.create_path_and_clean!(zip_files_directory, false)

    zip_files = %w[Senate/2011-Revised-Final/SHAPE/FinalSenatePlan2012.zip House/2011-Revised-Final/SHAPE/2011-Revised-Final-Plan-SHAPEFILES-House.zip]
    zip_file_path = 'http://aws.redistricting.state.pa.us/Redistricting/Resources/GISData/Districts/Legislative/'

    zip_files.each do |zip_file|
      download_file(zip_file_path,zip_file)
    end
  end

  def import_shapefiles!
    import_shapefile_processor do |shapefile|
      suffix = shapefile.match(/house/i) ? '_lower' : '_upper'
      temp_table_name + suffix
    end
  end

  def combine_and_normalize!
    #origin.ogc_fid == district name
    self.connection.drop_table(temp_table_name) if self.connection.table_exists?(temp_table_name)
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
      :source_organization   => 'Pennsylvania',
      :source_url            => 'http://www.redistricting.state.pa.us/',
      :source_identifer      => 'pa113',
    }
  end

end

