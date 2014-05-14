  class DatasetImporter::Mt < DatasetImporter::StateBase

  def download!
    self.create_path_and_clean!(self.zip_files_directory, false)

    zip_files = %w[House_shape_adopted021213.zip Senate_shape_adopted021213.zip]
    zip_file_path = 'http://leg.mt.gov/content/Committees/Interim/2011-2012/Districting/Maps/Adopted-Plan/'

    zip_files.each do |zip_file|
      download_file(zip_file_path,zip_file)
    end
  end

  def import_shapefiles!
    import_shapefile_processor do |shapefile|
      suffix = shapefile.match(/house/i) ? '_lower' : '_upper'
      puts suffic
      temp_table_name + suffix
    end
  end

  def combine_and_normalize!
    #origin.ogc_fid == district name
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
      :source_organization   => 'Montana',
      :source_url            => 'http://leg.mt.gov/css/Committees/interim/2011-2012/districting/adopted-plan.asp',
      :source_identifer      => 'mt113',
    }
  end

end

