  class DatasetImporter::Me < DatasetImporter::StateBase

  def download!
    self.create_path_and_clean!(zip_files_directory, false)

    zip_files = %w[senate13s.zip house13s.zip]
    zip_file_path = 'http://www.maine.gov/megis/catalog/shps/state/'
    puts 'WARNING: There is missing header and it seems that you must manually download the following files from your browser and place into #{zip_files_directory}: '

    zip_files.each do |zip_file|
      puts zip_file_path + zip_file
      # download_file(zip_file_path,zip_file)
    end
  end

  def import_shapefiles!
    raise 'these don\'t seem to import correctly.  Same issue as AK' +
      'Maybe try shp2sql'
    #error raised in ogr2ogr
    # ERROR 1: INSERT command for new feature failed.
    # ERROR:  numeric field overflow
    # DETAIL:  A field with precision 19, scale 11 must round to an absolute value less than 10^8.

    import_shapefile_processor do |shapefile|
      suffix = shapefile.match(/house/) ? '_lower' : '_upper'
      temp_table_name + suffix
    end
  end

  def combine_and_normalize!
    ActiveRecord::Base.transaction do
      %w[lower upper].each do |level_name|
        current_table_name = temp_table_name + '_' + level_name
        self.connection.remove_column current_table_name, :ogc_fid
        self.connection.execute "ALTER TABLE #{current_table_name} RENAME COLUMN #{level_name == 'lower' ? 'hd' : 'sd'}2013 TO ogc_fid"

        normalize_level_table(current_table_name,level_name)
        rename_or_insert_into_combined
      end

      normalize_combined_data
    end
  end


  def dataset_attributes(options={})
    {
      :table_name            => temp_table_name,
      :source_type           => 'state',
      :source_organization   => 'Maine',
      :source_url            => 'http://www.maine.gov/megis/catalog/#tbstriped2',
      :source_identifer      => 'me113',
    }
  end

end

