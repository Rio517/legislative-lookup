  class DatasetImporter::Ak < DatasetImporter::StateBase

  def download!
    self.create_path_and_clean!(self.zip_files_directory, false)
    zip_file = '2013ProclamationPlan.zip'
    zip_file_path = 'http://www.akredistricting.org/Files/2013_PROCLAMATION/'+ zip_file

    download_file(zip_file_path,zip_file)
  end

  def import_shapefiles!
    import_shapefile_processor do |shapefile|
      temp_table_name
    end
  end

  def combine_and_normalize!
    raise 'some issues w/ alaska data prevent moving forward.'
  end

  def dataset_attributes(options={})
    {
      :table_name            => temp_table_name,
      :source_type           => 'state',
      :source_organization   => 'Alaska',
      :source_url            => 'http://www.akredistricting.org/2013proclamation.html',
      :source_identifer      => 'ak113',
    }
  end

end

