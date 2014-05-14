  class DatasetImporter::Tx < DatasetImporter::StateBase

  def download!
    puts "Texas ftp server is extremly slow, so be patient with this download request. 3 minutes queue to start your download was normal."
    self.create_path_and_clean!(zip_files_directory, false)

    zip_file = 'PlanH309.zip'
    zip_file_path = 'ftp://ftpgis1.tlc.state.tx.us/DistrictViewer/House/'

    download_file(zip_file_path,zip_file)
  end

  def import_shapefiles!
    import_shapefile_processor do |shapefile|
      temp_table_name
    end
  end

  def combine_and_normalize!
    #origin.ogc_fid == district name
    ActiveRecord::Base.transaction do
      current_table_name = temp_table_name

      normalize_level_table(current_table_name,'lower')
      normalize_combined_data
    end
  end

  def dataset_attributes(options={})
    {
      :table_name            => temp_table_name,
      :source_type           => 'state',
      :source_organization   => 'Texas',
      :source_url            => 'http://www.tlc.state.tx.us/redist/redist.html',
      :source_identifer      => 'tx_h309',
    }
  end

end

